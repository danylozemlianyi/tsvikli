data "aws_caller_identity" "current" {}

data "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = var.db_secret_arn
}
