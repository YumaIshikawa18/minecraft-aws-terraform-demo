resource "aws_lb" "this" {
  name               = "${var.name_prefix}-nlb"
  load_balancer_type = "network"
  internal           = false
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "minecraft" {
  name        = "${var.name_prefix}-tg-mc"
  port        = var.port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    protocol = "TCP"
    port     = "traffic-port"
  }
}

resource "aws_lb_listener" "minecraft" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.minecraft.arn
  }
}
