##### EC2 Instance #####

module "ec2" {
  source      = "../../."
  ec2_name    = "ec2-vpc-a-public"
  vpc_name    = "VPC-A"
  subnet_name = "VPC-A-public-us-east-1a"
  public = true
}
