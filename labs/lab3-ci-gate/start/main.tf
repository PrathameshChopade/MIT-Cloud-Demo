# Infrastructure for the order export service.
# LAB FILE: scanned by Checkov, never applied. Each RISK comment marks a problem;
# solution/main.tf has the fix on the same line.

provider "aws" {
  region = "ap-south-1"
}

# --- Storage -------------------------------------------------------------------

resource "aws_s3_bucket" "reports" {
  bucket = "acme-customer-reports"
}

resource "aws_s3_bucket_public_access_block" "reports" {
  bucket = aws_s3_bucket.reports.id
  # RISK: public access is allowed, so one wrong setting exposes customer data.
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
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
    # RISK: SSH is open to the whole internet.
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Server --------------------------------------------------------------------

resource "aws_instance" "web" {
  ami                    = "ami-0123456789abcdef0"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web.id]
  # RISK: the server gets a public IP address, reachable from the internet.
  associate_public_ip_address = true

  metadata_options {
    # RISK: old metadata service (IMDSv1) allowed: the path used in the Capital One breach.
    http_tokens = "optional"
  }

  root_block_device {
    # RISK: the disk is not encrypted.
    encrypted = false
  }
}

# --- Permissions ---------------------------------------------------------------

resource "aws_iam_policy" "app" {
  name = "order-export-app"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      # RISK: every action on every resource: a leaked credential means full account takeover.
      Action   = "*"
      Resource = "*"
    }]
  })
}
