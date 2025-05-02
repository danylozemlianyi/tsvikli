resource "random_password" "db_password" {
  length           = 20
  special          = true
  override_special = "!#%^*()_-+="
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "tsvikli-db-credentials-secret"
  recovery_window_in_days = 0

  depends_on = [aws_db_instance.tsvikli_db]
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
