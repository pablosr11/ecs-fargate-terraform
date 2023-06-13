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

