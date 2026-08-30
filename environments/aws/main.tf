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
resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-central-1b"

  tags = {
    Name = "devops-lab-public-b"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "eu-central-1a"

  tags = {
    Name = "devops-lab-private-a"
  }
}


resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "devops-lab-private"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

# Add elastic IP for domain vpc
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "devops-lab-nat-eip"
  }
}

# Create a NAT Gateway in the public subnet to allow outbound Internet access for private subnets.
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "devops-lab-nat"
  }
}

# add a route to the private route table that directs Internet-bound traffic to the NAT Gateway.
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
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
