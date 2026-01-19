variable "name_prefix" { type = string }
variable "aws_region" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "ecs_sg_id" { type = string }

variable "efs_id" { type = string }
variable "efs_access_point_id" { type = string }

variable "minecraft_port" { type = number }

variable "sizes" {
  type = map(object({
    cpu    = number
    memory = number
  }))
}

variable "minecraft_ops" {
  description = "List of Minecraft usernames to be granted operator (OP) privileges on the server."
  type        = list(string)
  default     = []
}

variable "enable_whitelist" {
  description = "Enable whitelist mode for the Minecraft server, restricting access to only whitelisted players."
  type        = bool
  default     = false
}

variable "minecraft_whitelist" {
  description = "List of Minecraft usernames to be added to the server whitelist when whitelist mode is enabled."
  type        = list(string)
  default     = []
}

variable "task_execution_role_arn" { type = string }
variable "task_role_arn" { type = string }
variable "target_group_arn" { type = string }
