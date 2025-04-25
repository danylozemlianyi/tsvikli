locals {
  dist_dir = "${path.module}/../../frontend/dist"
}

resource "aws_acm_certificate" "acm_cert" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  validation_method         = "DNS"
  subject_alternative_names = ["www.${var.domain_name}"]

  tags = {
    Project = "Tsvikli Frontend"
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_route53_record" "frontend_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.acm_cert.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = var.dns_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

resource "aws_acm_certificate_validation" "frontend_cert_validation" {
  provider                  = aws.us_east_1
  certificate_arn           = aws_acm_certificate.acm_cert.arn
  validation_record_fqdns   = [for record in aws_route53_record.frontend_cert_validation : record.fqdn]
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

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "frontend-oac"
  description                       = "OAC for CloudFront to S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
  depends_on = [aws_acm_certificate_validation.frontend_cert_validation]

  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "tsvikli-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "tsvikli-frontend"

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.acm_cert.arn
    ssl_support_method  = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  aliases = [var.domain_name]
}

resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowCloudFrontAccessViaOAC"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })
}


resource "aws_route53_record" "frontend" {
  zone_id = var.dns_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
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

