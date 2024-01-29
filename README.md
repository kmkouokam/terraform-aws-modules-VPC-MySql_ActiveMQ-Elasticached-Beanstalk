This module version (1.0.0) has no root configuration. A module with no root configuration cannot be used directly.

Use the submodules dropdown above to view the 15 submodules defined within this module.


Features
------------------------------------------------------------------------------------------------------------------------
1- Create mutlistack application with MySQl, Elasticached, ActiveMQ in the backend, and Beanstalk in the frontend.

2- Iam role and policies for beantalk



Usage
------------------------------------------------------------------------------------------------------------------------
1- create a Directory called network. If you change the directory name, remember to adjust the path in terraform block.

This module create a network for the whole infrastructure. It has public subnet in 2 AZ where the bastion and beanstalk instances will be deployed. A private subnet for backend resources

 

terraform {
  backend "local" {
    path = "../network/terraform.tfstate"
  }
}


data "aws_availability_zones" "available" {}

 
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags       = merge(var.tags, { Name = "${var.env}-vpc" })
}


resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${var.env}-igw" })
}

 
resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "${var.env}-public-${count.index + 1}" })
}


resource "aws_route_table" "public_subnets" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = merge(var.tags, { Name = "${var.env}-route-public-subnets" })
}


resource "aws_route_table_association" "public_routes" {
  count          = length(aws_subnet.public_subnets[*].id)
  route_table_id = aws_route_table.public_subnets.id
  subnet_id      = aws_subnet.public_subnets[count.index].id
}


 
resource "aws_eip" "nat" {
  count  = length(var.private_subnet_cidrs)
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.env}-nat-gw-${count.index + 1}" })
}


resource "aws_nat_gateway" "nat" {
  count         = length(var.private_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public_subnets[count.index].id
  tags          = merge(var.tags, { Name = "${var.env}-nat-gw-${count.index + 1}" })
}

 
resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = merge(var.tags, { Name = "${var.env}-private-${count.index + 1}" })
}


resource "aws_route_table" "private_subnets" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }
  tags = merge(var.tags, { Name = "${var.env}-route-private-subnet-${count.index + 1}" })
}


resource "aws_route_table_association" "private_routes" {
  count          = length(aws_subnet.private_subnets[*].id)
  route_table_id = aws_route_table.private_subnets[count.index].id
  subnet_id      = aws_subnet.private_subnets[count.index].id
}




2- Set up the bastion host to login to your RDS: create a Directory called bastion. If you change the directory name, remember to adjust the path in terraform block.    

Add SSH rule to bation security group form MyIP
Login to bastion
clone the source code

Important: The network should have been created already, beacuse you need to refere this data.terraform_remote_state.vpc in your bastion main.tf code file

Without the terraform local backend block, terraform will tell you that the state file cannot be read.

data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "../network/terraform.tfstate"
  }
}

terraform {
  backend "local" {
    path = "../bastion/terraform.tfstate"
  }
}

data "aws_region" "current" {}

data "aws_ami" "ubuntu" {
  #executable_users = ["self"]
  most_recent = true
  #name_regex       = "^myami-\\d{3}"
  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }


}




resource "aws_instance" "bastion" {
  #count                       = length(data.terraform_remote_state.vpc.outputs.public_subnet_ids)
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = "virg.keypair"
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  subnet_id                   = data.terraform_remote_state.vpc.outputs.public_subnet_ids[0]

  user_data = file("user_data.sh") // Static file


  tags = {
    Name = "bastion-to_login_to_mysql"
  }
}

resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Allow ssh"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    description = "allow ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.vpc.outputs.vpc_cidr] //Must be edited to allow traffic from Myip via port 22
    #ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    #ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}



3-Set up your backend: create a directory called db, If you change the directory name, remember to adjust the path in the terraform block.



It will generate password for mysql and ActiveMQ and stored in the parameter store in the system manager.

Will create mysql, Elaticached, and ActiveMQ instances and a backend securyty group.

You must set up the data.terraform_remote_state.bastion, data.terraform_remote_state.vpc, and the terraform local backend for terraform apply to work without error messages.

The bastion module should be created prior to db moddule.

Without this block: the terraform local backend , an error message will be generated saying the state file could not be read.


Login into your bastionHost to initialize the db with the schema  using the below command

