resource "aws_cloudwatch_log_group" "minecraft" {
  name              = "/${var.name_prefix}/minecraft"
  retention_in_days = 14
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"
}

data "aws_iam_policy_document" "task_exec_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${var.name_prefix}-ecs-task-exec"
  assume_role_policy = data.aws_iam_policy_document.task_exec_assume.json
}

# Task Role（EFS IAM認可のために必須）
resource "aws_iam_role" "task" {
  name               = "${var.name_prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.task_exec_assume.json
}

# EFS IAM authorization 用の権限（Access Point利用時の典型）
data "aws_iam_policy_document" "efs_client" {
  statement {
    effect = "Allow"
    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite"
      # 必要なら追加：
      # "elasticfilesystem:ClientRootAccess"
    ]
    resources = [var.efs_file_system_arn]
  }
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

resource "aws_lb" "nlb" {
  name               = "${var.name_prefix}-nlb"
  load_balancer_type = "network"
  internal           = false
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "minecraft" {
  name        = "${var.name_prefix}-tg-mc"
  port        = var.minecraft_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol = "TCP"
    port     = "traffic-port"
  }
}

resource "aws_lb_listener" "minecraft" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = var.minecraft_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.minecraft.arn
  }
}

resource "aws_ecs_task_definition" "minecraft" {
  for_each                 = var.sizes
  family                   = "${var.name_prefix}-minecraft-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(each.value.cpu)
  memory                   = tostring(each.value.memory)
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  volume {
    name = "efs-data"
    efs_volume_configuration {
      file_system_id     = var.efs_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = var.efs_access_point_id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([{
    name      = "minecraft"
    image     = "itzg/minecraft-server:latest"
    essential = true

    portMappings = [{
      containerPort = var.minecraft_port
      hostPort      = var.minecraft_port
      protocol      = "tcp"
    }]

    # 分離なし：ここに全部直書き
    environment = [
      { name = "EULA", value = "TRUE" },
      { name = "ONLINE_MODE", value = "TRUE" },
      # RCONは後で true + Secret 参照にすると安全停止が作りやすい
      { name = "ENABLE_RCON", value = "false" },

      # OP
      { name = "OPS", value = join(",", var.minecraft_ops) },

      # Whitelist（今は使わないなら enable_whitelist=false のまま）
      { name = "ENABLE_WHITELIST", value = var.enable_whitelist ? "true" : "false" },
      { name = "WHITELIST", value = join(",", var.minecraft_whitelist) },
    ]

    mountPoints = [{
      sourceVolume  = "efs-data"
      containerPath = "/data"
      readOnly      = false
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.minecraft.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "minecraft"
      }
    }
  }])
}

# デフォルトはsmall
locals {
  default_size = "small"
}

resource "aws_ecs_service" "this" {
  name          = "${var.name_prefix}-minecraft"
  cluster       = aws_ecs_cluster.this.id
  desired_count = 0
  launch_type   = "FARGATE"

  task_definition = aws_ecs_task_definition.minecraft[local.default_size].arn

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.minecraft.arn
    container_name   = "minecraft"
    container_port   = var.minecraft_port
  }

  depends_on = [aws_lb_listener.minecraft]
}
