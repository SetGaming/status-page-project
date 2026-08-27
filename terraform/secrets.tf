resource "aws_secretsmanager_secret" "database" {
  name                    = "avivneta/${var.project_name}/${var.environment}/database"
  recovery_window_in_days = 7

  tags = {
    Name = "avivneta-${var.project_name}-${var.environment}-database-secret"
  }
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id

  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.postgres.address
    port     = aws_db_instance.postgres.port
    dbname   = aws_db_instance.postgres.db_name
    username = aws_db_instance.postgres.username
    password = random_password.db.result
  })
}
