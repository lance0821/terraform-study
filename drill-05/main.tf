terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"

    }
    aws = {
      source  = "hashicorp/aws"

    }
  }
}

provider "aws" {
  region = "us-east-1" 
}

module "naming" {
  source      = "./modules/naming"
  environment = "dev"
  project     = "testing"

}

module "iam" {
  source      = "./modules/iam"
  name_prefix = module.naming.prefix
}

module "compute" {
  source                = "./modules/compute"
  name_prefix           = module.naming.prefix
  instance_profile_name = module.iam.instance_profile_name


}