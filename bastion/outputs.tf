output "bastion_pulic_ip" {
  description = "The bastion host public ip"
  value       = aws_instance.bastion[*].public_ip
}


output "bastion_sg_id" {
  description = "The bastion host security group id"
  value       = aws_security_group.bastion_sg.id
}
