
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&*+-=?"
}

resource "aws_db_subnet_group" "main" {
  name       = "avivneta-${var.project_name}-${var.environment}-db-subnets"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "avivneta-${var.project_name}-${var.environment}-db-subnets"
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "avivneta-${var.project_name}-${var.environment}-postgres"

  engine         = "postgres"
  instance_class = var.rds_instance_class

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "statuspage"
  username = "statuspage_admin"
  password = random_password.db.result
  port     = 5432

  multi_az               = false
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:30-sun:05:30"

  auto_minor_version_upgrade = true
  deletion_protection        = true
  skip_final_snapshot        = true
  apply_immediately          = true

  tags = {
    Name = "avivneta-${var.project_name}-${var.environment}-postgres"
  }
}
