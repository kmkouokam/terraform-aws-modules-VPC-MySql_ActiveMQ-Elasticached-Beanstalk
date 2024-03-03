variable "env" {
  description = "The environment for the resources to be provisioned"
  default     = "Production"
}

variable "vpc_cidr" {
  description = "The VPC cidr_block"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "The list of public subnets cidr_block"
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24",
  ]
}

variable "private_subnet_cidrs" {
  description = "The list of private subnets cidr_block"
  default = [
    "10.0.11.0/24",
    "10.0.22.0/24",
  ]
}

variable "tags" {
  description = "The tag to apply to resources "
  default = {
    Owner   = "Ernestine D Motouom"
    Project = "vprofile"
  }
}
