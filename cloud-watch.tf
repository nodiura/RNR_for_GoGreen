# SNS Topic
resource "aws_sns_topic" "critical_alerts" {
  name = "CriticalEventAlerts"
}

# SNS Topic Subscription (for Email)
resource "aws_sns_topic_subscription" "critical_alerts_email" {
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = "youremail@example.com"  # Replace with your email
}

# CloudWatch Alarm for EC2 High CPU
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "HighCPUAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Triggers when CPU > 80%"
  
  dimensions = {
    InstanceId = "your_instance_id"  # Replace with your EC2 instance ID
  }
  
  alarm_actions = [aws_sns_topic.critical_alerts.arn]
}

# CloudWatch Alarm for RDS High DB Connections
resource "aws_cloudwatch_metric_alarm" "high_db_connections" {
  alarm_name          = "HighDBConnections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "100"
  alarm_description   = "Triggers when DB connections exceed 100."
  
  dimensions = {
    DBInstanceIdentifier = "your_rds_instance_id"  # Replace with your RDS instance ID
  }
  
  alarm_actions = [aws_sns_topic.critical_alerts.arn]
}

# CloudWatch Alarm for HTTP 400 Errors
resource "aws_cloudwatch_metric_alarm" "http_error_alarm" {
  alarm_name          = "HTTP400ErrorsAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "4XXError"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "Alarm when there are more than 100 HTTP 400 errors in a minute"
  
  dimensions = {
    LoadBalancer = aws_lb.app_lb.arn  # Ensure this Load Balancer resource exists
  }
  
  alarm_actions = [aws_sns_topic.critical_alerts.arn]
}

# Output SNS Topic ARN
output "sns_topic_arn" {
  value = aws_sns_topic.critical_alerts.arn
}