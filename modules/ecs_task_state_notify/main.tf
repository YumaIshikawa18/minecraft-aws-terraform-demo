resource "aws_iam_role" "lambda" {
  name = "${local.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda" {
  name = "${local.function_name}-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      // CloudWatch Logs
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
      },
      // SSM Parameter read
      {
        Effect   = "Allow",
        Action   = ["ssm:GetParameter"],
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${replace(var.discord_webhook_url_param_name, "/^\\//", "/")}"
      }
    ]
  })
}

resource "aws_lambda_function" "this" {
  function_name = local.function_name
  role          = aws_iam_role.lambda.arn

  runtime = var.lambda_runtime
  handler = "index.handler"

  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)

  timeout     = var.lambda_timeout_seconds
  memory_size = var.lambda_memory_mb

  environment {
    variables = {
      DISCORD_WEBHOOK_URL_PARAM = var.discord_webhook_url_param_name
      NOTIFY_ON_RUNNING         = tostring(var.notify_on_running)
      NOTIFY_ON_STOPPED         = tostring(var.notify_on_stopped)
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}

# EventBridge Rules (RUNNING / STOPPED)
resource "aws_cloudwatch_event_rule" "running" {
  count         = var.notify_on_running ? 1 : 0
  name          = "${local.function_name}-running"
  event_pattern = local.event_pattern_running
}

resource "aws_cloudwatch_event_rule" "stopped" {
  count         = var.notify_on_stopped ? 1 : 0
  name          = "${local.function_name}-stopped"
  event_pattern = local.event_pattern_stopped
}

resource "aws_cloudwatch_event_target" "running" {
  count = var.notify_on_running ? 1 : 0
  rule  = aws_cloudwatch_event_rule.running[0].name
  arn   = aws_lambda_function.this.arn
}

resource "aws_cloudwatch_event_target" "stopped" {
  count = var.notify_on_stopped ? 1 : 0
  rule  = aws_cloudwatch_event_rule.stopped[0].name
  arn   = aws_lambda_function.this.arn
}

resource "aws_lambda_permission" "allow_eventbridge_running" {
  count = var.notify_on_running ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridgeRunning"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.running[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge_stopped" {
  count = var.notify_on_stopped ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridgeStopped"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stopped[0].arn
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 30
}
