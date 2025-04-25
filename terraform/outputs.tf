output "frontend_s3_bucket_name" {
  description = "Name of the S3 bucket where frontend is hosted"
  value       = module.frontend.s3_bucket_name
}

output "frontend_cloudfront_distribution_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = module.frontend.cloudfront_distribution_domain_name
}

output "frontend_cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.frontend.cloudfront_distribution_id
}

output "frontend_acm_certificate_arn" {
  description = "ARN of the ACM certificate for the domain"
  value       = module.frontend.acm_certificate_arn
}
