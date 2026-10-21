# Lab 4: a small, secure-by-default AWS setup that is applied for real.
# Everything here is free or costs fractions of a cent: no servers are launched.
# Remove it all afterwards with `terraform destroy`.

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "region" {
  description = "AWS region for the demo"
  type        = string
  default     = "ap-south-1"
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project = "secure-path-to-cloud"
      Purpose = "workshop-demo"
    }
  }
}

# --- Storage: a private bucket ------------------------------------------------

resource "aws_s3_bucket" "reports" {
  bucket_prefix = "spc-demo-" # short, so the link participants open is short too
  force_destroy = true # lets `terraform destroy` remove it even with files inside
}

resource "aws_s3_bucket_public_access_block" "reports" {
  bucket                  = aws_s3_bucket.reports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "reports" {
  bucket = aws_s3_bucket.reports.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# The bucket's access policy: refuse any request not made over HTTPS.
# Because Terraform manages it, a manual change (like drift.sh's public policy)
# shows up in `terraform plan` and is reverted by `terraform apply`.
resource "aws_s3_bucket_policy" "reports" {
  bucket = aws_s3_bucket.reports.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.reports.arn, "${aws_s3_bucket.reports.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.reports]
}

# --- Networking: a security group in the default VPC --------------------------

data "aws_vpc" "default" {
  default = true
}

# HTTPS only. No SSH: admins would use Session Manager instead.
resource "aws_security_group" "web" {
  name_prefix = "secure-path-demo-web-"
  description = "Workshop demo web tier"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Identity: a least-privilege role -----------------------------------------

resource "aws_iam_role" "app" {
  name_prefix = "secure-path-demo-app-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Only read and write files, only in this one bucket.
resource "aws_iam_role_policy" "app" {
  name = "reports-bucket-only"
  role = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "${aws_s3_bucket.reports.arn}/*"
    }]
  })
}

# --- Outputs used by the demo scripts -----------------------------------------

output "region" {
  value = var.region
}

output "bucket_name" {
  value = aws_s3_bucket.reports.id
}

output "security_group_id" {
  value = aws_security_group.web.id
}

output "role_name" {
  value = aws_iam_role.app.name
}
