resource "aws_efs_file_system" "this" {
  encrypted = true
  tags      = { Name = "${var.name_prefix}-efs" }
}

resource "aws_efs_mount_target" "this" {
  for_each        = toset(var.subnet_ids)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [var.efs_sg_id]
}

resource "aws_efs_access_point" "data" {
  file_system_id = aws_efs_file_system.this.id

  root_directory {
    path = "/data"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0775"
    }
  }

  posix_user {
    uid = 1000
    gid = 1000
  }

  tags = { Name = "${var.name_prefix}-efs-ap-data" }
}
