##### EC2 Instance #####

module "ec2" {
  source      = "../."
  ec2_name    = "ec2-vpc-b"
  vpc_name    = "VPC-B"
  subnet_name = "VPC-B-private-us-east-1b"
}