step 3


Set up your backend: create a directory called db, If you change the directory name, remember to adjust the path in the terraform block.



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