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

variable "vpc_name" {
  type = string
}

variable "subnet_name" {
  type = string
}

data "aws_ec2_transit_gateway" "tgw" {
  filter {
    name   = "options.amazon-side-asn"
    values = ["64512"]
  }
}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnet" "private" {
  vpc_id = data.aws_vpc.vpc.id
  filter {
    name   = "tag:Name"
    values = [var.subnet_name]
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc" {
  subnet_ids         = [data.aws_subnet.private.id]
  transit_gateway_id = data.aws_ec2_transit_gateway.tgw.id
  vpc_id             = data.aws_vpc.vpc.id
}

data "aws_route_table" "selected" {
  subnet_id = data.aws_subnet.private.id
}

resource "aws_route" "routes_to_tgw" {
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.vpc]
  route_table_id         = data.aws_route_table.selected.id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = data.aws_ec2_transit_gateway.tgw.id

}