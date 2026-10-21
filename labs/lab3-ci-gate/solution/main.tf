# Infrastructure for the order export service.
# LAB FILE: scanned by Checkov, never applied. Each FIXED comment marks a fix;
# start/main.tf has the problem on the same line.

provider "aws" {
  region = "ap-south-1"
}

# --- Storage -------------------------------------------------------------------

resource "aws_s3_bucket" "reports" {
  bucket = "acme-customer-reports"
}

resource "aws_s3_bucket_public_access_block" "reports" {
  bucket = aws_s3_bucket.reports.id
  # FIXED: all public access blocked. Share files with time-limited presigned URLs.
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Network -------------------------------------------------------------------

resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Web server"

  ingress {
    description = "SSH for admins"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # FIXED: SSH only from the internal network (better still: no SSH, use Session Manager).
    cidr_blocks = ["10.0.0.0/8"]
  }
}

# --- Server --------------------------------------------------------------------

resource "aws_instance" "web" {
  ami                    = "ami-0123456789abcdef0"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web.id]
  # FIXED: no public IP; the server sits behind a load balancer.
  associate_public_ip_address = false

  metadata_options {
    # FIXED: IMDSv2 only: every metadata request needs a session token.
    http_tokens = "required"
  }

  root_block_device {
    # FIXED: the disk is encrypted.
    encrypted = true
  }
}

# --- Permissions ---------------------------------------------------------------

resource "aws_iam_policy" "app" {
  name = "order-export-app"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      # FIXED: least privilege: only the two actions the app needs, only on its own bucket.
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "${aws_s3_bucket.reports.arn}/*"
    }]
  })
}
