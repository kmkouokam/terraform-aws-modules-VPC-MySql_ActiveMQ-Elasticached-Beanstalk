step 5

set up the frontend: create a directory called frontend, If you change the directory name, remember to adjust the path in terraform block.

 The vpc, the beanstalk service role and ec2 role should have been created already, because you must refere them here using data block.

 Without the terraform local backend block, terraform will tell you that the state file cannot be read.

The source bundle is needed for your elasticbeanstalk app. Found here
https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/tutorials.html.

My domain name server was purchased in Goddady. I added a CNAME record and the value provided was my beanstalk domain name. After provisioning your environement, edit the configuration to add listener https and provide your domain name certificate.   

The path of the source bundle will be provided in your "aws_s3_object" resource in the source argument.

Important: The s3 bucket provisions in this code will store only the source bundle zip file. Beanstalk will create automaticaly its own bucket where the artifact, and other resources will be stored.

