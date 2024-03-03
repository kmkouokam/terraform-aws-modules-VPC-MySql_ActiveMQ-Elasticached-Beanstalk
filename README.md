This module version (1.0.0) has no root configuration.  

 


Features
------------------------------------------------------------------------------------------------------------------------
1- Create mutlistack application with MySQl, Elasticached, ActiveMQ in the backend, and Beanstalk as the frontend, s3 bucket, and VPC.

2- Iam role and policies for beantalk



Usage
------------------------------------------------------------------------------------------------------------------------
1- create a Directory called network. If you change the directory name, remember to adjust the path in terraform block.

This module create a network for the whole infrastructure. It has public subnet in 2 AZ where the bastion and beanstalk instances will be deployed. A private subnet for backend resources; two elastic IP, two nat gateways in the public subnet; route tables for public and private subnets.

terraform init
 terraform plan
 terraform apply


2- Set up the bastion host to login to your RDS: If you change the directory name, remember to adjust the path in terraform block.

 terraform init
 terraform plan
 terraform apply

Edit bastion security group to add SSH rule form MyIP


Important: The network should have been created already, beacuse you need to refere this data.terraform_remote_state.vpc in your bastion main.tf code file

 


3-Set up your backend: create a directory called db, If you change the directory name, remember to adjust the path in the terraform block.

terraform init
 terraform plan
 terraform apply

It will generate password for mysql and ActiveMQ and stored in the parameter store in the system manager.

Will create mysql, Elaticached, and ActiveMQ instances and a backend securyty group.

 

The bastion module should be created prior to db moddule.

Without this block: the terraform local backend , an error message will be generated saying the state file could not be read.


Login into your bastionHost to initialize the db with the schema  using the below command

clone the source code

Use the below command to initialize the db with the schema

command: mysql -h "dbendpoint" -u "dbusername" -p"dbpassword" "DBaccountName" < db_backup.sql

Edit your application.properties file with the rds, elasticcahe, and activeMq endpoints as well as password and username of your rds and activeMq.

built your artifact 

 

4- create a directory called iam_role, If you change the directory name, remember to adjust the path in terraform block.

terraform init
 terraform plan
 terraform apply

This module create IAM role service and policies for Elasticbeanstalk and an instance profile.

The instance profile is used to pass an IAM role to an EC2 instance

 


5- set up the frontend: create a directory called frontend, If you change the directory name, remember to adjust the path in terraform block.

 The vpc, the beanstalk service role and ec2 role should have been created already, because you must refere it here using data block.

 

The source bundle is needed for your elasticbeanstalk app. Found here
https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/tutorials.html.

My domain name server was purchased in Goddady. I added a CNAME record and the value provided was my beanstalk domain name. After provisioning your environment, edit the configuration to add listener https and provide your domain name certificate.

The path of the source bundle will be provided in your "aws_s3_object" resource in the source argument.

Important: The s3 bucket provisions in this code will store only the source bundle zip file. Beanstalk will create automaticaly its own bucket where the artifact, and other resources will be stored. 

 
 To delete the resources provisioned do it in the following order

1- DB
2- bastion
3- network
4- frontend
5- last iam_role

Author 
-----------------------------------------------------------------------------------------------------------
Module is maintained by Ernestine D Motouom


