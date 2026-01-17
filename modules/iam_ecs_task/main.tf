resource "aws_iam_role" "task_execution" {
  name               = "${var.name_prefix}-ecs-task-exec"
  assume_role_policy = data.aws_iam_policy_document.task_exec_assume.json
}

resource "aws_iam_role" "task" {
  name               = "${var.name_prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.task_exec_assume.json
}

resource "aws_iam_policy" "efs_client" {
  name   = "${var.name_prefix}-efs-client"
  policy = data.aws_iam_policy_document.efs_client.json
}

resource "aws_iam_role_policy_attachment" "efs_client" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.efs_client.arn
}

resource "aws_iam_role_policy_attachment" "task_exec" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
