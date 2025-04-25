module "frontend" {
  source = "./frontend"

  bucket_name = var.bucket_name
  domain_name = var.domain_name
  dns_zone_id = var.dns_zone_id

  providers = {
    aws          = aws
    aws.us_east_1 = aws.us_east_1
  }
}
