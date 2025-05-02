module "frontend" {
  source = "./frontend"

  bucket_name = var.bucket_name
  domain_name = var.domain_name
  dns_zone_id = var.dns_zone_id

  providers = {
    aws           = aws
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

  depends_on = [module.network, module.frontend]
}

module "backend" {
  source          = "./backend"
  vpc_id          = module.network.vpc_id
  private_subnets = module.network.private_subnets
  public_subnets  = module.network.public_subnets
  db_secret_arn   = module.database.db_secret_arn
  domain_name     = var.domain_name
  dns_zone_id     = var.dns_zone_id
  region          = var.region
}
