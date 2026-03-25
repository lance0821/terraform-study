# data "aws_iam_policy_document" "instance_assume_role_policy" {
#   statement {
#     actions = ["sts:AssumeRole"]

#     principals {
#       type        = "Service"
#       identifiers = ["ec2.amazonaws.com"]
#     }
#   }

# }

# resource "aws_iam_role" "this" {
#     for_each = var.infrastructure
#     name = each.key
#     assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
#     # tags = local.server_with_tags[each.key]
# }

# resource "aws_iam_instance_profile" "this" {
#   for_each = var.infrastructure
#   name  = "profile-${each.key}"
#   role = aws_iam_role.this[each.key].name
#   tags = {Name = each.key}
# }

# resource "aws_iam_role" "by_name" {
#   for_each           = toset(["web", "api", "db"])
#   name               = "${each.key}-role"
#   assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
# }