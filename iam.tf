# Instance roles. All servers get SSM Session Manager (shell access without opening SSH).
# Web servers can also read the RDS-managed database secret.

locals {
  roles = toset(["bastion", "nginx", "web"])
}

resource "aws_iam_role" "instance" {
  for_each = local.roles
  name     = "${local.name}-${each.key}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  for_each   = local.roles
  role       = aws_iam_role.instance[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  for_each   = local.roles
  role       = aws_iam_role.instance[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "web_db_secret" {
  name = "read-db-secret"
  role = aws_iam_role.instance["web"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_db_instance.mysql.master_user_secret[0].secret_arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "instance" {
  for_each = local.roles
  name     = "${local.name}-${each.key}"
  role     = aws_iam_role.instance[each.key].name
}
