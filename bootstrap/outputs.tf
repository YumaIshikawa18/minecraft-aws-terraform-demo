output "tfstate_bucket_name" {
  value = aws_s3_bucket.tfstate.bucket
}

output "gha_role_arn" {
  value = aws_iam_role.gha_terraform.arn
}
