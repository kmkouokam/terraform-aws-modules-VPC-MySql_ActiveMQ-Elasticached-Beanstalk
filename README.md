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

2- Set up the bastion host to login to your RDS: create a Directory called bastion. If you change the directory name, remember to adjust the path in terraform block.    

Add SSH rule to bation security group form MyIP
Login to bastion
clone the source code

Important: The network should have been created already, beacuse you need to refere this data.terraform_remote_state.vpc in your bastion main.tf code file

Without the terraform local backend block, terraform will tell you that the state file cannot be read.



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



4- create a directory called iam_role, If you change the directory name, remember to adjust the path in terraform block.


This module create IAM role service and policies for Elasticbeanstalk and an instance profile.

The instance profile is used to pass an IAM role to an EC2 instance

5- set up the frontend: create a directory called frontend, If you change the directory name, remember to adjust the path in terraform block.

 The vpc, the beanstalk service role and ec2 role should have been created already, because you must refere them here using data block.

 Without the terraform local backend block, terraform will tell you that the state file cannot be read.

The source bundle is needed for your elasticbeanstalk app. Found here
https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/tutorials.html.

My domain name server was purchased in Goddady. I added a CNAME record and the value provided was my beanstalk domain name. After provisioning your environement, edit the configuration to add listener https and provide your domain name certificate.

The path of the source bundle will be provided in your "aws_s3_object" resource in the source argument.

Important: The s3 bucket provisions in this code will store only the source bundle zip file. Beanstalk will create automaticaly its own bucket where the artifact, and other resources will be stored. 


Author
--------------------------------------------------------------------------------------------------------------------------
Module is maintained by Ernestine D Motouom


