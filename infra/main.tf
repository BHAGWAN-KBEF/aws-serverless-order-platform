terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.region
}

# IAM Role for Lambda
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "order-lambda-role-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "order-lambda-policy-${var.env}"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["cloudwatch:PutMetricData"],
        Resource = "*"
      }
    ]
  })
}

# Storage Module
module "storage" {
  source = "../modules/storage"
  env    = var.env
}

# Lambda Module
module "lambda" {
  source = "../modules/lambda"
  
  env                  = var.env
  lambda_role_arn      = aws_iam_role.lambda_role.arn
  sqs_queue_url        = module.storage.sqs_queue_url
  sqs_queue_arn        = module.storage.sqs_queue_arn
  dynamodb_table_name  = module.storage.dynamodb_table_name
  slack_webhook_url    = var.slack_webhook_url
}

# API Gateway Module
module "api_gateway" {
  source = "../modules/api-gateway"
  
  env                   = var.env
  lambda_function_arn   = module.lambda.api_handler_arn
  lambda_function_name  = module.lambda.api_handler_function_name
}

# Monitoring Module
module "monitoring" {
  source = "../modules/monitoring"
  
  env                         = var.env
  region                      = var.region
  api_handler_function_name   = module.lambda.api_handler_function_name
  order_worker_function_name  = module.lambda.order_worker_function_name
  sqs_queue_name             = "order-queue-${var.env}"
  dynamodb_table_name        = module.storage.dynamodb_table_name
  alert_email                = var.alert_email
  slack_webhook_url          = var.slack_webhook_url
  slack_notifier_arn         = module.lambda.slack_notifier_arn
}