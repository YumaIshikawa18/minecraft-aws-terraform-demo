variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "github_owner" { type = string }
variable "github_repo" { type = string }

variable "tfstate_bucket_name" {
  type        = string
  description = "tfstate用S3バケット名（グローバル一意）"
}

variable "gha_role_name" {
  type    = string
  default = "gh-terraform-minecraft"
}
