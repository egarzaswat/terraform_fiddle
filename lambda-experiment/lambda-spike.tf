variable "access_key" {}
variable "secret_key" {}
variable "region" {}

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}
#set up queue for receiving messages
resource "aws_sqs_queue" "terraform-sqs-test" {
  name = "lambda-feeder-queue"
}
#create bucket for code storage
resource "aws_s3_bucket" "lambda-code-bucket" {
    bucket = "lambda-spike-code-bucket"
}
#populate bucket with code
resource "aws_s3_bucket_object" "lambda-code" {
    key = "v1.0.0/example.zip"
    bucket = "${aws_s3_bucket.lambda-code-bucket.id}"
    source = "example.zip"
    etag = "${md5(file("example.zip"))}"
}
#create lambda using s3 bucket code
resource "aws_lambda_function" "lambda-hello-world-mark-1" {
    function_name = "helloWorld"

    s3_bucket = "${aws_s3_bucket.lambda-code-bucket.id}"
    s3_key = "${aws_s3_bucket_object.lambda-code.id}"

    handler = "main.handler"
    runtime = "nodejs6.10"

    role = "${aws_iam_role.lambda_basic_role.arn}"
}

#create basic role and add our lambda to role
resource "aws_iam_role" "lambda_basic_role" {
  name = "serverless_example_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Principal": {
            "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
    }
  ]
}
EOF
}
#create policy for lambda to access only the created queue
data "aws_iam_policy_document" "lambda-sqs-permissions" {
    statement {
        actions = ["sqs:*"]
        resources = [
            "${aws_sqs_queue.terraform-sqs-test.arn}"
        ]
    }
}
#add above policy as a permission
resource "aws_iam_policy" "lambda-sqs-permissions" {
    name = "lambda-sqs-permissions"
    path = "/"
    policy = "${data.aws_iam_policy_document.lambda-sqs-permissions.json}"
}
#add above permission to lambda's role
resource "aws_iam_role_policy_attachment" "lambda-sqs-permissions" {
    role       = "${aws_iam_role.lambda_basic_role.name}"
    policy_arn = "${aws_iam_policy.lambda-sqs-permissions.arn}"
}

#create pipe from queue to lambda
resource "aws_lambda_event_source_mapping" "lambda-sqs-link" {
  event_source_arn = "${aws_sqs_queue.terraform-sqs-test.arn}"
  function_name    = "${aws_lambda_function.lambda-hello-world-mark-1.arn}"
  batch_size = "1"
}