variable "name_prefix" { type = string }
variable "aws_region" { type = string }

variable "lambda_role_arn" { type = string }
variable "lambda_zip_path" { type = string }

variable "discord_public_key" { 
  type        = string
  description = "Discord Application Public Key (will be stored in SSM Parameter Store)"
}
variable "allowed_role_id" { type = string }

variable "ecs_cluster_arn" { type = string }
variable "ecs_service_name" { type = string }

variable "taskdef_arns_by_size" {
  type = map(string)
}