clone the source code

commands: mysql -h "dbendpoint" -u "dbusername" -p"dbpassword" "DBaccountName" < db_backup.sql

Edit your application.properties file with the rds, elasticcahe, and activeMq endpoints as well as password and username of your rds and activeMq.

built your artifact 

terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
    }

    random = {
      source = "hashicorp/random"
    }

    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}


# After creating my app sg
data "terraform_remote_state" "bastion" {
  backend = "local"

  config = {
    path = "../bastion/terraform.tfstate"
  }
}
 

data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "../network/terraform.tfstate"
  }
}


terraform {
  backend "local" {
    path = "../db/terraform.tfstate"
  }
}


# Generate password for mysql

resource "random_password" "mysql_password" {
  length           = 12
  special          = false
  override_special = "!#$%&*()-_+{}<>?"
}


# Store password
resource "aws_ssm_parameter" "mysql_password" {
  name        = "/production/mysql/password"
  description = "The parameter description"
  type        = "SecureString"
  value       = random_password.mysql_password.result

  tags = {
    environment = "production"
  }
}


# Retrieved Password
data "aws_ssm_parameter" "mysql_password" {
  name       = "/production/mysql/password"
  depends_on = [aws_ssm_parameter.mysql_password]
}

//DB subnet_group

resource "aws_db_subnet_group" "db_sub_group" {
  count       = length(data.terraform_remote_state.vpc.outputs.private_subnet_ids)
  name_prefix = "db_sub_group"
  subnet_ids  = data.terraform_remote_state.vpc.outputs.private_subnet_ids[*]

  tags = {
    Name = "My DB subnet group"
  }
}

// Elasticache Subnet_group


resource "aws_elasticache_subnet_group" "cache_subnet" {
  count      = length(data.terraform_remote_state.vpc.outputs.private_subnet_ids)
  name       = var.elasticache_subnet_group_names[count.index]
  subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids[*]

}

#Mysql db

resource "aws_db_instance" "mysql_db" {
  count                = length(data.terraform_remote_state.vpc.outputs.private_subnet_ids)
  allocated_storage    = 10
  db_name              = "accounts"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  skip_final_snapshot  = true
  apply_immediately    = true
  identifier           = "vprofile-${count.index + 1}"
  username             = "admin"
  password             = random_password.mysql_password.result
  parameter_group_name = "default.mysql8.0"
  db_subnet_group_name = aws_db_subnet_group.db_sub_group[count.index].name

  vpc_security_group_ids = [
    aws_security_group.backend.id,
    data.terraform_remote_state.bastion.outputs.bastion_sg_id
  ]
  port = 3306


  tags = {
    Name = "mysql_db-${count.index + 1}"
  }

}





resource "aws_elasticache_cluster" "memcached" {
  count                = length(data.terraform_remote_state.vpc.outputs.private_subnet_ids)
  cluster_id           = "memcached-${count.index + 1}"
  engine               = "memcached"
  node_type            = "cache.m4.large"
  num_cache_nodes      = 2
  parameter_group_name = "default.memcached1.6"
  port                 = 11211

  depends_on         = [aws_db_instance.mysql_db]
  security_group_ids = [aws_security_group.backend.id, data.terraform_remote_state.bastion.outputs.bastion_sg_id]
  subnet_group_name  = aws_elasticache_subnet_group.cache_subnet[count.index].name

  tags = {
    Name = "memcached-${count.index + 1}"
  }
}


# Generate password for rmq

resource "random_password" "rmq_password" {
  length  = 12
  special = false

}


# Store password
resource "aws_ssm_parameter" "rmq_password" {
  name        = "/production/rmq/password"
  description = "The parameter description"
  type        = "SecureString"
  value       = random_password.rmq_password.result

  tags = {
    environment = "production"
  }
}


# Retrieved Password
data "aws_ssm_parameter" "rmq_password" {
  name       = "/production/mysql/password"
  depends_on = [aws_ssm_parameter.rmq_password]
}



