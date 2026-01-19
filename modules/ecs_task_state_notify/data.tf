data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.lambda_zip_path
  output_path = "${path.module}/.build/${local.function_name}.zip"
}