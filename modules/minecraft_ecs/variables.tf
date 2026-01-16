variable "name_prefix" { type = string }
variable "aws_region" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "ecs_sg_id" { type = string }

variable "efs_id" { type = string }
variable "efs_access_point_id" { type = string }
variable "efs_file_system_arn" {
  description = "ARN of the EFS file system used for IAM authorization."
  type        = string
}

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
  type    = bool
  default = false
}

variable "minecraft_whitelist" {
  type    = list(string)
  default = []
}
