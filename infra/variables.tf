variable "region" {
  type    = string
  default = "us-east-1"
}

variable "env" {
  type    = string
  default = "final"
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = "admin@example.com"
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
}
