#DEFINE AWS PROVIDER
provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIAXTG2VY3C33WJRPNV"
  secret_key = "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"
}
#CREATE A VPC
resource "aws_vpc" "myvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "My_VPC-1"
  }
}
#CREATE A SUBNET (APPLICATION SEGMENT)
resource "aws_subnet" "mysubnet" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_lunch= true
  depends_on=[aws_vpc.myvpc]
 
  tags = {
    Name = "My_subnet"
  }
}
#DEFINE ROUTE TABLE
resource "aws_route_table" "my_rt" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "My_RT1"
  }
}
#ASSOCIATE SUBNET WITH ROUTE TABLE
resource "aws_route_table_association" "RT_association" {
  subnet_id      = aws_subnet.mysubnet.id
  route_table_id = aws_route_table.my_rt.id
}
#CREATE INTERNET GATEWAY FOR ACCESS TO INTERNET
resource "aws_internet_gateway" "Mygw" {
  vpc_id = aws_vpc.myvpc.id
  depends_on=[aws_vpc.myvpc]

  tags = {
    Name = "My_IGW1"
  }
}
#ADD DEFAULT ROUTE IN ROUTING TABLE TO CONNECT TO My_IGW
resource "aws_route" "default_rt"{
    route_table_id = aws_route_table.my_rt.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Mygw.id
}   
#CREATE SECURITY GROUP
resource "aws_security_group" "My_SG1" {
  name        = "My_SG1"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id
   ingress {
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    protocol         = "tcp"
    from_port        = 22
    to_port          = 22
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
  }
}
#CREATE A PRIVATE KEY REQUIRED FOR LOGIN
resource "tls_private_key" "Key_1" {
  algorithm   = "RSA"
}
#SAVE PUBLIC KEY FROM GENERATED KEY
resource "aws_key_pair" "Aws_key"{
    key_name = "Aws_key"
    public_key = tls_private_key.Aws_key.public_key_openssh
}
#SAVE THE KEY TO LOCAL SYSTEM
resource "local_file" "Aws_key" {
    content     = tls_private_key.Aws_key.private_key_pem
    filename = "Aws_key.pem"
}
#CREATE A WEBSERVER INSTANCE
resource "aws_instance" "server"{
    ami =""
    instance_type = "t2.micro"
    tags= {
        name = "Server1"
    }
    count = 1
    subnet_id =aws_subnet.mysubnet.id
    key_name = "Aws_key"
    security_group =[aws_security_group.My_SG1.id]
    provisioner "remote_exec"{
        connection {
            type ="ssh"
            user ="ec2-user"
            private_key = tls_private_key.Aws_key.private_key_pem
            host = aws_instance.server[0].public_ip
        }
        inline =[
            "sudo yum install httpd php git -y",
            "sudo systemctl restart httpd",
            "sudo systemctl enable httpd",
        ]
    }
}
#CREATE A BLOCK VOLUME FOR DATA (EBS) 
resource "aws_ebs_volume" "myebs" {
  availability_zone = aws_instance.server[0].availability_zone
  size   = 1

  tags = {
    Name = "volebs"
  }
}
#ATTACH THE VOLUME TO YOUR INSTANCE
resource "aws_volume_attachment" "att_ebs" {
  depends_on = [aws_ebs_volume.myebs]
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.myebs.id
  instance_id = aws_instance.server[0].id
  force_detach = true
}
#MOUNT THE VOLUME TO YOUR INSTANCE
resource "null_resource" "mount"{
    depends_on =[aws_volume_attachment.att_ebs]
    connection {
        type ="ssh"
        user ="ec2-user"
        private_key = tls_private_key.Aws_key.private_key_pem
        host= aws_instance.server[0].public_ip
    }
    provisioner "remote exec"{
        inline = [
            "sudo mkf.ext4/dev/xvdh",
            "sudo mount /dev/xvdh/var/www/html",
            "sudo rm -rf/var/www/html",
            "sudo git clone https://github.com/binay20/Terraform-LAB.binay1"
        ]
    }
}
#DEFINE S3 BUCKET(ID)
locals {
    s3_origin_id ="s3_origin"
}
#CREATE A S3 BUCKET TO UPLOAD DATA
resource "aws_s3_bucket" "demobucket2021" {
  bucket = "my-tf-testbucket"
  acl    = "public-read-write"
  region = "ap-south-1"

  versioning {
      enabled =true
  }

  tags = {
    Name        = "my-tf-testbucket"
    Environment = "production"
   }
  provisioner "local-exec"{
    command="https://github.com/binay20/Terraform-LAB"
   }

}
#ALLOW PUBLIC ACCES TO THE BUCKET
resource "aws_s3_bucket_public_access_block" "public_access" {
  depends_on = [aws_s3_bucket.demobucket2021]
  bucket = aws_s3_bucket.demobucket2021.id

  block_public_acls   = false
  block_public_policy = false
}
#UPLOAD DATA IN S3 BUCKET
resource "aws_s3_bucket_object" "object2" {
  bucket = "demobucket2021"
  acl = "public-read-write"
  key    = "binay1.PNG"
  source = "binay1.PNG"
}
#CREATE A CLOUDFRONT DISTRIBUTION FOR CDN 
resource "aws_cloudfront_distribution" "s3_cloudfront" {
  depends_on = [aws_s3_bucket_object.object2]  
  origin {
    domain_name = aws_s3_bucket.demobucket2021.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
  }
  enabled = true
    default_cache_behavior {
        allowed_methods = ["DLETE","GET","HEAD","OPTIONS","POST","PUT"]
        cached_methods = ["GET","HEAD"]
        target_origin_id = local.s3_origin_id

        forwarded_values {
            query_sring = false

            cookies {
                forward ="none"
            }
        }
        viewer_protocol_policy ="allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }

    restrictions {
        geo_restrictions {
            restriction_type = "none"
        }
    }
        veiwer_certificate {
            cloudfront_default_certificate = true
        }
}
#UPDATE THE CDN IMAGE URL TO YOUR WEBSERVER CODE
resource "null_resource" "write_image"{
    depends_on = [aws_cloudfront_distribution.s3_cloudfront]
    connection {
    type = "ssh"
    user = "ec2-user"
    private_key = tls_private_key.Aws_key.private_key_pem
    host = aws_instance.server[0].public_ip
     }
  provisioner "remote_exec" {
        inline = [
          "sudo su << EOF",
                  "echo \"<img src= 'http://${aws_cloudfront_distribution.s3_cloudfront.domain_name}/${aws_s3_bucket_object.object2.key}' width= '300' height='380'>\" >>/var/www/html/index.html",
                  "echo \"</body>\" >>/var/www/html/index.html",
                  "echo \"</html>\" >>var/www/html/index.html",
                  "EOF"
        ]
  }
}
#SUCCESS MESSAGE AND STORING THE RESULT IN A FILE
resource "null_resource" "result" {
  depends_on = [null_resource.mount]
  provisioner "local-exec" {
    command = "WEBSITE IS SUCCESSFULLY DEPLOYED ON AWS CLOUD and >> result.txt && echo the ip of the website is ${aws_instance.server[0].public_ip} >>result.txt"
  }
}
#TEST THE APPLICATION
resource "null_resource" "running_site" {
  depends_on = [null_resource.write_image]
  provisioner "local-exec" {
    command = "start chrome ${aws_instance.server[0].public_ip}"
  }
}