output "wordpress_url" {
  value = "https://${var.domain_name}"
}

output "tooling_url" {
  value = "https://${local.tooling_host}"
}

output "external_alb_dns" {
  value = aws_lb.external.dns_name
}

output "name_servers" {
  description = "Only when create_hosted_zone = true: set these as the domain's name servers at your registrar"
  value       = var.create_hosted_zone ? aws_route53_zone.this[0].name_servers : []
}

output "rds_endpoint" {
  value = aws_db_instance.mysql.address
}

output "efs_id" {
  value = aws_efs_file_system.this.id
}

output "asg_names" {
  value = {
    bastion   = module.bastion.asg_name
    nginx     = module.nginx.asg_name
    wordpress = module.wordpress.asg_name
    tooling   = module.tooling.asg_name
  }
}
