#IAM Configuration
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
  users_map = {
    for user in flatten([
      local.db_admin_users,
      local.monitor_users,
      local.sysadmin_users
    ]) : user => user
  }
}

# Create IAM Users
resource "aws_iam_user" "user" {
  for_each = local.users_map
  name     = each.key
}

# Create IAM User Group Membership
resource "aws_iam_user_group_membership" "membership" {
  for_each = local.users_map
  user     = each.key
  groups   = ["iam_usergroup_name"] # Replace with your actual group name
}

# Attach Users to Groups
resource "aws_iam_user_group_membership" "group_membership" {
  for_each = flatten([
    local.db_admin_users,
    local.monitor_users,
    local.sysadmin_users
  ])
  user = aws_iam_user.user[each.value].name
  groups = [
    aws_iam_group.db_admin.name,
    aws_iam_group.monitor.name,
    aws_iam_group.sysadmin.name
    ][lookup({
      "dbadmin1"     = aws_iam_group.db_admin.name,
      "dbadmin2"     = aws_iam_group.db_admin.name,
      "monitoruser1" = aws_iam_group.monitor.name,
      "monitoruser2" = aws_iam_group.monitor.name,
      "monitoruser3" = aws_iam_group.monitor.name,
      "monitoruser4" = aws_iam_group.monitor.name,
      "sysadmin1"    = aws_iam_group.sysadmin.name,
      "sysadmin2"    = aws_iam_group.sysadmin.name
  }, each.value)]
}

# IAM Role for EC2 Instances
resource "aws_iam_role" "ec2_role" {
  name = "GoGreenEC2Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
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
