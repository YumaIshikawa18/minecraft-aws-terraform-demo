resource "aws_ssm_parameter" "discord_public_key" {
  name        = "/${var.name_prefix}/discord/public-key"
  description = "Discord Application Public Key"
  type        = "SecureString"
  value       = var.discord_public_key
}

resource "aws_lambda_function" "this" {
  function_name = "${var.name_prefix}-discord-control"
  role          = var.lambda_role_arn
  runtime       = "nodejs20.x"
  handler       = "index.handler"

  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)

  timeout = 15

  environment {
    variables = {
      DISCORD_PUBLIC_KEY_PARAM = aws_ssm_parameter.discord_public_key.name
      ALLOWED_ROLE_ID          = var.allowed_role_id

      ECS_CLUSTER_ARN  = var.ecs_cluster_arn
      ECS_SERVICE_NAME = var.ecs_service_name

      TASKDEF_SMALL  = lookup(var.taskdef_arns_by_size, "small", "")
      TASKDEF_MEDIUM = lookup(var.taskdef_arns_by_size, "medium", "")
      TASKDEF_LARGE  = lookup(var.taskdef_arns_by_size, "large", "")
    }
  }

  depends_on = [aws_ssm_parameter.discord_public_key]
}

resource "aws_apigatewayv2_api" "http" {
  name          = "${var.name_prefix}-discord-http"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.this.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "root" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}
