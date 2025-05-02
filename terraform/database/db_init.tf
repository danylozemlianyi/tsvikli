data "archive_file" "init_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../resources/db_init/"
  output_path = "${path.module}/lambda_package.zip"
  excludes    = []
}

resource "aws_lambda_function" "db_initializer" {
  function_name = "tsvikli-db-init"
  handler       = "lambda.lambda_handler"
  runtime       = "python3.11"

  filename                           = data.archive_file.init_lambda_zip.output_path
  source_code_hash                   = data.archive_file.init_lambda_zip.output_base64sha256
  replace_security_groups_on_destroy = true

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

  depends_on = [aws_secretsmanager_secret_version.db_credentials_version, aws_db_instance.tsvikli_db]
}

resource "aws_lambda_invocation" "db_init" {
  function_name = aws_lambda_function.db_initializer.function_name
  input         = "{}"

  depends_on = [
    aws_db_instance.tsvikli_db,
    aws_lambda_function.db_initializer
  ]
}
