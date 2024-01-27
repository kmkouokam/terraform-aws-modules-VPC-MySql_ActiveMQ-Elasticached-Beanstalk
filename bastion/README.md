step 2


Set up the bastion host to login to your RDS: create a Directory called bastion. If you change the directory name, remember to adjust the path in terraform block.

Add SSH rule to bation security group form MyIP
Login to bastion
clone the source code

Important: The network should have been created already, beacuse you need to refere this data.terraform_remote_state.vpc in your bastion main.tf code file

Without the terraform local backend block, terraform will tell you that the state file cannot be read. 