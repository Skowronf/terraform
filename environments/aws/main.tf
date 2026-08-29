# Main VPC for the AWS environment.
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16" # 65,536 private IPv4 addresses.

  tags = {
    Name = "petclinic-vpc"
  }
}

# Public subnet in Availability Zone A.
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-central-1a"

  tags = {
    Name = "devops-lab-public-a"
  }
}

# Public subnet in Availability Zone B.
# A second AZ provides basic high-availability across zones.
resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-central-1b"

  tags = {
    Name = "devops-lab-public-b"
  }
}

# Internet Gateway provides a path between the VPC and the Internet.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "devops-lab-igw"
  }
}

# Route table for public subnets.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "devops-lab-public"
  }
}

# Send Internet-bound traffic from public subnets through the Internet Gateway.
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Associate subnet A with the public route table.
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

# Associate subnet B with the public route table.
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}
