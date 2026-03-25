terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}


module "networking" {
  source        = "./modules/networking"
  name          = "test-network"
  allowed_ports = [22, 80, 443]
}

module "compute" {
  source            = "./modules/compute"
  name              = "default-compute-instance"
  instance_type     = "t3.nano"
  security_group_id = module.networking.security_group_id
}