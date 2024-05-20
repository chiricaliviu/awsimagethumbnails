terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  access_key = var.access_key
  secret_key = var.secret_key
}


resource "aws_s3_bucket" "inputBucket" {
  bucket = "liviuinputbucket1"
  force_destroy = true

  tags = {
    Name        = "My input bucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket" "outputBucket" {
  bucket = "liviuoutputbucket1"
  force_destroy = true

  tags = {
    Name        = "Output bucket with thumbnails created"
    Environment = "Dev"
  }
}

resource "aws_iam_policy" "LambdaS3ThumbnailsPolicy" {
  name        = "LambdaS3ThumbnailsPolicy"
  path        = "/"
  description = "Policy to allow usage of the S3 buckets"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:PutLogEvents",
                "logs:CreateLogGroup",
                "logs:CreateLogStream"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::liviuinputbucket1/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject"
            ],
            "Resource": "arn:aws:s3:::liviuoutputbucket1/*"
        }
    ]
})
}

resource "aws_iam_role" "lambdaS3Role" {
  name = "LambdaS3ThumbnailsRole"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
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
      },
    ]
  })

  tags = {
    tag-key = "LambdaThumbnails"
  }
}

resource "aws_iam_role_policy_attachment" "lambdaS3_attachment" {
    role = aws_iam_role.lambdaS3Role.name
    policy_arn = aws_iam_policy.LambdaS3ThumbnailsPolicy.arn
}

data "archive_file" "lambda_zip" {
type        = "zip"
source_dir  = "source"
output_path = "functionthumbnails.zip"
}
resource "aws_lambda_function" "thumbnailslambda" {
  filename      = "functionthumbnails.zip"
  function_name = "LambdaThumbnails"
  role          = aws_iam_role.lambdaS3Role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  depends_on    = [aws_iam_role_policy_attachment.lambdaS3_attachment]
  
}
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.thumbnailslambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.inputBucket.arn
}
# Adding S3 bucket as trigger to my lambda and giving the permissions
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.inputBucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.thumbnailslambda.arn
    events              = ["s3:ObjectCreated:*"]

  }

  depends_on = [aws_lambda_permission.allow_bucket]
}