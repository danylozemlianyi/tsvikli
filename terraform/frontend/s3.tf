locals {
  dist_dir = "${path.module}/../../frontend/dist"
}

resource "aws_s3_bucket" "frontend" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Project = "Tsvikli Frontend"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowCloudFrontAccessViaOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_object" "frontend_files" {
  for_each = fileset(local.dist_dir, "**")

  bucket = aws_s3_bucket.frontend.id
  key    = each.key
  source = "${local.dist_dir}/${each.key}"
  etag   = filemd5("${local.dist_dir}/${each.key}")

  content_type = lookup(
    {
      html = "text/html"
      css  = "text/css"
      js   = "application/javascript"
      json = "application/json"
      png  = "image/png"
      jpg  = "image/jpeg"
      jpeg = "image/jpeg"
      svg  = "image/svg+xml"
      ico  = "image/x-icon"
      webp = "image/webp"
    },
    lower(element(split(".", each.key), length(split(".", each.key)) - 1)),
    "binary/octet-stream"
  )
}

resource "null_resource" "invalidate_cloudfront_cache" {
  triggers = {
    content_version = filemd5("${local.dist_dir}/index.html")
  }

  provisioner "local-exec" {
    command = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.frontend.id} --paths '/*'"
  }
}
