variable "buckets" {
  default = {
    "logs"    = { versioning = true, lifecycle_days = 30 }
    "backups" = { versioning = true, lifecycle_days = 90 }
    "staging" = { versioning = false, lifecycle_days = 7 }
  }
}

resource "aws_s3_bucket" "this" {
  for_each = var.buckets
  bucket   = "myapp-${each.key}"
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = { for k, v in var.buckets : k => v if v.versioning }
  bucket   = aws_s3_bucket.this[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket-config" {
  for_each = aws_s3_bucket_versioning.this
  bucket   = aws_s3_bucket.this[each.key].id
  rule {
    id = "delete"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.buckets[each.key].lifecycle_days
    }
    status = "Enabled"
  }
}

output "bucket_ids" {
    value = {for k, v in aws_s3_bucket.this: k => v.id}
}

output "versioned_bucket_names" {
    value = [for k, v in var.buckets: k if v.versioning]
}

output "lifecycle_summary" {
    value = {for k, v in var.buckets: k => v.lifecycle_days}
}