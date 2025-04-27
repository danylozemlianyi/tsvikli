variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_a_cidr" {
  description = "CIDR for public subnet A"
  default     = "10.0.1.0/24"
}

variable "public_subnet_b_cidr" {
  description = "CIDR for public subnet B"
  default     = "10.0.2.0/24"
}

variable "private_subnet_a_cidr" {
  description = "CIDR for private subnet A"
  default     = "10.0.11.0/24"
}

variable "private_subnet_b_cidr" {
  description = "CIDR for private subnet B"
  default     = "10.0.12.0/24"
}
