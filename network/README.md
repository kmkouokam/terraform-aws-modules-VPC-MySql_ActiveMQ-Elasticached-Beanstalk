
Step 1

create a Directory called network. If you change the directory name, remember to adjust the path in terraform block.

This module create a network for the whole infrastructure. It has public subnet in 2 AZ where the bastion and beanstalk instances will be deployed. A private subnet for backend resources