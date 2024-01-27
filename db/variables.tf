variable "aws_region" {
  default = "us-east-1"
}


variable "elasticache_subnet_group_names" {
  default = [
    "cache-subnet-group1",
    "cache-subnet-group2",
  ]
}
