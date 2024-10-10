# Secrets Manager Configuration
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "db_credentials"
  description = "Database credentials for GoGreen"
  tags = {
    Name = "GoGreenDBCredentials"
  }
}

resource "random_password" "db_password" {
  length  = 16
  special = true
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "dbadmin"
    password = random_password.db_password.result
    host     = aws_db_instance.default.endpoint
  })
}