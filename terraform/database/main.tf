resource "random_password" "db_password" {
  length           = 20
  special          = true
  override_special = "!#%^*()_-+="
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "tsvikli-db-credentials"
  description = "Credentials for Tsvikli MySQL database"
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = "mysql"
    host     = aws_db_instance.tsvikli_db.address
    port     = 3306
    dbname   = var.db_name
  })
}

resource "aws_security_group" "rds_sg" {
  name        = "tsvikli-rds-sg"
  description = "Allow MySQL access within VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidrs
    description = "Allow DB access from private subnets"
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
  skip_final_snapshot       = false
  final_snapshot_identifier = "tsvikli-db-final-snapshot"

  tags = {
    Name = "tsvikli-db"
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../resources/db_init/"
  output_path = "${path.module}/lambda_package.zip"
  excludes    = []
}

resource "aws_iam_role" "lambda_role" {
  name = "tsvikli-db-init-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "tsvikli-db-init-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_s3_access" {
  name = "tsvikli-lambda-s3-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.config_bucket.arn,
          "${aws_s3_bucket.config_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_lambda_function" "db_initializer" {
  function_name = "tsvikli-db-init"
  handler       = "lambda.lambda_handler"
  runtime       = "python3.11"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  role = aws_iam_role.lambda_role.arn

  timeout = 120

  vpc_config {
    subnet_ids         = var.private_subnets
    security_group_ids = [aws_security_group.rds_sg.id]
  }

  environment {
    variables = {
      DB_SECRET_NAME = aws_secretsmanager_secret.db_credentials.name
    }
  }
}

resource "aws_lambda_invocation" "db_init" {
  function_name = aws_lambda_function.db_initializer.function_name
  input         = "{}"

  depends_on = [
    aws_db_instance.tsvikli_db,
    aws_lambda_function.db_initializer
  ]
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "config_bucket" {
  bucket        = "tsvikli-config-${random_id.suffix.hex}"
  force_destroy = true

  tags = {
    Project = "Tsvikli Config"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config_bucket_encryption" {
  bucket = aws_s3_bucket.config_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "config_file" {
  bucket = aws_s3_bucket.config_bucket.id
  key    = "config.yaml"
  source = "${path.module}/../../config.yaml"
  etag   = filemd5("${path.module}/../../config.yaml")

  depends_on = [
    aws_s3_bucket.config_bucket,
    aws_s3_bucket_notification.config_bucket_notification
  ]
}

data "archive_file" "db_update_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../resources/db_update/"
  output_path = "${path.module}/db_update_lambda_package.zip"
}

resource "aws_lambda_function" "config_updater" {
  function_name    = "tsvikli-config-updater"
  handler          = "lambda.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.db_update_lambda_zip.output_path
  source_code_hash = data.archive_file.db_update_lambda_zip.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  timeout          = 120

  vpc_config {
    subnet_ids         = var.private_subnets
    security_group_ids = [aws_security_group.rds_sg.id]
  }

  environment {
    variables = {
      DB_SECRET_NAME = aws_secretsmanager_secret.db_credentials.name
      CONFIG_BUCKET  = aws_s3_bucket.config_bucket.bucket
      CONFIG_KEY     = "config.yaml"
    }
  }
}

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.config_updater.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.config_bucket.arn
}

resource "aws_s3_bucket_notification" "config_bucket_notification" {
  bucket = aws_s3_bucket.config_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.config_updater.arn
    events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_prefix       = "config.yaml"
  }

  depends_on = [
    aws_lambda_permission.allow_s3_invoke
  ]
}
