resource "aws_instance" "terraform_demo" {
    ami = "ami-0220d79f3f480ecf5"
    instance_type = "t3.micro"
    vpc_security_group_ids = [aws_security_group.allow_terraform.id] # list
    # labels, metadata, info, etc
    tags = {
        Name = "terraform-demo-1"
        Project = "roboshop"
        Environment = "dev"
    }
}

# It creates in default VPC
resource "aws_security_group" "allow_terraform" {
  name        = "allow_terraform"
  description = "Allow TLS inbound traffic and all outbound traffic"

  # outbound traffic
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1" # all traffic
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_terraform"
    Project = "roboshop"
    Environment = "dev"
  }
}