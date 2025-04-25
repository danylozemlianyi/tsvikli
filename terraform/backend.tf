terraform {
  backend "s3" {
    bucket         = "tsvikli-terraform-state"
    key            = "terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
