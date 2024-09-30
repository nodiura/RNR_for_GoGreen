

# Define IAM Groups
resource "aws_iam_group" "db_admin" {
  name = "DBAdmin"
}

resource "aws_iam_group" "monitor" {
  name = "Monitor"
}

resource "aws_iam_group" "sysadmin" {
  name = "Sysadmin"
}

# Define IAM Users
locals {
  db_admin_users = ["dbadmin1", "dbadmin2"]
  monitor_users  = ["monitoruser1", "monitoruser2", "monitoruser3", "monitoruser4"]
  sysadmin_users = ["sysadmin1", "sysadmin2"]
}

# Create DB Admin Users
resource "aws_iam_user" "db_admin" {
  for_each = toset(local.db_admin_users)
  name     = each.value
}

# Create Monitor Users
resource "aws_iam_user" "monitor" {
  for_each = toset(local.monitor_users)
  name     = each.value
}

# Create Sysadmin Users
resource "aws_iam_user" "sysadmin" {
  for_each = toset(local.sysadmin_users)
  name     = each.value
}

# Attach Users to Groups
resource "aws_iam_user_group_membership" "db_admin_membership" {
  user    = aws_iam_user.db_admin[each.key].name
  groups  = [aws_iam_group.db_admin.name]
  for_each = toset(local.db_admin_users)
}

resource "aws_iam_user_group_membership" "monitor_membership" {
  user    = aws_iam_user.monitor[each.key].name
  groups  = [aws_iam_group.monitor.name]
  for_each = toset(local.monitor_users)
}

resource "aws_iam_user_group_membership" "sysadmin_membership" {
  user    = aws_iam_user.sysadmin[each.key].name
  groups  = [aws_iam_group.sysadmin.name]
  for_each = toset(local.sysadmin_users)
}

# IAM Role for EC2 Instances
resource "aws_iam_role" "ec2_role" {
  name = "GoGreenEC2Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# IAM Policy for S3 and RDS Access
resource "aws_iam_policy" "ec2_policy" {
  name        = "GoGreenEC2Policy"
  description = "Policy for EC2 instances to access S3 and RDS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.static_assets.arn,
          aws_s3_bucket.archival_bucket.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:Connect"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the EC2 role
resource "aws_iam_role_policy_attachment" "ec2_role_policy_attachment" {
  policy_arn = aws_iam_policy.ec2_policy.arn
  role       = aws_iam_role.ec2_role.name
}

# IAM Role for Application Tier Instances
resource "aws_iam_role" "app_role" {
  name = "GoGreenAppRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# Attach the same policy to the application role
resource "aws_iam_role_policy_attachment" "app_role_policy_attachment" {
  policy_arn = aws_iam_policy.ec2_policy.arn
  role       = aws_iam_role.app_role.name
}

# AWS KMS Key for Encryption
resource "aws_kms_key" "s3_kms_key" {
  description = "KMS key for S3 bucket encryption"
  key_usage   = "ENCRYPT_DECRYPT"

  tags = {
    Name = "GoGreenS3KMSKey"
  }
}

# S3 Bucket Configuration without acl
resource "aws_s3_bucket" "static_assets" {
  bucket = "gogreen-static-assets"  # Replace with a unique bucket name

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.s3_kms_key.id
      }
    }
  }

  tags = {
    Name = "GoGreenStaticAssets"
  }
}

resource "aws_s3_bucket_acl" "static_assets_acl" {
  bucket = aws_s3_bucket.static_assets.id
  acl    = "private"
}

resource "aws_s3_bucket" "archival_bucket" {
  bucket = "gogreen-archive-bucket"  # Replace with a unique bucket name

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.s3_kms_key.id
      }
    }
  }

  tags = {
    Name = "GoGreenArchiveBucket"
  }
}

resource "aws_s3_bucket_acl" "archival_bucket_acl" {
  bucket = aws_s3_bucket.archival_bucket.id
  acl    = "private"
}

# Outputs for IAM and KMS
output "ec2_role_arn" {
  value = aws_iam_role.ec2_role.arn
}

output "app_role_arn" {
  value = aws_iam_role.app_role.arn
}

output "s3_kms_key_id" {
  value = aws_kms_key.s3_kms_key.id
}

# Outputs for Users and Groups
output "db_admin_users" {
  value = [for user in aws_iam_user.db_admin : user.name]
}

output "monitor_users" {
  value = [for user in aws_iam_user.monitor : user.name]
}

output "sysadmin_users" {
  value = [for user in aws_iam_user.sysadmin : user.name]
}