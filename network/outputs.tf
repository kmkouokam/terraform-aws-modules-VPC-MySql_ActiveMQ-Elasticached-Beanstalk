output "vpc_id" {
  description = "The VPC id"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The VPC classless inter-domain routing(cidr-block)"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "The public subnets ids"
  value       = aws_subnet.public_subnets[*].id
}

output "private_subnet_ids" {
  description = "The private subnets ids"
  value       = aws_subnet.private_subnets[*].id
}


output "aws_availability_zones_names" {
  description = "The names of the availability zones"
  value       = data.aws_availability_zones.available.names
}
