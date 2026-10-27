# External ALB terminates TLS from users and forwards to NGINX.
# NGINX forwards to the internal ALB, which routes by host name:
#   <domain>, www.<domain>  -> WordPress
#   tooling.<domain>        -> Tooling

locals {
  tls_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

# ---------- external ----------

resource "aws_lb" "external" {
  name                       = "${local.name}-ext"
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [aws_security_group.ext_alb.id]
  subnets                    = module.network.public_subnet_ids
  drop_invalid_header_fields = true
  idle_timeout               = 60
}

resource "aws_lb_target_group" "nginx" {
  name                 = "${local.name}-nginx"
  port                 = 443
  protocol             = "HTTPS"
  vpc_id               = module.network.vpc_id
  deregistration_delay = 30

  health_check {
    path                = "/healthstatus"
    protocol            = "HTTPS"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
  }
}

resource "aws_lb_listener" "external_https" {
  load_balancer_arn = aws_lb.external.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = local.tls_policy
  certificate_arn   = aws_acm_certificate_validation.this.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx.arn
  }
}

resource "aws_lb_listener" "external_http" {
  load_balancer_arn = aws_lb.external.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ---------- internal ----------

resource "aws_lb" "internal" {
  name                       = "${local.name}-int"
  load_balancer_type         = "application"
  internal                   = true
  security_groups            = [aws_security_group.int_alb.id]
  subnets                    = module.network.app_subnet_ids
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "site" {
  for_each             = toset(["wordpress", "tooling"])
  name                 = "${local.name}-${each.key}"
  port                 = 443
  protocol             = "HTTPS"
  vpc_id               = module.network.vpc_id
  deregistration_delay = 30

  health_check {
    path                = "/healthstatus"
    protocol            = "HTTPS"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
  }

  # WordPress logins rely on the same server for a session.
  stickiness {
    type            = "lb_cookie"
    enabled         = each.key == "wordpress"
    cookie_duration = 3600
  }
}

resource "aws_lb_listener" "internal_https" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = local.tls_policy
  certificate_arn   = aws_acm_certificate_validation.this.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.site["wordpress"].arn
  }
}

resource "aws_lb_listener_rule" "tooling" {
  listener_arn = aws_lb_listener.internal_https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.site["tooling"].arn
  }

  condition {
    host_header {
      values = [local.tooling_host]
    }
  }
}
