resource "aws_ssm_parameter" "discord_public_key" {
  name        = "/${var.name_prefix}/discord/public-key"
  description = "Discord Application Public Key"
  type        = "SecureString"
  value       = var.discord_public_key
}

resource "aws_ssm_parameter" "allowed_role_id" {
  name        = "/${var.name_prefix}/discord/allowed-role-id"
  description = "Discord Allowed Role ID"
  type        = "SecureString"
  value       = var.allowed_role_id
}
