variable "aws_region" {
  type = string
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "cluster_arn" {
  type        = string
  description = "ECS cluster ARN to filter task state change events"
}

variable "service_group" {
  type        = string
  description = "ECS event detail.group (e.g. service:your-service). If empty, group filter is omitted."
  default     = ""
}

variable "discord_webhook_url_param_name" {
  type        = string
  description = "SSM parameter name (SecureString recommended) that stores Discord webhook URL"
}

variable "notify_on_running" {
  type        = bool
  default     = true
  description = "Send notification when task becomes RUNNING"
}

variable "notify_on_stopped" {
  type        = bool
  default     = true
  description = "Send notification when task becomes STOPPED"
}

variable "lambda_runtime" {
  type        = string
  default     = "nodejs24.x"
  description = "Lambda runtime"
}

variable "lambda_timeout_seconds" {
  type        = number
  default     = 10
  description = "Lambda timeout"
}

variable "lambda_memory_mb" {
  type        = number
  default     = 128
  description = "Lambda memory"
}

variable "lambda_zip_path" {
  type        = string
  description = "Path to lambda source directory (contains index.mjs and package.json). Relative to where terraform runs."
}
