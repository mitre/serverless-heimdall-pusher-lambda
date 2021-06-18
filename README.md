# Serverless Heimdall Pusher (AWS)

This lambda function is meant to allow you listen to and S3 bucket for HDF results and push them to a Heimdall Server.

## Table of Contents
- [How Does This Lambda Work?](#how-does-this-lambda-work)
- [How Can I Deploy This Lambda with Terraform?](#how-can-i-deploy-this-lambda-with-terraform)
- [What Format Do JSON Files Need to Be in for the Function to Process Results?](#what-format-do-json-files-need-to-be-in-for-the-function-to-process-results)

## How Does This Lambda Work?

The lambda function is triggered when new files hit an S3 bucket that you specify under the `unprocessed/*` folder. The lambda will then take several steps to process the results:
1. Fetch the new file from S3
2. Form a valid API request for a [Heimdall server](https://github.com/mitre/heimdall2) and tag the result with `HeimdallPusher`
3. Send the API request to the configured Heimdall server
4. Save the HDF to the same S3 bucket under `hdf/*`
5. Save the original file to the same S3 bucket under `processed/*` 
6. Delete the unprocessed version of the file from the S3 bucket

## How Can I Deploy This Lambda with Terraform?

Before deploying with terraform you will need to pull the docker image to your deployment machine
```bash
docker pull ghcr.io/mitre/serverless-heimdall-pusher-lambda:<version>
```

```hdf
##
# Heimdall Pusher Lambda function
#
# https://github.com/mitre/serverless-heimdall-pusher-lambda
#
module "serverless-heimdall-pusher-lambda" {
  source = "github.com/mitre/serverless-heimdall-pusher-lambda"
  heimdall_url      = "https://target-heimdall.com"
  heimdall_user     = ""
  heimdall_password = ""
  results_bucket_id = "bucket_name"
  subnet_ids        = ["subnet-00000000000000000"]
  security_groups   = ["sg-00000000000000000"]
  lambda_role_arn   = aws_iam_role.InSpecRole.arn
  lambda_name       = "serverless-heimdall-pusher-lambda"
}
```

## What Format Do JSON Files Need to Be in for the Function to Process Results?

New files that are added to the S3 bucket under `unprocessed/*` and are in the below format can trigger the lambda and have it process the results properly.

```javascript
{
  "data": {}, // This is where the HDF results go
  "eval_tags": "ServerlessInspec,RHEL7" // These are any tags that should be assigned in Heimdall
}
```

### NOTICE

© 2019-2021 The MITRE Corporation.

Approved for Public Release; Distribution Unlimited. Case Number 18-3678.

### NOTICE

MITRE hereby grants express written permission to use, reproduce, distribute, modify, and otherwise leverage this software to the extent permitted by the licensed terms provided in the LICENSE.md file included with this project.

### NOTICE

This software was produced for the U. S. Government under Contract Number HHSM-500-2012-00008I, and is subject to Federal Acquisition Regulation Clause 52.227-14, Rights in Data-General.

No other use other than that granted to the U. S. Government, or to those acting on behalf of the U. S. Government under that Clause is authorized without the express written permission of The MITRE Corporation.