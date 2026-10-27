module "network" {
  source      = "./modules/network"
  name        = local.name
  cidr        = var.vpc_cidr
  kms_key_arn = aws_kms_key.main.arn
}
