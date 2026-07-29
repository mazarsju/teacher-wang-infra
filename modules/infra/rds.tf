# RDS PostgreSQL — cheapest viable sizing for early-stage / solo use.
#
# Cost notes:
# - db.t4g.micro, single-AZ, gp3 20 GiB (no Multi-AZ, no Performance Insights).
# - Storage encryption uses the AWS-managed RDS key (AES256; no CMK charge).
# - Master password is managed by RDS in Secrets Manager (~$0.40/mo).
# - skip_final_snapshot = true while data is disposable; flip before real prod data.

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db"
  subnet_ids = aws_subnet.private[*].id

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-db"
    Tier = "data"
  })
}

resource "aws_db_instance" "main" {
  identifier = "${local.name_prefix}-postgres"

  engine               = "postgres"
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class
  allocated_storage     = var.db_allocated_storage_gb
  max_allocated_storage = var.db_max_allocated_storage_gb > 0 ? var.db_max_allocated_storage_gb : null
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username

  # AWS creates/rotates the master secret in Secrets Manager.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false
  availability_zone      = local.azs[0]

  backup_retention_period = var.db_backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  deletion_protection = var.db_deletion_protection
  skip_final_snapshot = !var.db_deletion_protection
  final_snapshot_identifier = var.db_deletion_protection ? "${local.name_prefix}-postgres-final" : null

  # Performance Insights and enhanced monitoring add cost — leave off for now.
  performance_insights_enabled = false
  monitoring_interval          = 0

  copy_tags_to_snapshot = true

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-postgres"
    Tier = "data"
  })
}
