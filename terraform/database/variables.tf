variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "tsvikliadmin"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "guacamole_db"
}
