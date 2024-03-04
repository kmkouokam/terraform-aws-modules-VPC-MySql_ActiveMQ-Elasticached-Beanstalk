variable "aws_region" {
  description = "Region where you want to provision the Servers"
  default     = "us-east-1"
}


variable "elasticache_subnet_group_names" {
  description = "The names for Elasticached subnet groups"
  default = [
    "cache-subnet-group1",
    "cache-subnet-group2",
  ]
}
