output "api_endpoint" {
  value = module.api_gateway.api_endpoint
}

output "dashboard_url" {
  value = module.monitoring.dashboard_url
}

output "dynamodb_table" {
  value = module.storage.dynamodb_table_name
}

output "sqs_url" {
  value = module.storage.sqs_queue_url
}

output "sqs_dlq_url" {
  value = module.storage.sqs_dlq_url
}

output "sqs_dlq_arn" {
  value = module.storage.sqs_dlq_arn
}