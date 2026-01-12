variable "name_prefix" { type = string }
variable "vpc_id"      { type = string }
variable "subnet_ids"  { type = list(string) }

variable "efs_sg_id"   { type = string }
variable "ecs_sg_id"   { type = string } # 将来拡張用に残す（今は直接は未使用）
