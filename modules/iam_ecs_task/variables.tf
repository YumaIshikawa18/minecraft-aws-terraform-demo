variable "name_prefix" { type = string }

variable "efs_file_system_arn" {
  description = "ARN of the EFS file system used for IAM authorization."
  type        = string
}
