variable "env" {
  description = "Environment name"
  type        = string
}

# DynamoDB Table
resource "aws_dynamodb_table" "orders" {
  name         = "orders-${var.env}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }
}

# SQS Queue
resource "aws_sqs_queue" "order_queue" {
  name = "order-queue-${var.env}"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.order_dlq.arn
    maxReceiveCount     = 3
  })
}

# Dead Letter Queue
resource "aws_sqs_queue" "order_dlq" {
  name                      = "order-dlq-${var.env}"
  message_retention_seconds = 1209600 # 14 days
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.orders.name
}

output "sqs_queue_url" {
  value = aws_sqs_queue.order_queue.id
}

output "sqs_queue_arn" {
  value = aws_sqs_queue.order_queue.arn
}

output "sqs_dlq_url" {
  value = aws_sqs_queue.order_dlq.id
}

output "sqs_dlq_arn" {
  value = aws_sqs_queue.order_dlq.arn
}