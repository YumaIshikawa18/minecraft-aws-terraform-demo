locals {
  function_name = "${var.name_prefix}-ecs-task-notify"

  // EventBridge event pattern: ECS Task State Change
  // EventBridge detail-type for ECS task state changes (official AWS event type)
  event_pattern_running = jsonencode({
    "source" : ["aws.ecs"],
    "detail-type" : ["ECS Task State Change"],
    "detail" : merge(
      {
        "clusterArn" : [var.cluster_arn],
        "lastStatus" : ["RUNNING"]
      },
      var.service_group != "" ? { "group" : [var.service_group] } : {}
    )
  })

  event_pattern_stopped = jsonencode({
    "source" : ["aws.ecs"],
    "detail-type" : ["ECS Task State Change"],
    "detail" : merge(
      {
        "clusterArn" : [var.cluster_arn],
        "lastStatus" : ["STOPPED"]
      },
      var.service_group != "" ? { "group" : [var.service_group] } : {}
    )
  })
}
