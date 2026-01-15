data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.name_prefix}-discord-control-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "ecs_control" {
  statement {
    effect = "Allow"
    actions = [
      "ecs:UpdateService"
    ]
    resources = [
      # UpdateServiceはService ARN指定がベストだが、ここは簡略化してクラスター配下を許可（後で絞る）
      "*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      # Lambda function needs permission to invoke itself for async worker pattern
      "arn:aws:lambda:*:*:function:${var.name_prefix}-discord-control"
    ]
  }
}

resource "aws_iam_policy" "ecs_control" {
  name   = "${var.name_prefix}-ecs-control"
  policy = data.aws_iam_policy_document.ecs_control.json
}

resource "aws_iam_role_policy_attachment" "ecs_control" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.ecs_control.arn
}
