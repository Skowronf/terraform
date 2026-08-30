# Small EC2 instance used to verify the VPC networking setup.
resource "aws_instance" "test" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  subnet_id = aws_subnet.private_a.id

  # Attach the Security Group created for public resources.
  vpc_security_group_ids = [
    aws_security_group.public.id
  ]

  tags = {
    Name = "devops-lab-test"
  }
}


# Find the latest Amazon Linux 2023 AMI available in the configured region.
data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

