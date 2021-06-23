
##
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region
#
data "aws_region" "current" {}

##
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity
#
data "aws_caller_identity" "current" {}

##
# Computed local variables
#
locals {
  # If image_version is not set, then default to the lastest available version
  image_version = var.image_version != null ? var.image_version : file("${path.module}/version")
}

# Elastic Container Registry for SAF deployment
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository
#
resource "aws_ecr_repository" "mitre_heimdall_pusher" {
  name                 = "mitre/serverless-heimdall-pusher-lambda"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

##
# The KMS key used to encrypt/decrypt HeimdallPusher's Heimdall account password 
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key
#
resource "aws_kms_key" "HeimdallPassKmsKey" {
  description             = "The KMS key used to encrypt/decrypt HeimdallPusher's Heimdall account password "
  deletion_window_in_days = 10

  tags = {
    Name = "HeimdallPusherPassKmsKey"
  }
}

##
# SSM SecureString parameter for the Heimdall password
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter
#
resource "aws_ssm_parameter" "heimdall_pass_ssm_param" {
  name        = "/serverless-heimdall-pusher-lambda/heimdall_pass_ssm_param"
  description = "Stores the password for HeimdallPusher's Heimdall account."
  type        = "SecureString"
  value       = var.heimdall_password
  key_id      = aws_kms_key.HeimdallPassKmsKey.key_id
}

##
# HeimdallPusher Role to Invoke HeimdallPusher Lambda function 
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
#
resource "aws_iam_role" "serverless_heimdall_pusher_lambda_role" {
  name = "serverless_heimdall_pusher_lambda_role"

  # Allow execution of the lambda function
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  ]

  # Allow assume role permission for lambda
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  # Allow READ access to Heimdall password SSM parameter
  inline_policy {
    name = "HeimdallPassSsmReadAccess"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "ssm:GetParameter"
          ]
          Effect   = "Allow"
          Resource = aws_ssm_parameter.heimdall_pass_ssm_param.arn
        }
      ]
    })
  }

  inline_policy {
    name = "AllowHeimdallPassKmsKeyDecrypt"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "kms:Decrypt"
          ]
          Effect   = "Allow"
          Resource = aws_kms_key.HeimdallPassKmsKey.arn
        }
      ]
    })
  }

  # Allow S3 read and write access to InSpec results bucket
  inline_policy {
    name = "S3ResultsAccess"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject"
          ]
          Effect   = "Allow"
          Resource = "${data.aws_s3_bucket.results_bucket.arn}/*"
        }
      ]
    })
  }
}

resource "null_resource" "push_image" {
  depends_on = [
    aws_ecr_repository.mitre_heimdall_pusher,
  ]

  # Ensures this script always runs
  triggers = {
    always_run = timestamp()
  }

  # https://www.terraform.io/docs/language/resources/provisioners/local-exec.html
  provisioner "local-exec" {
    command = "${path.module}/push-image.sh"

    environment = {
      REPOSITORY_URL = aws_ecr_repository.mitre_heimdall_pusher.repository_url
      AWS_REGION     = data.aws_region.current.name
      AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
      REPO_NAME      = "ghcr.io/mitre/serverless-heimdall-pusher-lambda"
      IMAGE_TAG      = local.image_version
    }
  }
}

##
# HeimdallPusher Lambda function
#
# https://registry.terraform.io/modules/terraform-aws-modules/lambda/aws/latest
#
module "serverless-heimdall-pusher-lambda" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = var.lambda_name
  description   = "Lambda capable of pulling AWS Config data, mapping to HDF, and pushing results to Heimdall Server API."
  handler       = "lambda_function.lambda_handler"
  runtime       = "ruby2.7"
  create_role   = false
  lambda_role   = aws_iam_role.serverless_heimdall_pusher_lambda_role.arn
  timeout       = 900

  vpc_subnet_ids         = var.subnet_ids
  vpc_security_group_ids = var.security_groups

  create_package = false
  image_uri      = "${aws_ecr_repository.mitre_heimdall_pusher.repository_url}:${local.image_version}"
  package_type   = "Image"

  environment_variables = {
    HEIMDALL_URL            = var.heimdall_url
    HEIMDALL_API_USER       = var.heimdall_user
    HEIMDALL_PASS_SSM_PARAM = aws_ssm_parameter.heimdall_pass_ssm_param.name
    HEIMDALL_PUBLIC         = var.heimdall_public
  }
}

##
# Get bucket data for use elsewhere
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket
#
data "aws_s3_bucket" "results_bucket" {
  bucket = var.results_bucket_id
}

##
# Allow the bucket events to trigger the pusher lambda
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission
#
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowHeimdallPusherExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = module.serverless-heimdall-pusher-lambda.lambda_function_arn
  principal     = "s3.amazonaws.com"
  source_arn    = data.aws_s3_bucket.results_bucket.arn
}

##
# Trigger lambda when objects get placed in 'unprocessed/*'
#
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification
#
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = var.results_bucket_id

  lambda_function {
    lambda_function_arn = module.serverless-heimdall-pusher-lambda.lambda_function_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "unprocessed/"
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}
