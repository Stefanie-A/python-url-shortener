# variable "remote_state_bucket" {
#   description = "The name of the s3 bucket to store the terraform state file"
#   type        = string
#   default     = "terraform-state21525"
# }

variable "dynamodb_state_table" {
  description = "The name of the dynamodb table to store the terraform state lock"
  type        = string
  default     = "terraform-state-lock"
}

variable "region" {
  description = "The region to launch the instance"
  default     = "us-east-1"
}

variable "dynamodb_table_name" {
  description = "The name of the dynamodb table"
  type        = string
  default     = "url-table"
}

variable "lambda_name" {
  description = "The name of the Lambda function"
  default     = "url-function"
}

variable "lambda_handler" {
  description = "The name of the Lambda function handler"
  default     = "main.lambda_handler"
}

variable "file_upload_bucket" {
  description = "The name of the s3 bucket to upload files"
  type        = string
  default     = "file-upload21525"
}

variable "api_gateway_name" {
  description = "The name of the API Gateway"
  default     = "api21525"

}