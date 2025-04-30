output "db_endpoint" {
  description = "The endpoint of the RDS database"
  value       = aws_db_instance.tsvikli_db.endpoint
}

output "db_secret_arn" {
  description = "The ARN of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_username" {
  description = "Database username"
  value       = var.db_username
}

output "db_name" {
  description = "Database name"
  value       = var.db_name
}
