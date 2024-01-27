Provision:
# - aws-elasticbeanstalk-service-role
# - aws-elasticbeanstalk-ec2-role
# - aws_iam_instance_profile

# Author: Ernestine D Motouom
# Email: kmkouokam@yahoo.com



# IAM role service and policies for Elasticbeanstalk
####################################################################



##Assume Role Policy
data "aws_iam_policy_document" "beanstalk_service_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["elasticbeanstalk.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"

      values = [
        "elasticbeanstalk"
      ]
    }
  }
}

resource "aws_iam_role" "beanstalk_service_role" {
  name               = "vpro-aws-elasticbeanstalk-service-role"
  assume_role_policy = data.aws_iam_policy_document.beanstalk_service_role.json
}

resource "aws_iam_role_policy_attachment" "AWSElasticBeanstalkEnhancedHealth-attach" {
  role       = aws_iam_role.beanstalk_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}


resource "aws_iam_role_policy_attachment" "AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy-attach" {
  role       = aws_iam_role.beanstalk_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy"
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }


}


resource "aws_iam_role" "ec2_role" {
  name               = "vpro-aws-elasticbeanstalk-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchFullAccess",
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier",
    "arn:aws:iam::aws:policy/AdministratorAccess-AWSElasticBeanstalk",
    "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkRoleSNS",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess"

  ]


}



resource "aws_iam_instance_profile" "instance_profile" {

  name = "vpro-aws-elasticbeanstalk-ec2-role"
  role = aws_iam_role.ec2_role.name
}








 
