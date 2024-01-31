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

resource "aws_ec2_transit_gateway" "tgw" {
  description = "lab tgw"
  dns_support = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

}