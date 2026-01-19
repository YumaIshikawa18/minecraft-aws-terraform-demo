resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"
}

resource "aws_ecs_task_definition" "minecraft" {
  for_each                 = var.sizes
  family                   = "${var.name_prefix}-minecraft-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(each.value.cpu)
  memory                   = tostring(each.value.memory)
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

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

    environment = [
      { name = "EULA", value = "TRUE" },
      { name = "ONLINE_MODE", value = "TRUE" },
      { name = "ENABLE_RCON", value = "false" },
      { name = "OPS", value = join(",", var.minecraft_ops) },
      { name = "ENABLE_WHITELIST", value = var.enable_whitelist ? "true" : "false" },
      { name = "WHITELIST", value = join(",", var.minecraft_whitelist) }
    ]

    mountPoints = [{
      sourceVolume  = "efs-data"
      containerPath = "/data"
      readOnly      = false
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "minecraft"
      }
    }
  }])
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
    target_group_arn = var.target_group_arn
    container_name   = "minecraft"
    container_port   = var.minecraft_port
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "${var.name_prefix}/minecraft"
  retention_in_days = 14
}