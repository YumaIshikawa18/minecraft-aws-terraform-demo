output "discord_public_key_name" {
  value = aws_ssm_parameter.discord_public_key.name
}

output "allowed_role_id_name" {
  value = aws_ssm_parameter.allowed_role_id.name
}
