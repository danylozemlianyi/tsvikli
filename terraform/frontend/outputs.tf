output "s3_bucket_name" {
  description = "Name of the S3 bucket where frontend is hosted"
  value       = aws_s3_bucket.frontend.id
}

output "cloudfront_distribution_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.frontend.id
}
