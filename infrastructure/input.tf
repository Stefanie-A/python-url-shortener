variable "remote_state_bucket" {
    description = "The name of the s3 bucket to store the terraform state file"
    type = string
    default = "terraform-statefile12525"
}

variable "dynamodb_state_table" {
    description = "The name of the dynamodb table to store the terraform state lock"
    type = string
    default = "terraform-state-lock"  
}

variable "key_name" {
  description = "Name of the ssh key for the ec2 instance"
  type = string
  default = "new-key"
}

variable "instance_type" {
  description = "The type of instance to launch"
#   default = "t2.micro"
}

variable "region" {
  description = "The region to launch the instance"
  default = "us-east-1"
}

variable "ami" {
  description = "The ami to launch the instance"
  default = "ami-0866a3c8686eaeeba"
   validation {
    condition     = length(var.ami) > 4 && substr(var.ami, 0, 4) == "ami-"
    error_message = "Please provide a valid value for variable AMI."
  }
}

# variable "vpc_security_group_ids" {
#   description = "The security group id to attach to the instance"
#   type = list(string)
#   default = ["sg-0c1f7b7b4b4b4b4b4"]
# }

variable "tags" {
  description = "The tags to attach to the instance"
  type = map(string)
  default = {
    Name = "mox"
  }
  
}

variable "dynamodb_table_name" {
  description = "The name of the dynamodb table"
  type = string
  default = "uri-table"
}

variable "ec2_instance" {
  description = "The name of the ec2 instance"
  type = string
  default = "foxy"  
}