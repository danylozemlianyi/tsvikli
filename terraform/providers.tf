provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "Tsvikli"
      ManagedBy   = "Terraform"
    }  
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "Tsvikli"
      ManagedBy   = "Terraform"
    }
  }
}
