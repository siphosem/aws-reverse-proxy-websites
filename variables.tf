variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "company" {
  description = "Fictitious company name, used as the name prefix (lowercase, no spaces)"
  type        = string
  default     = "ubuntu-corp"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.company))
    error_message = "company must be 3-21 lowercase letters, digits or hyphens."
  }
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "domain_name" {
  description = "Domain for the sites: WordPress at the apex, Tooling at tooling.<domain>"
  type        = string
}

variable "create_hosted_zone" {
  description = "true = create a new Route 53 zone (then point your registrar's NS records at it). false = use the zone Route 53 created when you bought the domain."
  type        = bool
  default     = false
}

variable "admin_cidrs" {
  description = "Your public IP range(s) allowed to SSH to the bastion, e.g. [\"203.0.113.10/32\"]"
  type        = list(string)

  validation {
    condition     = !contains(var.admin_cidrs, "0.0.0.0/0")
    error_message = "Don't open SSH to the whole internet."
  }
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "key_name" {
  description = "Optional existing EC2 key pair for SSH via the bastion. Leave null to use SSM Session Manager only."
  type        = string
  default     = null
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_multi_az" {
  description = "Standby replica in the second AZ. Doubles RDS cost; the brief allows skipping it for labs."
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Optional email for Auto Scaling notifications (confirm the subscription email AWS sends)"
  type        = string
  default     = null
}
