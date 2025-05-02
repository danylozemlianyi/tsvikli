resource "aws_kms_key" "db_key" {
  description = "KMS key for encrypting Tsvikli RDS database"
}

resource "aws_db_instance" "tsvikli_db" {
  identifier             = "tsvikli-db"
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0.35"
  instance_class         = "db.t3.micro"
  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.db_key.arn
  multi_az               = false
  publicly_accessible    = false

  backup_retention_period   = 7
  deletion_protection       = false
  skip_final_snapshot       = true
  final_snapshot_identifier = "tsvikli-db-final-snapshot"

  tags = {
    Name = "tsvikli-db"
  }
}
