resource "aws_db_subnet_group" "postgres" {
  name = "petclinic-postgres"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  tags = {
    Name = "petclinic-postgres"
  }
}


# Dedicated Security Group for PostgreSQL.
# TODO
# For the initial implementation we allow
# PostgreSQL traffic from the VPC CIDR.
#
# Later we will tighten this to the appropriate EKS
# workload/node security group.
resource "aws_security_group" "postgres" {
  name        = "petclinic-postgres"
  description = "Security group for Petclinic PostgreSQL RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    
    # For now we allow access from the VPC CIDR.
    # Later we will tighten this to the appropriate EKS workload/node security group.
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "petclinic-postgres"
  }
}


# Single-AZ is intentional
# Multi-AZ can be evaluated later as part of the production review
resource "aws_db_instance" "postgres" {
  identifier = "petclinic-postgres"

  engine         = "postgres"
  engine_version = "16"

  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "petclinic"
  username = "petclinic"
  password = "petclinic"

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]

  publicly_accessible = false

  storage_encrypted = true

  backup_retention_period = 1

  multi_az = false

  deletion_protection = false

  skip_final_snapshot = true

  tags = {
    Name = "petclinic-postgres"
  }
}
