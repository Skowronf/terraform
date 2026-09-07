# Security Group for resources exposed to the Internet.
resource "aws_security_group" "public" {
  name        = "devops-lab-public"
  description = "Allow public HTTP and HTTPS traffic"
  vpc_id      = aws_vpc.main.id

  # Allow HTTP traffic from the Internet.
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS traffic from the Internet.
  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow resources to initiate outbound connections.
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devops-lab-public"
  }
}
