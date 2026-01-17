resource "aws_iam_role" "gha_terraform" {
  name               = var.gha_role_name
  assume_role_policy = data.aws_iam_policy_document.gha_assume.json
}

resource "aws_iam_role_policy_attachment" "admin" {
  role       = aws_iam_role.gha_terraform.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
