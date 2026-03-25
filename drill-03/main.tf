terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~> 6.0"
      }
    }
}

provider "aws" {
    region = "us-east-1"
}


module "web" {
    source = "./modules/ec2_with_iam"
    name = "web"
    instance_type = "t3.nano"
    s3_bucket_name = "web-assets-bucket"
}

module "api" {
    source = "./modules/ec2_with_iam"
    name = "api"
    instance_type = "t3.micro"
    s3_bucket_name = "api-data-bucket"
}