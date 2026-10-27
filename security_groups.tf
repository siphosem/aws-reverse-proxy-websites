# Each tier only accepts traffic from the tier in front of it:
#   internet -> ext ALB -> nginx -> int ALB -> web servers -> RDS / EFS
#   admin IP -> bastion -> (SSH) nginx and web servers

resource "aws_security_group" "ext_alb" {
  name        = "${local.name}-ext-alb"
  description = "External ALB: HTTP and HTTPS from the internet"
  vpc_id      = module.network.vpc_id
  tags        = { Name = "${local.name}-ext-alb" }
}

resource "aws_security_group" "nginx" {
  name        = "${local.name}-nginx"
  description = "NGINX reverse proxies: HTTPS from the external ALB only"
  vpc_id      = module.network.vpc_id
  tags        = { Name = "${local.name}-nginx" }
}

resource "aws_security_group" "bastion" {
  name        = "${local.name}-bastion"
  description = "Bastion: SSH from admin workstations only"
  vpc_id      = module.network.vpc_id
  tags        = { Name = "${local.name}-bastion" }
}

resource "aws_security_group" "int_alb" {
  name        = "${local.name}-int-alb"
  description = "Internal ALB: HTTPS from NGINX only"
  vpc_id      = module.network.vpc_id
  tags        = { Name = "${local.name}-int-alb" }
}

resource "aws_security_group" "web" {
  name        = "${local.name}-web"
  description = "WordPress and Tooling servers: HTTPS from the internal ALB only"
  vpc_id      = module.network.vpc_id
  tags        = { Name = "${local.name}-web" }
}

resource "aws_security_group" "data" {
  name        = "${local.name}-data"
  description = "RDS and EFS: MySQL and NFS from web servers only"
  vpc_id      = module.network.vpc_id
  tags        = { Name = "${local.name}-data" }
}

locals {
  # [security group, description, port, source: cidr or sg]
  ingress = {
    ext_alb_http   = { sg = aws_security_group.ext_alb.id, port = 80, cidr = "0.0.0.0/0", desc = "HTTP from internet (redirected to HTTPS)" }
    ext_alb_https  = { sg = aws_security_group.ext_alb.id, port = 443, cidr = "0.0.0.0/0", desc = "HTTPS from internet" }
    nginx_alb      = { sg = aws_security_group.nginx.id, port = 443, src = aws_security_group.ext_alb.id, desc = "HTTPS from external ALB" }
    nginx_bastion  = { sg = aws_security_group.nginx.id, port = 22, src = aws_security_group.bastion.id, desc = "SSH from bastion" }
    int_alb_nginx  = { sg = aws_security_group.int_alb.id, port = 443, src = aws_security_group.nginx.id, desc = "HTTPS from NGINX" }
    web_int_alb    = { sg = aws_security_group.web.id, port = 443, src = aws_security_group.int_alb.id, desc = "HTTPS from internal ALB" }
    web_bastion    = { sg = aws_security_group.web.id, port = 22, src = aws_security_group.bastion.id, desc = "SSH from bastion" }
    data_mysql_web = { sg = aws_security_group.data.id, port = 3306, src = aws_security_group.web.id, desc = "MySQL from web servers" }
    data_nfs_web   = { sg = aws_security_group.data.id, port = 2049, src = aws_security_group.web.id, desc = "NFS from web servers" }
  }

  egress = {
    ext_alb_to_nginx = { sg = aws_security_group.ext_alb.id, port = 443, dst = aws_security_group.nginx.id, desc = "To NGINX" }
    int_alb_to_web   = { sg = aws_security_group.int_alb.id, port = 443, dst = aws_security_group.web.id, desc = "To web servers" }
    nginx_to_int_alb = { sg = aws_security_group.nginx.id, port = 443, dst = aws_security_group.int_alb.id, desc = "To internal ALB" }
    nginx_out_https  = { sg = aws_security_group.nginx.id, port = 443, cidr = "0.0.0.0/0", desc = "Packages and SSM" }
    nginx_out_http   = { sg = aws_security_group.nginx.id, port = 80, cidr = "0.0.0.0/0", desc = "Package mirrors" }
    bastion_ssh      = { sg = aws_security_group.bastion.id, port = 22, cidr = var.vpc_cidr, desc = "SSH into the VPC" }
    bastion_https    = { sg = aws_security_group.bastion.id, port = 443, cidr = "0.0.0.0/0", desc = "Packages and SSM" }
    bastion_http     = { sg = aws_security_group.bastion.id, port = 80, cidr = "0.0.0.0/0", desc = "Package mirrors" }
    web_mysql        = { sg = aws_security_group.web.id, port = 3306, dst = aws_security_group.data.id, desc = "To RDS" }
    web_nfs          = { sg = aws_security_group.web.id, port = 2049, dst = aws_security_group.data.id, desc = "To EFS" }
    web_out_https    = { sg = aws_security_group.web.id, port = 443, cidr = "0.0.0.0/0", desc = "Packages, SSM, Secrets Manager, wordpress.org" }
    web_out_http     = { sg = aws_security_group.web.id, port = 80, cidr = "0.0.0.0/0", desc = "Package mirrors" }
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each                     = local.ingress
  security_group_id            = each.value.sg
  description                  = each.value.desc
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  cidr_ipv4                    = lookup(each.value, "cidr", null)
  referenced_security_group_id = lookup(each.value, "src", null)
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  for_each          = toset(var.admin_cidrs)
  security_group_id = aws_security_group.bastion.id
  description       = "SSH from admin workstation"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each                     = local.egress
  security_group_id            = each.value.sg
  description                  = each.value.desc
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  cidr_ipv4                    = lookup(each.value, "cidr", null)
  referenced_security_group_id = lookup(each.value, "dst", null)
}
