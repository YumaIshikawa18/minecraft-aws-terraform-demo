resource "aws_lambda_function" "this" {
  function_name = "${var.name_prefix}-discord-control"
  role          = var.lambda_role_arn
  runtime       = "nodejs24.x"
  handler       = "index.handler"

  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)

  timeout = 15

  environment {
    variables = {
      DISCORD_PUBLIC_KEY_PARAM = var.discord_public_key_param_name
      ALLOWED_ROLE_ID_PARAM    = var.allowed_role_id_param_name

      ECS_CLUSTER_ARN  = var.ecs_cluster_arn
      ECS_SERVICE_NAME = var.ecs_service_name

      TASKDEF_SMALL  = lookup(var.taskdef_arns_by_size, "small", "")
      TASKDEF_MEDIUM = lookup(var.taskdef_arns_by_size, "medium", "")
      TASKDEF_LARGE  = lookup(var.taskdef_arns_by_size, "large", "")
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.this.function_name}"
  retention_in_days = 30
}
