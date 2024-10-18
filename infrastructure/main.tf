terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"

}

data "aws_vpc" "default" {
  default = true
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = "my-key"
}

resource "tls_private_key" "key-pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh-key" {
  key_name   = var.key_name
  public_key = tls_private_key.key-pair.public_key_openssh

}

resource "aws_security_group" "instance" {
  name = "fox"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
resource "aws_instance" "web_server" {
  ami                         = "ami-0866a3c8686eaeeba"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.instance.id]
  key_name = aws_key_pair.ssh-key.key_name
  user_data                   = <<-EOF
                #!/bin/bash
                mkdir myapp
                cd myapp
                sudo apt update -y
                sudo apt install docker.io -y
                EOF
  user_data_replace_on_change = true
  tags = {
    Name = "mox"
  }

}

resource "aws_dynamodb_table" "dynamodb-table" {
  name           = "uri-table"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "Id"

  attribute {
    name = "Id"
    type = "S"
  }

  attribute {
    name = "new-uri"
    type = "S"
  }

  global_secondary_index {
    name            = "NewUriIndex"
    hash_key        = "new-uri"
    write_capacity  = 10
    read_capacity   = 10
    projection_type = "ALL"
  }

  tags = {
    Name = "newURI"
  }
}

output "public_ip" {
  value       = aws_instance.web_server.public_ip
  description = "The public IP address of the web server"
}

output "private-key" {
  value     = tls_private_key.key-pair.private_key_pem
  sensitive = true

}