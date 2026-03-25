resource "aws_iam_role" "this" {
  for_each           = var.environments
  name               = "${each.key}-ec2-s3-access-role"
  assume_role_policy = data.aws_iam_policy_document.trust_policy.json
}

resource "aws_iam_role_policy" "s3_access" {
  for_each = var.environments
  name     = "${each.key}-s3-access-policy"
  role     = aws_iam_role.this[each.key].id
  policy   = data.aws_iam_policy_document.s3_access.json
}

resource "aws_iam_instance_profile" "this" {
  for_each = var.environments
  name     = "${each.key}-ec2-s3-access-profile"
  role     = aws_iam_role.this[each.key].name
}