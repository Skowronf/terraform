resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16" # addresses 10.0.0.0–10.0.255.255.

  tags = {
    Name = "petclinic-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-central-1a"

  tags = {
    Name = "devops-lab-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-central-1b"

  tags = {
    Name = "devops-lab-public-b"
  }
}