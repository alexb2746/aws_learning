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

  name = "VPC-A"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a"]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.0.0/24"]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}