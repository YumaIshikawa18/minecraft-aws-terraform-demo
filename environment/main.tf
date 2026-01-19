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

  name  = var.discord_public_key_name
  value = var.discord_public_key
}

module "discord_allowed_role_id" {
  source = "../modules/ssm_parameters"

  name  = var.allowed_role_id_name
  value = var.allowed_role_id
}

module "discord_webhook_url_param" {
  source = "../modules/ssm_parameters"

  name  = var.discord_webhook_url_param_name
  value = var.discord_webhook_url_param
}

module "discord_lambda" {
  source = "../modules/discord_control"

  name_prefix     = var.name_prefix
  lambda_role_arn = module.iam_control.lambda_role_arn
  lambda_zip_path = var.lambda_discord_control_zip_path

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

module "ecs_task_state_notify" {
  source = "../modules/ecs_task_state_notify"

  aws_region  = var.aws_region
  name_prefix = var.name_prefix

  cluster_arn   = module.minecraft_ecs.ecs_cluster_arn
  service_group = "service:${module.minecraft_ecs.ecs_service_name}"

  discord_webhook_url_param_name = module.discord_webhook_url_param.ssm_parameter_name

  notify_on_running = true
  notify_on_stopped = true

  lambda_zip_path = var.lambda_ecs_task_notify_zip_path
}

