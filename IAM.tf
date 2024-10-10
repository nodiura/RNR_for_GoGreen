
 
# Define IAM Groups based on the workspace
resource "aws_iam_group" "db_admin" {
  name = "${terraform.workspace}-DBAdmin"
}
 
resource "aws_iam_group" "monitor" {
  name = "${terraform.workspace}-Monitor"
}
 
resource "aws_iam_group" "sysadmin" {
  name = "${terraform.workspace}-Sysadmin"
}
 
# Define IAM Users
variable "db_admin_users" {
  type    = list(string)
  default = ["dbadmin1", "dbadmin2"]
}
 
variable "monitor_users" {
  type    = list(string)
  default = ["monitoruser1", "monitoruser2", "monitoruser3", "monitoruser4"]
}
 
variable "sysadmin_users" {
  type    = list(string)
  default = ["sysadmin1", "sysadmin2"]
}
 
# Combine users into a single map that indicates their groups
locals {
  user_group_map = merge(
    { for user in var.db_admin_users : user => aws_iam_group.db_admin.name },
    { for user in var.monitor_users : user => aws_iam_group.monitor.name },
    { for user in var.sysadmin_users : user => aws_iam_group.sysadmin.name }
  )
}
 
# Create IAM Users
resource "aws_iam_user" "user" {
  for_each = local.user_group_map
  name     = each.key
}
 
# Create IAM User Group Membership
resource "aws_iam_user_group_membership" "group_membership" {
  for_each = local.user_group_map  # Use the mapping of users to their groups
  user     = aws_iam_user.user[each.key].name
  groups   = [each.value]
}
 
# IAM Role for EC2 Instances
resource "aws_iam_role" "ec2_role" {
  name = "${terraform.workspace}-GoGreenEC2Role"
 
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}
 
# IAM Policy for S3 and RDS Access
resource "aws_iam_policy" "ec2_policy" {
  name        = "${terraform.workspace}-GoGreenEC2Policy"
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
          aws_s3_bucket.archival_bucket.arn,
          "${aws_s3_bucket.static_assets.arn}/*",  
          "${aws_s3_bucket.archival_bucket.arn}/*"  
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:Connect"
        ]
        Resource = "*"  # This is allowed for Describe actions
      }
    ]
  })
}
 
# Outputs
output "users" {
  value = {
    db_admin = [for user in aws_iam_user.user : user.name if contains(var.db_admin_users, user.name)]
    monitor  = [for user in aws_iam_user.user : user.name if contains(var.monitor_users, user.name)]
    sysadmin = [for user in aws_iam_user.user : user.name if contains(var.sysadmin_users, user.name)]
  }
}
 
 