terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-east-1"
  profile = "znet-sandbox"
}


module "vpc-tgw" {
  source = "../."
  vpc_name = "VPC-A"
  subnet_name = "VPC-A-private-us-east-1a"
}