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


##### EC2 Instance #####

variable "vpc_name" {
  type = string
}

variable "subnet_name" {
  type = string
}

data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnet" "subnet" {
  vpc_id = data.aws_vpc.vpc.id
  filter {
    name   = "tag:Name"
    values = [var.subnet_name]
  }
}

variable "sg_name" {
  type = string
  default = "allow_inbound_all_outbound"
}

variable "ec2_name" {
  type = string
}

variable "public" {
    type    = bool
    default = false
}

data "aws_ami" "latest_ubuntu_22_04" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_security_group" "allow_inbound_all_outbound" {
  name   = var.sg_name
  vpc_id = data.aws_vpc.vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ec2-vpc" {
  ami                    = data.aws_ami.latest_ubuntu_22_04.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_inbound_all_outbound.id]
  key_name               = "alexbol-sandbox"
  subnet_id              = data.aws_subnet.subnet.id
  associate_public_ip_address = var.public

  tags = {
    Name    = var.ec2_name
    Service = "ZNET - lab"
    Team    = "ZNET"
  }
}
