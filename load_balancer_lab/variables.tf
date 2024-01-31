variable "aws_subnets" {
  default = {
    private-subnet-az-a = {
      cidr_block        = "10.0.10.0/24"
      availability_zone = "us-east-1a"
    }
    private-subnet-az-b = {
      cidr_block        = "10.0.11.0/24"
      availability_zone = "us-east-1b"
    }
    private-subnet-az-c = {
      cidr_block        = "10.0.12.0/24"
      availability_zone = "us-east-1c"
    }
  }
}