output "iam_service_role" {
  description = "The arn of the beanstalk service role"
  value       = aws_iam_role.beanstalk_service_role.arn
}


output "iam_instance_profile" {
  description = "The arn of the instance profile"
  value       = aws_iam_instance_profile.instance_profile.arn
}


output "beanstalk_ec2_role" {
  description = "The name of the beanstalk ec2 role"
  value       = aws_iam_role.ec2_role.name

}


output "beanstalk_service_role" {
  description = "The name of the beanstalk servive role"
  value       = aws_iam_role.beanstalk_service_role.name

}


