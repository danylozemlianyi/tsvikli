output "s3_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}

output "guacamole_repository_url" {
  value = aws_ecr_repository.guacamole.repository_url
}
