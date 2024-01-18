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

### Private Cloud Subnet 2 and route table
resource "aws_subnet" "cloud-private-2" {
  vpc_id     = aws_vpc.cloud.id
  cidr_block = "10.0.11.0/24"

  tags = {
    Name = "cloud-private-2"
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
  route_table_id = aws_route_table.cloud_public_subnet_route_table.id
}

resource "aws_route_table_association" "cloud_private2_association_route_table" {
  subnet_id      = aws_subnet.cloud-private-2.id
  route_table_id = aws_route_table.cloud_public_subnet_route_table.id
}

### Public Cloud subnet and route table

resource "aws_subnet" "cloud-public-1" {
  vpc_id     = aws_vpc.cloud.id
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "cloud-public-1"
  }
}

resource "aws_route_table" "cloud_public_subnet_route_table" {
  vpc_id = aws_vpc.cloud.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cloud_internet_gateway.id
  }
  tags = {
    name = "cloud_public_subnet_route_table"
  }
}

resource "aws_route_table_association" "cloud_public_association_route_table" {
  subnet_id      = aws_subnet.cloud-public-1.id
  route_table_id = aws_route_table.cloud_public_subnet_route_table.id
}



### EC2 instance - Cloud app

resource "aws_instance" "cloud-app" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.cloud-app-sg.id]
  key_name                    = "alexbol-sandbox"
  subnet_id                   = aws_subnet.cloud-public-1.id

  tags = {
    Name    = "Cloud app"
    Service = " - testing"
    Team    = ""
  }
}

### EC2 instance - SG

