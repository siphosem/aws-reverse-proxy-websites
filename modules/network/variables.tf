variable "name" {
  description = "Name prefix for network resources"
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block (/16)"
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr, 0)) && endswith(var.cidr, "/16")
    error_message = "cidr must be a valid /16 IPv4 block."
  }
}

variable "kms_key_arn" {
  description = "KMS key used to encrypt the flow log group"
  type        = string
}
