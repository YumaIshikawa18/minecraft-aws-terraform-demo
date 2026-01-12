output "ecs_cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "ecs_service_name" {
  value = aws_ecs_service.this.name
}

output "taskdef_arns_by_size" {
  value = { for k, v in aws_ecs_task_definition.minecraft : k => v.arn }
}

output "nlb_dns_name" {
  value = aws_lb.nlb.dns_name
}
