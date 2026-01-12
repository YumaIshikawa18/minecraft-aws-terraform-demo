data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

resource "aws_vpc" "this" {
  cidr_block           = "10.50.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${var.name_prefix}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-igw" }
}

# public subnets（NLB）
resource "aws_subnet" "public" {
  for_each                = { for i, az in local.azs : az => i }
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, each.value)
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.name_prefix}-public-${each.key}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-rt-public" }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# private subnets（ECSタスク/ EFS）
resource "aws_subnet" "private" {
  for_each          = { for i, az in local.azs : az => i }
  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 8, each.value + 10)
  tags              = { Name = "${var.name_prefix}-private-${each.key}" }
}

# NATなし（最小運用）。必要になったらVPC Endpoint化 or NAT追加。

# ECS task SG（Minecraft portを許可）
resource "aws_security_group" "ecs" {
  name        = "${var.name_prefix}-ecs-sg"
  description = "ECS tasks"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Minecraft TCP"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EFS SG（2049をECS SGからのみ許可）
resource "aws_security_group" "efs" {
  name        = "${var.name_prefix}-efs-sg"
  description = "EFS"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "NFS from ECS"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
