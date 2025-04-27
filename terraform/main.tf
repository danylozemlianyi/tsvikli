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

module "network" {
  source = "./network"
}

module "database" {
  source = "./database"

  vpc_id               = module.network.vpc_id
  private_subnets      = module.network.private_subnets
  private_subnet_cidrs = module.network.private_subnet_cidrs
}
