data "aws_vpc" "default" {
  default = true
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
  key_name                    = aws_key_pair.ssh-key.key_name
  tags = {
    Name = "mox"
  }

}

resource "aws_dynamodb_table" "dynamodb_table" {
  name           = "uri-table"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "shorten-uri"

  # Define table attributes
  attribute {
    name = "shorten-uri"
    type = "S"
  }

  attribute {
    name = "original-uri"
    type = "S"
  }

  # Global Secondary Index for querying by original URI
  global_secondary_index {
    name            = "original-uri-index"
    hash_key        = "original-uri"
    write_capacity  = 10
    read_capacity   = 10
    projection_type = "ALL"
  }

  tags = {
    Name = "uriTable"
  }
}