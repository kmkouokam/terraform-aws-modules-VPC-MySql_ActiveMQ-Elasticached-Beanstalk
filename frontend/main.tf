



#-----------------Read output in network module---------------
data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "../network/terraform.tfstate"
  }
}

#-----------------Read output in iam_role module---------------
data "terraform_remote_state" "iam_role" {
  backend = "local"

  config = {
    path = "../iam_role/terraform.tfstate"
  }
}



#-----------------Read output in iam_role module---------------
data "terraform_remote_state" "role" {
  backend = "local"

  config = {
    path = "../iam_role/terraform.tfstate"
  }
}



#--------------------s3 Test Bucket creation---------------------
resource "aws_s3_bucket" "vpro-s3" {
  bucket = "vpro-bean.applicationversion.bucket1"



  tags = {
    Name        = "My bucket"
    Environment = "Prod"
  }
}


resource "aws_s3_object" "vpro_s3_object" {
  bucket = aws_s3_bucket.vpro-s3.id
  key    = "target/tomcat.zip"
  source = "./tomcat (2).zip"
  #etag   = filebase64("./tomcat (2).zip ")

  acl = "private"

  depends_on = [aws_s3_bucket.vpro-s3]
}



data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    sid    = ""
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::435329769674:role/${data.terraform_remote_state.iam_role.outputs.beanstalk_ec2_role}",
        "arn:aws:iam::435329769674:role/${data.terraform_remote_state.iam_role.outputs.beanstalk_service_role}"

      ]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:GetObjectVersion",

    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.vpro-s3.id}",
      "arn:aws:s3:::${aws_s3_bucket.vpro-s3.id}/*"
    ]
  }
}


resource "aws_s3_bucket_policy" "s3_bucket_policy" {
  bucket = aws_s3_bucket.vpro-s3.id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}


#---------------------Elasticbeanstalk creation--------------------
resource "aws_elastic_beanstalk_application" "vpro_bean" {
  name        = "vpro-bean-app1"
  description = "AWS Elastic Beanstalk JAVA Application"

  appversion_lifecycle {
    service_role = data.terraform_remote_state.iam_role.outputs.iam_service_role
    #max_count             = 1
    delete_source_from_s3 = true

  }

  lifecycle {
    create_before_destroy = true
  }
}






resource "aws_elastic_beanstalk_application_version" "vpro_app_version" {
  name        = "vpro-app-version-label1"
  application = aws_elastic_beanstalk_application.vpro_bean.id
  description = "application version created by terraform"
  bucket      = aws_s3_bucket.vpro-s3.id
  key         = "target/tomcat.zip" //aws_s3_object.vpro_s3_object.id

  depends_on = [aws_s3_object.vpro_s3_object]

  lifecycle {
    create_before_destroy = true
  }

}




resource "aws_elastic_beanstalk_configuration_template" "vpro_bean_template" {
  name                = "vpro-bean-template-config1"
  application         = aws_elastic_beanstalk_application.vpro_bean.name
  solution_stack_name = "64bit Amazon Linux 2023 v5.1.1 running Tomcat 9 Corretto 11"
  #environment_id = aws_elastic_beanstalk_environment.vpro_bean_env.id
}


resource "aws_elastic_beanstalk_environment" "vpro_bean_env" {
  name                = "vpro-bean-prod-env1"
  description         = "AWS Elastic Beanstalk Java Application Environment"
  application         = aws_elastic_beanstalk_application.vpro_bean.name
  solution_stack_name = "64bit Amazon Linux 2023 v5.1.1 running Tomcat 9 Corretto 11"
  #template_name = "vpro-bean-template-config"
  version_label = aws_elastic_beanstalk_application_version.vpro_app_version.id

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = data.terraform_remote_state.vpc.outputs.vpc_id
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = "${data.terraform_remote_state.vpc.outputs.public_subnet_ids[0]}, ${data.terraform_remote_state.vpc.outputs.public_subnet_ids[1]}"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = "${data.terraform_remote_state.vpc.outputs.public_subnet_ids[0]}, ${data.terraform_remote_state.vpc.outputs.public_subnet_ids[1]}"
  }


  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = true
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBScheme"
    value     = "public"
  }


  setting {
    namespace = "aws:ec2:instances"
    name      = "InstanceTypes"
    value     = "t2.micro"
  }



  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t2.micro"
  }


  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "EC2KeyName"
    value     = "virg.keypair"
  }




  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = data.terraform_remote_state.iam_role.outputs.iam_instance_profile
  }


  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t2.micro"
  }


  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeSize"
    value     = 20
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeIOPS"
    value     = 3000
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeType"
    value     = "standard"
  }




  setting {
    namespace = "aws:elasticbeanstalk:application"
    name      = "Application Healthcheck URL"
    value     = "/login"
  }



  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = data.terraform_remote_state.iam_role.outputs.iam_service_role
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }






  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = 2
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = 4
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "Availability Zones"
    value     = "Any"
  }

  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "RollingUpdateEnabled"
    value     = true
  }



  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "RollingUpdateType"
    value     = "Health"
  }

  # Rolling update & Deployment
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "DeploymentPolicy"
    value     = "Rolling"
  }

  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "BatchSizeType"
    value     = "Percentage"
  }

  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "BatchSize"
    value     = "50"
  }



  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "MeasureName"
    value     = "NetworkOut"
  }





  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "RollingUpdateType"
    value     = "Health"
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = true
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "DeleteOnTerminate"
    value     = true
  }


  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs:health"
    name      = "HealthStreamingEnabled"
    value     = true
  }





  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "StickinessEnabled"
    value     = true
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "Protocol"
    value     = "HTTP"
  }


  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "Port"
    value     = 80
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "HealthCheckInterval"
    value     = 20
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "HealthCheckPath"
    value     = "/login"
  }




  # Monitoring Health Reporting
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "EnhancedHealthAuthEnabled"
    value     = true

  }


  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "EnhancedHealthAuthEnabled"
    value     = true

  }

  setting {
    namespace = "aws:elasticbeanstalk:monitoring"
    name      = "Automatically Terminate Unhealthy Instances"
    value     = true

  }
}
