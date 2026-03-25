module "naming" {
  source      = "./modules/naming"
  project     = "learning-terraform"
  environment = "dev"
}
module "networking" {
  source = "./modules/networking"
  name   = module.naming.prefix
}

module "iam" {
  source      = "./modules/iam"
  name_prefix = module.naming.prefix
}

module "compute" {
  source                = "./modules/compute"
  instance_profile_name = module.iam.instance_profile_name
  name_prefix           = module.naming.prefix
  security_group_id     = module.networking.security_group_id
  subnet_id             = module.networking.subnet_id
}

