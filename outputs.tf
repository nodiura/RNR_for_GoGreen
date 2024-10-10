#Outputs
output "vpc_id" {
  value = aws_vpc.main.id
}
output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}
output "alb_dns" {
  value = aws_lb.app_lb.dns_name
}
# output "bastion_host_id" {
#   value = aws_instance.bastion.id
# }
# output "bastion_host_public_ip" {
#   value = aws_instance.bastion.public_ip
# }
output "db_instance_id" {
  value = aws_db_instance.default.id
}
output "db_instance_endpoint" {
  value = aws_db_instance.default.endpoint
}
output "static_assets_bucket_name" {
  value = aws_s3_bucket.static_assets.bucket
}
output "archival_bucket_name" {
  value = aws_s3_bucket.archival_bucket.bucket
}
# output "s3_kms_key_id" {
#   value = aws_kms_key.s3_kms_key.id
# }
output "db_credentials_secret_arn" {
  value = aws_secretsmanager_secret.db_credentials.arn
}
output "http_error_alarm_name" {
  value = aws_cloudwatch_metric_alarm.http_error_alarm.alarm_name
}
# Outputs for IAM and KMS
# output "ec2_role_arn" {
#   value = aws_iam_role.ec2_role.arn
# }
