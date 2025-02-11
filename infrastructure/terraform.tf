terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }
  required_version = ">= 1.2.0"
  backend "s3" {
    bucket = "terraform-state21125"
    key    = "terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    
  }
}

provider "aws" {
  region = var.region
}