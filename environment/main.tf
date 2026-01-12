terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }

  # backendはworkflowで -backend-config で渡す（変数は使えないため）
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

module "network" {
  source = "../modules/network"

  name_prefix         = var.name_prefix
  aws_region          = var.aws_region
  allowed_cidr_blocks = var.allowed_cidr_blocks
}

module "efs" {
  source = "../modules/efs"

  name_prefix  = var.name_prefix
  vpc_id       = module.network.vpc_id
  subnet_ids   = module.network.private_subnet_ids
  efs_sg_id    = module.network.efs_sg_id
  ecs_sg_id    = module.network.ecs_sg_id
}

module "minecraft" {
  source = "../modules/minecraft_ecs"

  name_prefix         = var.name_prefix
  aws_region          = var.aws_region
  vpc_id              = module.network.vpc_id
  public_subnet_ids   = module.network.public_subnet_ids
  ecs_sg_id           = module.network.ecs_sg_id
  efs_id              = module.efs.efs_id
  efs_access_point_id = module.efs.efs_access_point_id

  minecraft_port = var.minecraft_port

  # size別のCPU/メモリ（Fargate対応値にする）
  sizes = var.sizes
}

module "iam_control" {
  source = "../modules/iam_control"

  name_prefix      = var.name_prefix
  ecs_cluster_arn  = module.minecraft.ecs_cluster_arn
  ecs_service_name = module.minecraft.ecs_service_name
}

module "discord_control" {
  source = "../modules/discord_control"

  name_prefix         = var.name_prefix
  aws_region          = var.aws_region
  lambda_role_arn     = module.iam_control.lambda_role_arn

  # build成果物（workflowで生成）
  lambda_zip_path     = var.lambda_zip_path

  # Discord
  discord_public_key  = var.discord_public_key
  allowed_role_id     = var.allowed_role_id

  # ECS対象
  ecs_cluster_arn     = module.minecraft.ecs_cluster_arn
  ecs_service_name    = module.minecraft.ecs_service_name
  taskdef_arns_by_size = module.minecraft.taskdef_arns_by_size
}
