#Outputs
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "public_subnet_b_id" {
  value = aws_subnet.public_b.id
}

output "app_private_subnet_id" {
  value = aws_subnet.app_private.id
}

output "app_private_subnet_b_id" {
  value = aws_subnet.app_private_b.id
}

output "db_private_subnet_id" {
  value = aws_subnet.db_private.id
}

output "alb_dns_name" {
  value = aws_lb.app_lb.dns_name
}

output "bastion_host_id" {
  value = aws_instance.bastion.id
}

output "route53_zone_id" {
  value = aws_route53_zone.main.id
}

output "static_assets_bucket_name" {
  value = aws_s3_bucket.static_assets.bucket
}

output "archival_bucket_name" {
  value = aws_s3_bucket.archival_bucket.bucket
}