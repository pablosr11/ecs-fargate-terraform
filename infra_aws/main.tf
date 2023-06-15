terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  backend "s3" {
    bucket = "clinikita-terraform-state"
    key    = "clinikita.tfstate"
    region = "eu-west-2"
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "eu-west-2"
  # profile = "default" # optionally set a user for terraform
}

## ECR
resource "aws_ecr_repository" "main" {
  name = "clinikita"
  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "clinikita-repo"
  }
}

## AWS IAM Roles (base)
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "clinikita-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_role" {
  name = "clinikita-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# AWS default role policies for both
# Task execution deals with access and managemenet of the ECS agent, the container.
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role deals with acess and management of the task itself, the app
resource "aws_iam_role_policy_attachment" "ecs_task_role_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

## Security Groups
resource "aws_security_group" "app" {
  name        = "clinikita-app-sg"
  description = "Allow all inbound traffic"
  vpc_id      = aws_vpc.main.id

  # Ports should be restricted to access from ELB and whats required for ECS (ECR, Cloudwatch, etc)
  ingress {
    protocol    = "tcp"
    from_port   = 0
    to_port     = 65535
    cidr_blocks = ["0.0.0.0/0"]

  }
  egress {
    protocol    = "tcp"
    from_port   = 0
    to_port     = 65535
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "lb" {
  name        = "clinikita-lb-sg"
  description = "LB security groups. Allow 443 and 80"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "tcp"
    from_port   = 0
    to_port     = 65535
    cidr_blocks = ["0.0.0.0/0"]
  }

}

## VPC, Subnets, Networking
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "clinikita-vpc"
  }
}

# Subnets
resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }

}

# Open up the subnet to the internet
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "clinikita-igw"
  }
}

resource "aws_route_table" "second_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public route table"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "private route table"
  }

}

resource "aws_route_table_association" "public_subnet_asso" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.second_rt.id
}

resource "aws_route_table_association" "private_subnet_asso" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = element(aws_subnet.private_subnets[*].id, count.index)
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_eip" "nat" {
  vpc = true

  tags = {
    Name = "clinikita-nat"
  }
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnets[0].id

  tags = {
    Name = "clinikita-nat"
  }

}


resource "aws_cloudwatch_log_group" "main" {
  name              = "clinikita-logs"
  retention_in_days = 7
}

## ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "clinikita-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

## ECS Task definition
resource "aws_ecs_task_definition" "main" {
  family                   = "clinikita-taskdef"
  network_mode             = "awsvpc"
  cpu                      = var.ecs_container_cpu
  memory                   = var.ecs_container_memory
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn


  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name  = "clinikita-container",
      image = aws_ecr_repository.main.repository_url,
      portMappings = [
        {
          name          = "clinika-container-tcp"
          containerPort = var.cliniquita_app_port
          hostPort      = var.cliniquita_app_port
          protocol      = "tcp"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "clinikita-logs"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "clinikita"
          "awslogs-create-group"  = "true"

        }
      },
      environment = [
        { "name" : "BASIC_AUTH_USER", "value" : var.basic_auth_user },
        { "name" : "BASIC_AUTH_PASSWORD", "value" : var.basic_auth_password },
        { "name" : "CLINIQUITA_APP_PORT", "value" : tostring(var.cliniquita_app_port) }
      ],
      essential = true,
    },
  ])
}

## ECS Service
resource "aws_ecs_service" "main" {
  name                              = "clinikita-service"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.main.arn
  desired_count                     = var.ecs_container_count
  launch_type                       = "FARGATE"
  scheduling_strategy               = "REPLICA"
  health_check_grace_period_seconds = 60

  network_configuration {
    # subnets = aws_subnet.public_subnets[*].id
    subnets          = aws_subnet.private_subnets[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.http_tg.arn
    container_name   = "clinikita-container"
    container_port   = var.cliniquita_app_port
  }

}

resource "aws_s3_bucket_policy" "lb_logs" {
  bucket = aws_s3_bucket.lb_logs.id
  policy = data.aws_iam_policy_document.lb_logs.json
}

## Load Balancer
resource "aws_lb" "main" {
  name                       = "clinikita-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.lb.id]
  subnets                    = aws_subnet.public_subnets[*].id
  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.lb_logs.bucket
    prefix  = "clinikita-lb-logs"
    enabled = true
  }

  tags = {
    Name = "clinikita-lb"
  }
}

resource "aws_lb_target_group" "http_tg" {
  name = "clinikita-tg-http"

  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/amihealthy"
    interval            = 20
    protocol            = "HTTP"
    timeout             = 5
    matcher             = "200"
    unhealthy_threshold = 3
    healthy_threshold   = 5
  }
}

  # This should be HTTPS 443 and the certificate
  # should be handled at the app level to be end to end encrypted.
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/amihealthy"
    interval            = 20
    protocol            = "HTTP"
    timeout             = 5
    matcher             = "200"
    unhealthy_threshold = 3
    healthy_threshold   = 5
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.id
  port              = 443
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn = var.alb_tls_cert_arn

  default_action {
    target_group_arn = aws_lb_target_group.http_tg.arn
    type             = "forward"
  }
}

# Access logs for easier debugging of ELB
resource "aws_s3_bucket" "lb_logs" {
  bucket = "clinikita-lb-logs"

  tags = {
    Name = "clinikita-lb-logs"
  }
}

data "aws_iam_policy_document" "lb_logs" {
  statement {
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.lb_logs.arn}/*",
    ]
    principals {
      identifiers = [var.ELB_account_id]
      type        = "AWS"
    }
  }
}

## Route 53 resources
# Imported default zone into state
# $ terraform import aws_route53_zone.main {zone_id}
resource "aws_route53_zone" "main" {
  name = var.api_zone
}

# Alias record from zone to the load balancer
resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.api_zone}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = false
  }
}
