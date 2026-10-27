# ---------- EFS: shared WordPress files across all WordPress servers ----------

resource "aws_efs_file_system" "this" {
  creation_token   = "${local.name}-efs"
  encrypted        = true
  kms_key_id       = aws_kms_key.main.arn
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = { Name = "${local.name}-efs" }
}

resource "aws_efs_backup_policy" "this" {
  file_system_id = aws_efs_file_system.this.id
  backup_policy {
    status = "ENABLED"
  }
}

resource "aws_efs_mount_target" "this" {
  count           = 2
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = module.network.data_subnet_ids[count.index]
  security_groups = [aws_security_group.data.id]
}

# Access point pins the directory and the Apache user (uid/gid 48 on Amazon Linux).
resource "aws_efs_access_point" "wordpress" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = 48
    gid = 48
  }

  root_directory {
    path = "/wordpress"
    creation_info {
      owner_uid   = 48
      owner_gid   = 48
      permissions = "0755"
    }
  }

  tags = { Name = "${local.name}-wordpress" }
}

# ---------- RDS MySQL ----------

resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db"
  subnet_ids = module.network.data_subnet_ids
}

resource "aws_db_parameter_group" "mysql" {
  name   = "${local.name}-mysql8"
  family = "mysql8.0"

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }
}

resource "aws_db_instance" "mysql" {
  identifier     = "${local.name}-mysql"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.main.arn

  db_name                       = "wordpress"
  username                      = "dbadmin"
  manage_master_user_password   = true # password generated and kept in Secrets Manager
  master_user_secret_kms_key_id = aws_kms_key.main.arn

  multi_az               = var.db_multi_az
  db_subnet_group_name   = aws_db_subnet_group.this.name
  parameter_group_name   = aws_db_parameter_group.mysql.name
  vpc_security_group_ids = [aws_security_group.data.id]
  publicly_accessible    = false

  backup_retention_period         = 7
  backup_window                   = "02:00-03:00"
  maintenance_window              = "sun:03:30-sun:04:30"
  copy_tags_to_snapshot           = true
  auto_minor_version_upgrade      = true
  enabled_cloudwatch_logs_exports = ["error", "slowquery"]
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn

  iam_database_authentication_enabled = true
  performance_insights_enabled        = false # not available on micro instance classes

  deletion_protection = false # lab: allow terraform destroy
  skip_final_snapshot = true
  apply_immediately   = true
}

resource "aws_iam_role" "rds_monitoring" {
  name = "${local.name}-rds-monitoring"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
