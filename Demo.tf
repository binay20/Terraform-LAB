#LOGIN TO AWS USER

provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIAXTG2VY3C33WJRPNV"
  secret_key = "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"
}
#INSTANCE CREATION 

resource "aws_instance" "ap-south-1" {
  ami           = "ami-010aff33ed5991201" # ap-south-1
  instance_type = "t2.micro"
}
#S3 BUCKET CREATION

resource "aws_s3_bucket" "MyBucket-2121" {
  bucket = "my-easy-terraform-test-bucket"
  acl    = "private"

  tags = {
    Name        = "My terraform bucket"
    Environment = "Dev-Env"
  }
  versioning{
   enabled=true
   }
}
#VPC CREATION

resource "aws_vpc" "dev" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "prod-vpc"
  }
}
# SUBNET CREATION

resource "aws_subnet" "sub" {
  vpc_id     = aws_vpc.dev.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "subnet1"
  }
}
#USING FUNCTIONS
resource "aws_instance" "app-dev" {
   ami = lookup(var.ami,var.region)
   instance_type = "t2.micro"
   count = 2

   tags = {
     Name = element(var.tags,count.index)
   }
}
#CREATING LOAD BALANCER
resource "aws_elb" "bar" {
  name               = var.elb_name
  availability_zones = var.az

   listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8000/"
    interval            = 30
  }
  cross_zone_load_balancing   = true
  idle_timeout                = var.timeout
  connection_draining         = true
  connection_draining_timeout = var.timeout
}  