output "tfstate_bucket_name" {
  value = module.tfstate.bucket_name
}

output "gha_role_arn" {
  value = module.gha_role.role_arn
}
