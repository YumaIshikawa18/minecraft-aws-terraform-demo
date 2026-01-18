terraform {
  required_version = "= 1.14.3"
  required_providers {
    aws = { source = "hashicorp/aws", version = "= 6.28.0" }
  }
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

  name_prefix = var.name_prefix
  vpc_id      = module.network.vpc_id
  subnet_ids  = module.network.private_subnet_ids
  efs_sg_id   = module.network.efs_sg_id
  ecs_sg_id   = module.network.ecs_sg_id
}

module "minecraft_log_group" {
  source = "../modules/cloudwatch_log_group"

  log_group_name    = "/${var.name_prefix}/minecraft"
  retention_in_days = 14
}

module "minecraft_task_iam" {
  source = "../modules/iam_ecs_task"

  name_prefix         = var.name_prefix
  efs_file_system_arn = module.efs.efs_arn
}

module "minecraft_lb" {
  source = "../modules/elb_network"

  name_prefix       = var.name_prefix
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  port              = var.minecraft_port
}

module "minecraft_ecs" {
  source = "../modules/ecs_service"

  name_prefix         = var.name_prefix
  aws_region          = var.aws_region
  public_subnet_ids   = module.network.public_subnet_ids
  ecs_sg_id           = module.network.ecs_sg_id
  efs_id              = module.efs.efs_id
  efs_access_point_id = module.efs.efs_access_point_id
  minecraft_port      = var.minecraft_port
  sizes               = var.sizes
  minecraft_ops       = [var.minecraft_op_name]

  log_group_name          = module.minecraft_log_group.log_group_name
  task_execution_role_arn = module.minecraft_task_iam.task_execution_role_arn
  task_role_arn           = module.minecraft_task_iam.task_role_arn
  target_group_arn        = module.minecraft_lb.target_group_arn

  depends_on = [module.minecraft_lb]
}

module "iam_control" {
  source = "../modules/iam_control"

  name_prefix      = var.name_prefix
  ecs_cluster_arn  = module.minecraft_ecs.ecs_cluster_arn
  ecs_service_name = module.minecraft_ecs.ecs_service_name
  ecs_passrole_arns = [
    module.minecraft_task_iam.task_execution_role_arn,
    module.minecraft_task_iam.task_role_arn,
  ]
}

module "discord_public_key" {
  source = "../modules/ssm_parameters"

  name = var.discord_public_key_name
  value = var.discord_public_key
}

module "discord_allowed_role_id" {
  source = "../modules/ssm_parameters"

  name = var.allowed_role_id_name
  value = var.allowed_role_id
}

module "discord_lambda" {
  source = "../modules/lambda_function"

  name_prefix     = var.name_prefix
  lambda_role_arn = module.iam_control.lambda_role_arn
  lambda_zip_path = var.lambda_zip_path

  discord_public_key_param_name = module.discord_public_key.ssm_parameter_name
  allowed_role_id_param_name    = module.discord_allowed_role_id.ssm_parameter_name

  ecs_cluster_arn      = module.minecraft_ecs.ecs_cluster_arn
  ecs_service_name     = module.minecraft_ecs.ecs_service_name
  taskdef_arns_by_size = module.minecraft_ecs.taskdef_arns_by_size
}

module "discord_api" {
  source = "../modules/apigateway_http"

  name_prefix          = var.name_prefix
  lambda_invoke_arn    = module.discord_lambda.lambda_invoke_arn
  lambda_function_name = module.discord_lambda.lambda_function_name
}
