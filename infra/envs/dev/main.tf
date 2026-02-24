terraform {
    required_version = ">= 1.14.5"

    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }

    backend "local" {}
}

provider "aws" {
    region = var.region
}

resource "aws_cloudwatch_log_group" "core" {
    name              = "/${var.project_name}/core"
    retention_in_days = 14
    
    tags = {
        Project = var.project_name
        Environment = "dev"
        ManagedBy = "terraform"
    }
}