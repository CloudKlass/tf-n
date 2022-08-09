terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0.0"
    }
    random = {
      source  = "hashicorp/random" # Path to Docs: https://registry.terraform.io/providers/hashicorp/random/latest/docs
      version = "~> 3.3.2"
    }
    archive = {
      source  = "hashicorp/archive" # Path to Docs: https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/archive_file
      version = "~> 2.2.0"
    }
  }

  required_version = "~> 1.0"
}

provider "aws" {
  region = var.aws_region
}

resource "random_string" "bucketname" {  # Generate Random string to append to lab5 prefix
  prefix = "lab5"
  length = 6
}

resource "aws_s3_bucket" "lambda_bucket" { # Use generated string to create bucket
  bucket = random_string.bucketname.id

  acl           = "private"
  force_destroy = true
}
                                            # Create Archive to prepare for upload to Lambda service
data "archive_file" "lambda_archive" {
  type = "zip"

  source_dir  = "${path.module}/lambdaArchive" # Interpolations are wrapped in ${} and path.module represents the path to the module/folder
  output_path = "${path.module}/lambdaArchive.zip"
}

resource "aws_s3_object" "lambda_upload" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "lambdaArchive.zip"
  source = data.archive_file.lambda_archive.output_path

  etag = filemd5(data.archive_file.lambda_archive.output_path)
}

# Add the creation of the Lambda function

resource "aws_lambda_function" "hello" {
  function_name = "HelloLearners"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_upload.key

  runtime = "nodejs16.x"
  handler = "hello.handler"

  source_code_hash = data.archive_file.lambda_archive.output_base64sha256

  role = aws_iam_role.lambda_IAM.arn
}

resource "aws_cloudwatch_log_group" "hello_lambdas" {
  name = "/aws/lambda/${aws_lambda_function.hello.function_name}"

  retention_in_days = 7
}

resource "aws_iam_role" "lambda_IAM" {
  name = "IAM_lambda"

  assume_role_policy = jsonencode({ # Defining IAM role and attaching trust policy
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_IAM.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_apigatewayv2_api" "lambda" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "serverless_lambda_stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "hello_Lab5" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.hello_Lab5.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "hello_Lab5" {
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.hello_Lab5.id}"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.lambda.name}"

  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_Lab5.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
