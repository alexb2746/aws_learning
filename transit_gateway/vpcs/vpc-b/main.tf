terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-east-1"
  profile = "znet-sandbox"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "VPC-B"
  cidr = "10.1.0.0/16"

  azs             = ["us-east-1b"]
  private_subnets = ["10.1.0.0/24"]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}


