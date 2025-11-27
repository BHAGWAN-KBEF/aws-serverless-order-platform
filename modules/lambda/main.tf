variable "env" {
  description = "Environment name"
  type        = string
}

variable "lambda_role_arn" {
  description = "IAM role ARN for Lambda functions"
  type        = string
}

variable "sqs_queue_url" {
  description = "SQS queue URL"
  type        = string
}

variable "sqs_queue_arn" {
  description = "SQS queue ARN"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "slack_webhook_url" {
  description = "Slack webhook URL"
  type        = string
  default     = ""
}

# API Handler Lambda
resource "aws_lambda_function" "api_handler" {
  filename         = "${path.root}/infra/api_handler.zip"
  function_name    = "api-handler-${var.env}"
  role             = var.lambda_role_arn
  handler          = "app.lambda_handler"
  runtime          = "python3.10"
  source_code_hash = try(filebase64sha256("${path.root}/infra/api_handler.zip"), null)

  environment {
    variables = {
      SQS_URL   = var.sqs_queue_url
      DDB_TABLE = var.dynamodb_table_name
    }
  }

  tracing_config {
    mode = "Active"
  }
}

# Order Worker Lambda
resource "aws_lambda_function" "order_worker" {
  filename         = "${path.root}/infra/order_worker.zip"
  function_name    = "order-worker-${var.env}"
  role             = var.lambda_role_arn
  handler          = "worker.lambda_handler"
  runtime          = "python3.10"
  source_code_hash = try(filebase64sha256("${path.root}/infra/order_worker.zip"), null)

  environment {
    variables = {
      DDB_TABLE = var.dynamodb_table_name
    }
  }

  tracing_config {
    mode = "Active"
  }
}

# Slack Notifier Lambda
resource "aws_lambda_function" "slack_notifier" {
  count            = var.slack_webhook_url != "" ? 1 : 0
  filename         = "${path.root}/infra/slack_notifier.zip"
  function_name    = "slack-notifier-${var.env}"
  role             = var.lambda_role_arn
  handler          = "slack_notifier.lambda_handler"
  runtime          = "python3.10"
  source_code_hash = try(filebase64sha256("${path.root}/infra/slack_notifier.zip"), null)

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }
}

# SQS Event Source Mapping
resource "aws_lambda_event_source_mapping" "worker_sqs" {
  event_source_arn = var.sqs_queue_arn
  function_name    = aws_lambda_function.order_worker.arn
  batch_size       = 5
  enabled          = true
}

output "api_handler_arn" {
  value = aws_lambda_function.api_handler.arn
}

output "api_handler_function_name" {
  value = aws_lambda_function.api_handler.function_name
}

output "order_worker_function_name" {
  value = aws_lambda_function.order_worker.function_name
}

output "slack_notifier_arn" {
  value = var.slack_webhook_url != "" ? aws_lambda_function.slack_notifier[0].arn : null
}