resource "aws_security_group" "cloud-app-sg" {
  name   = "ubuntu security group"
  vpc_id = aws_vpc.cloud.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = #your public ips in an array
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8", "192.168.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

### Inbound resolver SG ##

resource "aws_security_group" "inbound_outbound_resolver_sg" {
  name   = "Inbound resolver security group"
  vpc_id = aws_vpc.cloud.id

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "UDP"
    cidr_blocks = ["10.0.0.0/8", "192.168.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#### Cloud Virtual Gateway
resource "aws_vpn_gateway" "cloud_vgw" {
  vpc_id = aws_vpc.cloud.id

  tags = {
    Name = "cloud vgw"
  }
}

#### Cloud customer Gateway
resource "aws_customer_gateway" "cloud_cgw" {
  bgp_asn    = 65000
  ip_address = aws_instance.onprem-vpn-server.public_ip
  type       = "ipsec.1"
  depends_on = [aws_instance.cloud-app]
  tags = {
    Name = "on-prem vpn-server"
  }
}

#### Cloud to on-prem VPN connection
resource "aws_vpn_connection" "vpn_to_onprem" {
  vpn_gateway_id           = aws_vpn_gateway.cloud_vgw.id
  customer_gateway_id      = aws_customer_gateway.cloud_cgw.id
  type                     = "ipsec.1"
  static_routes_only       = true
  local_ipv4_network_cidr  = "192.168.0.0/16"
  outside_ip_address_type  = "PublicIpv4"
  remote_ipv4_network_cidr = "10.0.0.0/16"
  depends_on               = [aws_customer_gateway.cloud_cgw, aws_vpn_gateway.cloud_vgw, aws_instance.cloud-app]
}

### propgate vpn route to route tables
resource "aws_vpn_gateway_route_propagation" "route_propagation_public" {
  vpn_gateway_id = aws_vpn_connection.vpn_to_onprem.vpn_gateway_id
  route_table_id = aws_route_table.cloud_public_subnet_route_table.id
}

resource "aws_vpn_gateway_route_propagation" "route_propagation_private" {
  vpn_gateway_id = aws_vpn_connection.vpn_to_onprem.vpn_gateway_id
  route_table_id = aws_route_table.cloud_private_subnet_route_table.id
}


### static route entry for vpn
resource "aws_vpn_connection_route" "office" {
  destination_cidr_block = "192.168.0.0/16"
  vpn_connection_id      = aws_vpn_connection.vpn_to_onprem.id
}

###### DNS Zone #########
resource "aws_route53_zone" "cloud_dns_zone" {
  name = "cloud.com"
  vpc {
    vpc_id = aws_vpc.cloud.id
  }
}

###### DNS Records #########

resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.cloud_dns_zone.zone_id
  name    = "app"
  type    = "A"
  ttl     = 300
  records = [aws_instance.cloud-app.private_ip]
}

### DNS endpoint resolvers ###

resource "aws_route53_resolver_endpoint" "inbound-endpoint" {
  name      = "inbound-endpoint"
  direction = "INBOUND"

  security_group_ids = [
    aws_security_group.inbound_outbound_resolver_sg.id,
  ]

  ip_address {
    subnet_id = aws_subnet.cloud-private-1.id
    ip        = "10.0.10.63"
  }

  ip_address {
    subnet_id = aws_subnet.cloud-private-2.id
    ip        = "10.0.11.119"
  }

  tags = {
    Environment = "testing"
  }
}

### Outbound
resource "aws_route53_resolver_endpoint" "outbound-endpoint" {
  name      = "outbound-endpoint"
  direction = "OUTBOUND"

  security_group_ids = [
    aws_security_group.inbound_outbound_resolver_sg.id,
  ]

  ip_address {
    subnet_id = aws_subnet.cloud-private-1.id
  }

  ip_address {
    subnet_id = aws_subnet.cloud-private-2.id
  }

  tags = {
    Environment = "testing"
  }
}

### Outbound DNS forwarder rule
resource "aws_route53_resolver_rule" "onprem_rule" {
  domain_name          = "app.onprem.com"
  name                 = "onprem"
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound-endpoint.id

  target_ip {
    ip = "192.168.10.152"
  }

}

#assoicate to VPC
resource "aws_route53_resolver_rule_association" "assoicate_rule_to_vpc" {
  resolver_rule_id = aws_route53_resolver_rule.onprem_rule.id
  vpc_id           = aws_vpc.cloud.id
}

###################################
###################################
###################################
###################################
#### "on-prem" setup for LAB #####
###################################
###################################
###################################
###################################

## VPC
resource "aws_vpc" "onprem" {
  cidr_block = "192.168.0.0/16"
  tags = {
    Name = "onprem-vpc"
  }
}

### Internet gateway
resource "aws_internet_gateway" "onprem_internet_gateway" {
  vpc_id = aws_vpc.onprem.id

  tags = {
    Name = "onprem"
  }
}

### Public ip for NAT gateway
resource "aws_eip" "onprem-pub-ip-1" {
}


### Nat gateway
resource "aws_nat_gateway" "onprem_nat_gateway" {
  allocation_id = aws_eip.onprem-pub-ip-1.id
  subnet_id     = aws_subnet.onprem-public-1.id

  tags = {
    Name = "gw NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.onprem_internet_gateway]
}

### Private On-prem Subnet 1 and route table
resource "aws_subnet" "onprem-private-1" {
  vpc_id     = aws_vpc.onprem.id
  cidr_block = "192.168.10.0/24"

  tags = {
    Name = "onprem-private-1"
  }
}

### Private On-prem Subnet 2 and route table

resource "aws_subnet" "onprem-private-2" {
  vpc_id     = aws_vpc.onprem.id
  cidr_block = "192.168.11.0/24"

  tags = {
    Name = "onprem-private-2"
  }
}



### onprem private route tables

resource "aws_route_table" "onprem_private_subnet_route_table" {
  vpc_id = aws_vpc.onprem.id

  route {
    cidr_block           = "10.0.0.0/16"
    network_interface_id = aws_instance.onprem-vpn-server.primary_network_interface_id
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.onprem_nat_gateway.id
  }
  tags = {
    name = "onprem_private_subnet_route_table"
  }
}

resource "aws_route_table_association" "onprem_private1_association_route_table" {
  subnet_id      = aws_subnet.onprem-private-1.id
  route_table_id = aws_route_table.onprem_private_subnet_route_table.id
}

resource "aws_route_table_association" "onprem_private2_association_route_table" {
  subnet_id      = aws_subnet.onprem-private-2.id
  route_table_id = aws_route_table.onprem_private_subnet_route_table.id
}

### Public On-prem Subnet 1 and route table

resource "aws_subnet" "onprem-public-1" {
  vpc_id     = aws_vpc.onprem.id
  cidr_block = "192.168.0.0/24"

  tags = {
    Name = "onprem-public-1"
  }
}

resource "aws_route_table" "onprem_public_subnet_route_table" {
  vpc_id = aws_vpc.onprem.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.onprem_internet_gateway.id
  }
}

resource "aws_route_table_association" "onprem_public_route_table" {
  subnet_id      = aws_subnet.onprem-public-1.id
  route_table_id = aws_route_table.onprem_public_subnet_route_table.id
}

############ EC2 SG - VPN ######

resource "aws_security_group" "onprem-vpn-server" {
  name   = "ubuntu security group 2"
  vpc_id = aws_vpc.onprem.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = #your public ips in an array
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8", "192.168.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#### EC2 VPN Server
resource "aws_instance" "onprem-vpn-server" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.onprem-vpn-server.id]
  key_name                    = "alexbol-sandbox"
  subnet_id                   = aws_subnet.onprem-public-1.id
  source_dest_check           = false

  tags = {
    Name    = "on-prem VPN SERVER"
    Service = " - testing"
    Team    = "testing"
  }
}

#### onprem app server
resource "aws_instance" "onprem-app" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t2.micro"
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.onprem-vpn-server.id]
  key_name                    = "alexbol-sandbox"
  subnet_id                   = aws_subnet.onprem-private-2.id

  tags = {
    Name    = "on-prem app server"
    Service = " - testing"
    Team    = "testing"
  }
}

#### EC2 VPN Server
resource "aws_instance" "onprem-DNS-server" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.onprem-vpn-server.id]
  key_name               = "alexbol-sandbox"
  subnet_id              = aws_subnet.onprem-private-1.id

  tags = {
    Name    = "on-prem DNS SERVER"
    Service = " - testing"
    Team    = "testing"
  }
}
