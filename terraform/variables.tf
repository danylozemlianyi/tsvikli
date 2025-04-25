variable "region" {
  description = "AWS region where resources for backend will be created"
  type        = string
  default     = "eu-west-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for hosting frontend files"
  type        = string
  default     = "tsvikli-frontend"
}

variable "domain_name" {
  description = "Full domain name for frontend"
  type        = string
  default     = "tsvikli.com"
}

variable "dns_zone_id" {
  description = "DNS Zone ID created for domain"
  type        = string
  default     = "<dns_zone_id>"
}
