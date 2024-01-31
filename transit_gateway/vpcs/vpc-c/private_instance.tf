##### EC2 Instance #####

module "ec2" {
  source      = "../."
  ec2_name    = "ec2-vpc-c"
  vpc_name    = "VPC-C"
  subnet_name = "VPC-C-private-us-east-1c"
}