variable "name_prefix" { type = string }
variable "aws_region"  { type = string }

variable "allowed_cidr_blocks" {
  type = list(string)
}
