variable "env" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "api_handler_function_name" {
  description = "API handler function name"
  type        = string
}

variable "order_worker_function_name" {
  description = "Order worker function name"
  type        = string
}

variable "sqs_queue_name" {
  description = "SQS queue name"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "alert_email" {
  description = "Email for alerts"
  type        = string
}

variable "slack_webhook_url" {
  description = "Slack webhook URL"
  type        = string
  default     = ""
}

variable "slack_notifier_arn" {
  description = "Slack notifier Lambda ARN"
  type        = string
  default     = null
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "order-service-alerts-${var.env}"
}

# Email Subscription
resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Slack Subscription
resource "aws_sns_topic_subscription" "slack_alerts" {
  count     = var.slack_webhook_url != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = var.slack_notifier_arn
}

# Lambda Permission for SNS
resource "aws_lambda_permission" "allow_sns_slack" {
  count         = var.slack_webhook_url != "" ? 1 : 0
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = split(":", var.slack_notifier_arn)[6]
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "lambda-errors-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Lambda function errors detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = var.api_handler_function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "high_order_processing_delay" {
  alarm_name          = "high-order-processing-delay-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "600"
  alarm_description   = "Orders taking too long to process"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    QueueName = var.sqs_queue_name
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "order_service" {
  dashboard_name = "OrderService-${var.env}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["OrderService", "OrdersReceived", "Environment", var.env],
            [".", "OrdersProcessed", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Order Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.api_handler_function_name],
            [".", ".", ".", var.order_worker_function_name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Lambda Duration"
          period  = 300
        }
      }
    ]
  })
}

output "dashboard_url" {
  value = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.order_service.dashboard_name}"
}