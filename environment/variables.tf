variable "aws_region" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "minecraft_port" {
  type = number
}

variable "allowed_cidr_blocks" {
  type = list(string)
}

variable "sizes" {
  type = map(object({
    cpu    = number
    memory = number
  }))
}

variable "minecraft_op_name" {
  type        = string
  description = "OPにする自分のMinecraftユーザー名"
}

variable "discord_public_key_name" {
  type = string
}

variable "allowed_role_id_name" {
  type = string
}

variable "discord_webhook_url_param_name" {
  type = string
}

variable "discord_public_key" {
  type      = string
  sensitive = true
  default   = "dummy"
}

variable "allowed_role_id" {
  type      = string
  sensitive = true
  default   = "dummy"
}

variable "discord_webhook_url_param" {
  type      = string
  sensitive = true
  default   = "dummy"
}

variable "lambda_discord_control_zip_path" {
  type = string
}

variable "lambda_ecs_task_notify_zip_path" {
  type = string
}
