data "aws_iam_policy_document" "trust_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "base_permissions" {
  statement {
    actions   = ["ssm:StartSession", "ssm:DescribeSessions"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name_prefix}-ec2-base-access-role"
  assume_role_policy = data.aws_iam_policy_document.trust_policy.json
}

resource "aws_iam_role_policy" "base_permissions" {
  name   = "${var.name_prefix}-access-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.base_permissions.json
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name_prefix}-ec2-base-access-profile"
  role = aws_iam_role.this.name
}