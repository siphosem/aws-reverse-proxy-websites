locals {
  web_common = {
    region        = var.region
    db_secret_arn = aws_db_instance.mysql.master_user_secret[0].secret_arn
    db_host       = aws_db_instance.mysql.address
  }
}

resource "aws_sns_topic" "scaling" {
  name              = "${local.name}-scaling-events"
  kms_master_key_id = aws_kms_key.main.arn
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == null ? 0 : 1
  topic_arn = aws_sns_topic.scaling.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ---------- Bastion (public subnets) ----------

module "bastion" {
  source                = "./modules/asg"
  name                  = "${local.name}-bastion"
  role                  = "bastion"
  instance_type         = var.instance_type
  subnet_ids            = module.network.public_subnet_ids
  public_ip             = true
  security_group_ids    = [aws_security_group.bastion.id]
  instance_profile_name = aws_iam_instance_profile.instance["bastion"].name
  key_name              = var.key_name
  kms_key_arn           = aws_kms_key.main.arn
  user_data             = templatefile("${path.module}/templates/bastion.sh.tftpl", {})
  min_size              = 1
  desired_capacity      = 1
  max_size              = 2
  sns_topic_arn         = aws_sns_topic.scaling.arn
  tags                  = local.tags
}

# ---------- NGINX reverse proxies (public subnets, reachable only via the external ALB) ----------

module "nginx" {
  source                = "./modules/asg"
  name                  = "${local.name}-nginx"
  role                  = "nginx"
  instance_type         = var.instance_type
  subnet_ids            = module.network.public_subnet_ids
  public_ip             = true # for package downloads; the security group still only admits the ALB
  security_group_ids    = [aws_security_group.nginx.id]
  instance_profile_name = aws_iam_instance_profile.instance["nginx"].name
  key_name              = var.key_name
  kms_key_arn           = aws_kms_key.main.arn
  user_data = templatefile("${path.module}/templates/nginx.sh.tftpl", {
    internal_alb_dns = aws_lb.internal.dns_name
  })
  target_group_arns = [aws_lb_target_group.nginx.arn]
  min_size          = 2
  desired_capacity  = 2
  max_size          = 4
  sns_topic_arn     = aws_sns_topic.scaling.arn
  tags              = local.tags
}

# ---------- WordPress (private app subnets) ----------

module "wordpress" {
  source                = "./modules/asg"
  name                  = "${local.name}-wordpress"
  role                  = "wordpress"
  instance_type         = var.instance_type
  subnet_ids            = module.network.app_subnet_ids
  security_group_ids    = [aws_security_group.web.id]
  instance_profile_name = aws_iam_instance_profile.instance["web"].name
  key_name              = var.key_name
  kms_key_arn           = aws_kms_key.main.arn
  user_data = join("\n", [
    templatefile("${path.module}/templates/web-common.sh.tftpl", local.web_common),
    templatefile("${path.module}/templates/wordpress.sh.tftpl", {
      efs_id    = aws_efs_file_system.this.id
      efs_ap_id = aws_efs_access_point.wordpress.id
      domain    = var.domain_name
    }),
  ])
  target_group_arns         = [aws_lb_target_group.site["wordpress"].arn]
  health_check_grace_period = 600 # first boot downloads WordPress onto EFS
  min_size                  = 2
  desired_capacity          = 2
  max_size                  = 4
  sns_topic_arn             = aws_sns_topic.scaling.arn
  tags                      = local.tags

  depends_on = [aws_efs_mount_target.this]
}

# ---------- Tooling (private app subnets) ----------

module "tooling" {
  source                = "./modules/asg"
  name                  = "${local.name}-tooling"
  role                  = "tooling"
  instance_type         = var.instance_type
  subnet_ids            = module.network.app_subnet_ids
  security_group_ids    = [aws_security_group.web.id]
  instance_profile_name = aws_iam_instance_profile.instance["web"].name
  key_name              = var.key_name
  kms_key_arn           = aws_kms_key.main.arn
  user_data = join("\n", [
    templatefile("${path.module}/templates/web-common.sh.tftpl", local.web_common),
    templatefile("${path.module}/templates/tooling.sh.tftpl", {
      index_php_b64  = filebase64("${path.module}/app/tooling/index.php")
      schema_sql_b64 = filebase64("${path.module}/app/tooling/schema.sql")
    }),
  ])
  target_group_arns = [aws_lb_target_group.site["tooling"].arn]
  min_size          = 2
  desired_capacity  = 2
  max_size          = 4
  sns_topic_arn     = aws_sns_topic.scaling.arn
  tags              = local.tags
}
