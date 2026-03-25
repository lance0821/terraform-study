variable "websites" {
  type = map(object({
    versioning  = bool
    environment = string
  }))
  default = {
    "marketing" = { versioning = true, environment = "prod" }
    "docs"      = { versioning = true, environment = "prod" }
    "staging"   = { versioning = false, environment = "dev" }
  }
}


resource "aws_s3_bucket" "this" {
  for_each = var.websites
  bucket   = "website-${each.key}-lwl"
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  for_each = { for k, v in var.websites : k => v if v.versioning }
  bucket   = aws_s3_bucket.this[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket-config" {
  for_each = { for k, v in var.websites : k => v if v.versioning }
  bucket   = aws_s3_bucket.this[each.key].id

  rule {
    id = "delete"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    status = "Enabled"

  }
}


resource "aws_s3_bucket_policy" "public_read" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${each.value.arn}/*"
    }]
  })
}

output "bucket_ids" {
  value = { for k, v in aws_s3_bucket.this : k => v.id }
}

output "versioned_buckets" {
  value = [for k,v in var.websites : k if v.versioning]
}

output "prod_buckets" {
  value = [for k,v in var.websites : k if v.environment == "prod"]
}
