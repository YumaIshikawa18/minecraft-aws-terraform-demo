variable "name_prefix" { type = string }

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
