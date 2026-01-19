variable "name_prefix" { type = string }
variable "lambda_role_arn" { type = string }
variable "lambda_zip_path" { type = string }

variable "discord_public_key_param_name" { type = string }
variable "allowed_role_id_param_name" { type = string }

variable "ecs_cluster_arn" { type = string }
variable "ecs_service_name" { type = string }
variable "taskdef_arns_by_size" { type = map(string) }
