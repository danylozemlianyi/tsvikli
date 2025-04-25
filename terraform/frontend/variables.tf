variable "bucket_name" {
  description = "Name of the S3 bucket for hosting frontend files"
  type        = string
}

variable "domain_name" {
  description = "Full domain name for frontend"
  type        = string
}

variable "dns_zone_id" {
  description = "DNS Zone ID created for domain"
  type        = string
}
