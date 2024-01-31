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
  profile = "#yourprofile"
}

################  VPC Section  ####################

## VPC
resource "aws_vpc" "test_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "test-vpc"
  }
}

### public Subnet 
resource "aws_subnet" "subnets" {

  for_each = var.aws_subnets

  availability_zone = each.value.availability_zone
  cidr_block        = each.value.cidr_block

  vpc_id                  = aws_vpc.test_vpc.id
  map_public_ip_on_launch = true
}

#### Internet Gateway ####

resource "aws_internet_gateway" "cloud_internet_gateway" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name = "cloud igw"
  }
}

###############  EC2 Section  ####################
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

### EC2 instance - SG

resource "aws_security_group" "ec2-sg" {
  name   = "ec2 security group"
  vpc_id = aws_vpc.test_vpc.id

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

### actual ec2 instance

resource "aws_instance" "test_instance" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2-sg.id]
  key_name                    = "alexbol-sandbox"
  subnet_id                   = aws_subnet.subnets["private-subnet-az-a"].id
  user_data                   = file("userdata.sh")

  tags = {
    Name    = "test instance"
    Service = "testing"
    Team    = "testing"
  }
}


#### output the public ip so I dont have to find it in the console ####
output "public_ip" {
  value = aws_instance.test_instance.public_ip
}


###############  NLB Section  ####################
resource "aws_lb" "test-nlb" {
  name               = "test-nlb-tf"
  internal           = false
  load_balancer_type = "network"
  subnets            = values(aws_subnet.subnets)[*].id

  enable_deletion_protection = false

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "test-tg-nlb" {
  name     = "tf-nlb-tg"
  port     = 80
  protocol = "TCP"
  target_type = "ip"
  ### usefull for proxy protocol and see the client's original ip instead of the nlb ip
  proxy_protocol_v2 = true
  preserve_client_ip = true

  vpc_id   = aws_vpc.test_vpc.id
}

resource "aws_lb_target_group_attachment" "test-tg-attachement-nlb" {
  target_group_arn = aws_lb_target_group.test-tg-nlb.arn
  target_id = aws_instance.test_instance.private_ip
  port             = 80
}

resource "aws_lb_listener" "nlb_listener" {
  load_balancer_arn = aws_lb.test-nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test-tg-nlb.arn
  }
}



###############  ALB Section  ####################
# resource "aws_lb" "demo-alb" {
#   name               = "test-lb-tf"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.ec2-sg.id]
#   subnets            = values(aws_subnet.subnets)[*].id

#   enable_deletion_protection = false

#   tags = {
#     Environment = "demo alb"
#   }
# }

# resource "aws_lb_listener" "test-listener" {
#   load_balancer_arn = aws_lb.demo-alb.arn
#   port              = "80"
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.test-tg.arn
#   }
# }

# resource "aws_lb_target_group" "test-ssh-tg" {
#   name     = "tf-example-lb-tg-ssh"
#   port     = 22
#   protocol = "TCP"
#   vpc_id   = aws_vpc.test_vpc.id
# }

# resource "aws_lb_target_group" "test-tg" {
#   name     = "tf-example-lb-tg"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.test_vpc.id
#   health_check {
#     enabled             = true
#     healthy_threshold   = 3
#     unhealthy_threshold = 3
#     timeout             = 10
#     interval            = 30
#     path                = "/"
#     protocol            = "HTTP"
#   }
# }

# resource "aws_lb_target_group_attachment" "test-tg-attachement" {
#   target_group_arn = aws_lb_target_group.test-tg.arn
#   target_id        = aws_instance.test_instance.id
#   port             = 80
# }
