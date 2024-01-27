

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
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
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
  special = true

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
