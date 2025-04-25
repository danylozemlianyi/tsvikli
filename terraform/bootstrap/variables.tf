variable "region" {
  description = "AWS region where resources for backend will be created"
  type        = string
  default     = "eu-west-1"
}

variable "bucket_name" {
  description = "Name for S3 bucket to store Terraform state"
  type        = string
  default     = "tsvikli-terraform-state"
}

variable "lock_table_name" {
  description = "Name for DynamoDB table to manage Terraform locks"
  type        = string
  default     = "terraform-locks"
}
