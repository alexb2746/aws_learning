##### EC2 Instance #####


module "ec2" {
  source      = "../."
  ec2_name    = "ec2-vpc-a"
  vpc_name    = "VPC-A"
  subnet_name = "VPC-A-private-us-east-1a"
}
