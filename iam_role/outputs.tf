output "iam_service_role" {
  value = aws_iam_role.beanstalk_service_role.arn
}


output "iam_instance_profile" {
  value = aws_iam_instance_profile.instance_profile.arn
}


output "beanstalk_ec2_role" {
  value = aws_iam_role.ec2_role.name

}


output "beanstalk_service_role" {
  value = aws_iam_role.beanstalk_service_role.name

}


