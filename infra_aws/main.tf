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
  region = var.aws_region
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
# Task execution deals with access and managemenet of the ECS agent, the container.
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy_attachment" "ecs_task_role_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
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
    Name = "2nd Route Table"
  }
}

resource "aws_route_table_association" "public_subnet_asso" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.second_rt.id
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
