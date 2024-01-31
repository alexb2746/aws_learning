terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-east-1"
  profile = "znet-sandbox"
}

###################################
###################################
#### Cloud setup for LAB #####
###################################
###################################

### Data to grab amazon linux 2 ami

data "aws_ami" "amazon_linux_2" {
  most_recent = true

  filter {
    name = "name"
    // Please note that exact name filter can differ depending on region and type of instance
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  // This is the Amazon owner ID for public AMIs
  owners = ["137112412989"]
}

## VPC
resource "aws_vpc" "cloud" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "cloud-vpc"
  }
}


### Internet gateway
resource "aws_internet_gateway" "cloud_internet_gateway" {
  vpc_id = aws_vpc.cloud.id

  tags = {
    Name = "cloud igw"
  }
}

### Private Cloud Subnet 1 and route table
resource "aws_subnet" "cloud-private-1" {
  vpc_id     = aws_vpc.cloud.id
  cidr_block = "10.0.10.0/24"

  tags = {
    Name = "cloud-private-1"
  }
}

### cloud private route tables

resource "aws_route_table" "cloud_private_subnet_route_table" {
  vpc_id = aws_vpc.cloud.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cloud_internet_gateway.id
  }
  tags = {
    name = "cloud_public_subnet_route_table"
  }
}

resource "aws_route_table_association" "cloud_private1_association_route_table" {
  subnet_id      = aws_subnet.cloud-private-1.id
  route_table_id = aws_route_table.cloud_private_subnet_route_table.id
}

### EC2 instance - Cloud app

resource "aws_instance" "cloud-app" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.cloud-app-sg.id]
  key_name                    = "alexbol-sandbox"
  subnet_id                   = aws_subnet.cloud-private-1.id

  tags = {
    Name    = "Cloud app"
    Service = " - testing"
    Team    = ""
  }
}

output "public_ip" {
  value = aws_instance.cloud-app.public_ip
}

### EC2 instance - SG

resource "aws_security_group" "cloud-app-sg" {
  name   = "ubuntu security group"
  vpc_id = aws_vpc.cloud.id

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



##### Analysis #####
resource "aws_ec2_network_insights_path" "path" {
  source      = aws_instance.cloud-app.primary_network_interface_id
  destination = aws_internet_gateway.cloud_internet_gateway.id
  protocol    = "tcp"
}

resource "aws_ec2_network_insights_analysis" "analysis" {
  network_insights_path_id = aws_ec2_network_insights_path.path.id
}


### ACL 

resource "aws_network_acl" "main" {
  vpc_id = aws_vpc.cloud.id
  subnet_ids = [ aws_subnet.cloud-private-1.id ]

  egress {
    protocol   = "-1"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "main"
  }
}