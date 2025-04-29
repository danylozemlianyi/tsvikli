variable "vpc_id" {
  description = "The ID of the VPC where the ECS cluster will be deployed."
  type        = string
}

variable "private_subnets" {
  description = "A list of IDs of private subnets for deploying ECS tasks."
  type        = list(string)
}

variable "public_subnets" {
  description = "A list of IDs of public subnets for deploying the Application Load Balancer."
  type        = list(string)
}

variable "db_secret_arn" {
  description = "The ARN of the AWS Secrets Manager secret storing the database connection credentials."
  type        = string
}

variable "domain_name" {
  description = "The custom domain name that will be used for accessing the Guacamole backend through the ALB."
  type        = string
}

variable "dns_zone_id" {
  description = "The ID of the Route 53 Hosted Zone that manages the domain name for the backend."
  type        = string
}

variable "region" {
  description = "The AWS region where all resources will be created."
  type        = string
}
