variable "name" {
  type = string
}

variable "role" {
  description = "Server role tag, e.g. nginx"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "public_ip" {
  type    = bool
  default = false
}

variable "instance_profile_name" {
  type = string
}

variable "user_data" {
  type = string
}

variable "key_name" {
  description = "Optional EC2 key pair for SSH through the bastion"
  type        = string
  default     = null
}

variable "kms_key_arn" {
  type = string
}

variable "volume_size" {
  type    = number
  default = 10
}

variable "target_group_arns" {
  type    = list(string)
  default = []
}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "desired_capacity" {
  type = number
}

variable "cpu_target" {
  description = "Average CPU % the group scales to hold"
  type        = number
  default     = 90
}

variable "health_check_grace_period" {
  type    = number
  default = 300
}

variable "sns_topic_arn" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
