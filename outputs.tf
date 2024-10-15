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
output "http_error_alarm_name" {
  value = aws_cloudwatch_metric_alarm.http_error_alarm.alarm_name
}