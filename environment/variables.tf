variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "name_prefix" {
  type    = string
  default = "mc"
}

variable "minecraft_port" {
  type    = number
  default = 25565
}

variable "allowed_cidr_blocks" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "sizes" {
  type = map(object({
    cpu    = number
    memory = number
  }))
  default = {
    small  = { cpu = 1024, memory = 2048 }
    medium = { cpu = 2048, memory = 4096 }
    large  = { cpu = 4096, memory = 8192 }
  }
}

variable "minecraft_op_name" {
  type        = string
  description = "OPにする自分のMinecraftユーザー名"
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

variable "lambda_zip_path" {
  type    = string
  default = "../lambda/discord-control/dist/discord-control.zip"
}
