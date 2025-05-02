data "archive_file" "db_update_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../resources/db_update/"
  output_path = "${path.module}/db_update_lambda_package.zip"
}

resource "aws_lambda_function" "config_updater" {
  function_name                      = "tsvikli-config-updater"
  handler                            = "lambda.lambda_handler"
  runtime                            = "python3.11"
  filename                           = data.archive_file.db_update_lambda_zip.output_path
  source_code_hash                   = data.archive_file.db_update_lambda_zip.output_base64sha256
  role                               = aws_iam_role.lambda_role.arn
  timeout                            = 120
  replace_security_groups_on_destroy = true

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
  depends_on = [
    aws_secretsmanager_secret_version.db_credentials_version,
    aws_db_instance.tsvikli_db,
  ]
}