resource "aws_mq_broker" "rmq1" {
  #count = length(data.terraform_remote_state.vpc.outputs.private_subnet_ids)

  broker_name = "rmq1"

  configuration {

    id       = aws_mq_configuration.rmq_configuration.id
    revision = aws_mq_configuration.rmq_configuration.latest_revision
  }

  engine_type        = "ActiveMQ"
  engine_version     = "5.17.6"
  host_instance_type = "mq.t2.micro"
  depends_on         = [aws_db_instance.mysql_db, aws_elasticache_cluster.memcached]
  subnet_ids = [
    data.terraform_remote_state.vpc.outputs.private_subnet_ids[0],
  data.terraform_remote_state.vpc.outputs.private_subnet_ids[1]]


  security_groups = [aws_security_group.backend.id, data.terraform_remote_state.bastion.outputs.bastion_sg_id]
  deployment_mode = "ACTIVE_STANDBY_MULTI_AZ"


  user {
    username = "guest"
    password = data.aws_ssm_parameter.rmq_password.value
  }


}


resource "aws_mq_broker" "rmq2" {
  #count = length(data.terraform_remote_state.vpc.outputs.private_subnet_ids)

  broker_name = "rmq2"

  configuration {

    id       = aws_mq_configuration.rmq_configuration.id
    revision = aws_mq_configuration.rmq_configuration.latest_revision
  }

  engine_type        = "ActiveMQ"
  engine_version     = "5.17.6"
  host_instance_type = "mq.t2.micro"
  depends_on         = [aws_db_instance.mysql_db, aws_elasticache_cluster.memcached]
  subnet_ids = [
    data.terraform_remote_state.vpc.outputs.private_subnet_ids[0],
  data.terraform_remote_state.vpc.outputs.private_subnet_ids[1]]

  security_groups = [aws_security_group.backend.id, data.terraform_remote_state.bastion.outputs.bastion_sg_id]
  deployment_mode = "ACTIVE_STANDBY_MULTI_AZ"


  user {
    username = "guest"
    password = data.aws_ssm_parameter.rmq_password.value
  }


}


resource "aws_mq_configuration" "rmq_configuration" {
  description    = "rmq Configuration"
  name           = "rmq_configuration"
  engine_type    = "ActiveMQ"
  engine_version = "5.17.6"

  data = <<DATA
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<broker xmlns="http://activemq.apache.org/schema/core">
  <plugins>
    <forcePersistencyModeBrokerPlugin persistenceFlag="true"/>
    <statisticsBrokerPlugin/>
    <timeStampingBrokerPlugin ttlCeiling="86400000" zeroExpirationOverride="86400000"/>
  </plugins>
</broker>
DATA
}



# Backend SG

resource "aws_security_group" "backend" {
  name        = "backend"
  description = "Allow TLS inbound traffic"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  dynamic "ingress" {
    #description = "TLS from VPC"
    for_each = ["3306", "11211", "5672"]
    content {
      from_port = ingress.value
      to_port   = ingress.value
      protocol  = "tcp"

      cidr_blocks = ["0.0.0.0/0"]

    }

  }

  // allows traffic from the SG itself
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    Name = "backend_sg"
  }
}

4- create a directory called iam_role, If you change the directory name, remember to adjust the path in terraform block.


This module create IAM role service and policies for Elasticbeanstalk and an instance profile.

The instance profile is used to pass an IAM role to an EC2 instance


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


5- set up the frontend: create a directory called frontend, If you change the directory name, remember to adjust the path in terraform block.

 The vpc, the beanstalk service role and ec2 role should have been created already, because you must refere them here using data block.

 Without the terraform local backend block, terraform will tell you that the state file cannot be read.

The source bundle is needed for your elasticbeanstalk app. Found here
https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/tutorials.html.

My domain name server was purchased in Goddady. I added a CNAME record and the value provided was my beanstalk domain name. After provisioning your environement, edit the configuration to add listener https and provide your domain name certificate.

The path of the source bundle will be provided in your "aws_s3_object" resource in the source argument.

Important: The s3 bucket provisions in this code will store only the source bundle zip file. Beanstalk will create automaticaly its own bucket where the artifact, and other resources will be stored. 


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


#-----------------Remote backend to storage: s3 bucket------------
terraform {
  backend "s3" {
    bucket = "vpro-bean.applicationversion.bucket"
    key    = "vpro-bean/terraform.tfstate"
    region = "us-east-1"
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


Author
--------------------------------------------------------------------------------------------------------------------------
Module is maintained by Ernestine D Motouom


