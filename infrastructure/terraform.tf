terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }
  required_version = ">= 1.8.5"
  backend "s3" {
    bucket         = "backend-tfstate13"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "backend-lock"

  }
}

provider "aws" {
  region = var.region
}