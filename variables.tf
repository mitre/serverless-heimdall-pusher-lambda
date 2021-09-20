
variable "heimdall_public" {
  description = "Set this to 'true' if results should be visible by anyone in Heimdall"
  type        = string
  default     = "false"
}

variable "heimdall_url" {
  description = "The url to the Heimdall server in http://... format"
  type        = string
}

variable "heimdall_user" {
  description = "The Heimdall user's email used to log in"
  type        = string
}

variable "heimdall_password" {
  description = "The Heimdall user's password used to log in"
  type        = string
  sensitive   = true
}

variable "results_bucket_id" {
  description = "The S3 bucket id/name where results will be placed and processed"
  type        = string
}

variable "results_bucket_source_account_id" {
  description = "The AWS account ID (without a hyphen) of the results S3 bucket source owner."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "The subnet ids to deploy the lambda to."
  type        = list(string)
  default     = null
}

variable "security_groups" {
  description = "The security groups to assign to the lambda."
  type        = list(string)
  default     = null
}

variable "image_version" {
  description = "The image and tag of the lambda docker image to deploy"
  type = string
  default = null
}

variable "lambda_name" {
  description = "The name of the lambda function"
  type = string
  default = "serverless-inspec-lambda"
}
