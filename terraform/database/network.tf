resource "aws_security_group" "rds_sg" {
  name   = "tsvikli-rds-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tsvikli-rds-sg"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "tsvikli-db-subnet-group"
  subnet_ids = var.private_subnets

  tags = {
    Name = "tsvikli-db-subnet-group"
  }
}
