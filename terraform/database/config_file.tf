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
