output "api_endpoint" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}

output "sqs_url" {
  value = aws_sqs_queue.order_queue.id
}

output "dynamodb_table" {
  value = aws_dynamodb_table.orders.name
}

output "sqs_dlq_url" {
  value = aws_sqs_queue.order_dlq.id
}

output "sqs_dlq_arn" {
  value = aws_sqs_queue.order_dlq.arn
}

output "dashboard_url" {
  value = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.order_service.dashboard_name}"
}
