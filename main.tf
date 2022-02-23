
provider "aws" {
   region = var.region
}

# Configure the Artifactory provider
provider "artifactory" {
  url = "https://artifactory"
  username = "uname"
  password = "pass"
}

data "artifactory_file" "my-file" {
   repository = "repo-key"
   path = "/path/to/the/artifact.zip"
   output_path = "tmp/artifact.zip"
}


# Create a new repository
resource "artifactory_local_repository" "pypi-libs" {
  key             = "pypi-libs"
  package_type    = "pypi"
  repo_layout_ref = "simple-default"
  description     = "A pypi repository for python packages"
}

resource "aws_s3_bucket" "dev_bucket" {
   bucket = local.s3bucket
   acl = "private"
   tags = {
      Name  = local.s3bucket
      Environment = var.environment
   }
}

resource "aws_s3_bucket_object" "info" {
   bucket = aws_s3_bucket.dev_bucket.bucket
   key = "info/"
}
resource "aws_s3_bucket_object" "pakages" {
   bucket = aws_s3_bucket.dev_bucket.bucket
   key = "pakages/"
}
resource "aws_s3_bucket_object" "reference" {
   bucket = aws_s3_bucket.dev_bucket.bucket
   key = "reference/"
}

#----------------------- lambda definition------------#
resource "aws_lambda_function" "terraform_lambda_func" {
  filename                       = local.lambdaZipLocation
  function_name                  = "Test_Lambda_Function_new"
  role                           = aws_iam_role.lambda_role.arn
  handler                        = "lambda/lambda.hello"
  runtime                        = "python3.8"
  depends_on                     = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
  layers = [aws_lambda_layer_version.usage.arn]
}

#----------------- Defining aws lambda layers -------------#
resource "aws_lambda_layer_version" "usage" {
  layer_name = "usage"
  filename = "./usage.zip"
  compatible_runtimes = ["python3.8"]
}
#----------------- Defining aws lambda layers ENDS -------------#

resource "aws_s3_bucket_notification" "aws-lambda-trigger" {
   bucket = aws_s3_bucket.dev_bucket.id
   lambda_function {
      lambda_function_arn = aws_lambda_function.terraform_lambda_func.arn
      events = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
   }
}
#------------------- defining local variables---------#
locals {
   s3bucket = "${var.environment}-bucket-terraform-raja"
   lambdaZipLocation = "./lambda.zip"
}
#------------------ Lambda execution roles -----------#

resource "aws_iam_role" "lambda_role" {
name   = "Spacelift_Test_Lambda_Function_Role"
assume_role_policy = "${file("${path.module}/lambda-aws-iam-role.json")}"
}

resource "aws_iam_policy" "iam_policy_for_lambda" {
 name         = "aws_iam_policy_for_terraform_aws_lambda_role"
 description  = "AWS IAM Policy for managing aws lambda role"
 policy       = "${file("${path.module}/lambda-aws-iam-policy.json")}"
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
 role        = aws_iam_role.lambda_role.name
 policy_arn  = aws_iam_policy.iam_policy_for_lambda.arn
}

resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.terraform_lambda_func.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${aws_s3_bucket.dev_bucket.id}"
}
