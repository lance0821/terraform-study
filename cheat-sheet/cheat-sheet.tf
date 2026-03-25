# terraform {
#     required_providers {
#       aws = {
#         source = "hashicorp/aws"
#         version = "~> 6.0"
#       }
#     }
# }

# provider "aws" {
#     region = "us-east-1"
# }

# resource "aws_s3_bucket" "this" {
#     bucket = "llewandowski-test-cheatsheet-bucket"

#     tags = {
#         Name = " My cheatsheet bucket"
#         Envoronment = "dev"
#     }
# }

# resource "aws_iam_role" "this" {
#     name = "cheat_sheet_role"
#     assume_role_policy = jsonencode ({
#         Version = "2012-10-17"
#         Statement = [
#             {
#                 Action = "sts:AssumeRole"
#                 Effect = "Allow"
#                 Principal = {
#                     Service = "ec2.amazonaws.com"
#                 }
#             }
#         ]
#     })
# }

# data "aws_iam_policy_document" "instance_assume_role_policy" {
#   statement {
#     actions = ["sts:AssumeRole"]

#     principals {
#       type        = "Service"
#       identifiers = ["ec2.amazonaws.com"]
#     }
#   }
# }

# resource "aws_iam_role" "instance" {
#   name               = "instance_role"
#   path               = "/system/"
#   assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
# }

# resource "aws_iam_instance_profile" "cheatsheet_profile"{
#     name = "cheatsheet_profile"
#     role = aws_iam_role.instance.name
# }

# resource "aws_security_group" "this" {
#     name = "cheatsheet_sg"
#     description = "My security group"

# }

# data "aws_ami" "al2023" {
#     most_recent = true
#     owners= ["amazon"]

#     filter {
#         name = "architecture"
#         values = ["x86_64"] 
#     }

#     filter {
#         name = "name"
#         values = ["al2023-ami-*"]
#     }
# }

# resource "aws_instance" "this" {
#     ami = data.aws_ami.al2023.id
#     instance_type = "t3.nano"
# }

# output "al2024_ami_id" {
#     value = data.aws_ami.al2023.id
# }