data "archive_file" "request" {
  type = "zip"
  # Referencing build_id makes Terraform wait until the TypeScript build writes index.js.
  source_file = var.build_id != "" ? "${path.module}/build/index.js" : "${path.module}/build/index.js"
  output_path = "${path.module}/build/request_upload.zip"
}

resource "aws_cloudwatch_log_group" "request" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "request" {
  name               = var.function_name
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "request" {
  statement {
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = [
      "arn:aws:s3:::${var.bucket_name}/incoming/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.request.arn}:*"]
  }
}

resource "aws_iam_role_policy" "request" {
  name   = var.function_name
  role   = aws_iam_role.request.id
  policy = data.aws_iam_policy_document.request.json
}

resource "aws_lambda_function" "request" {
  function_name    = var.function_name
  role             = aws_iam_role.request.arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  filename         = data.archive_file.request.output_path
  source_code_hash = data.archive_file.request.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      BUCKET_NAME      = var.bucket_name
      AWS_ENDPOINT_URL = var.aws_endpoint_url
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.request,
    aws_iam_role_policy.request,
  ]
}

resource "aws_api_gateway_rest_api" "this" {
  name               = var.function_name
  binary_media_types = ["application/octet-stream"]
}

resource "aws_api_gateway_resource" "uploads" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "uploads"
}

resource "aws_api_gateway_method" "post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.uploads.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.uploads.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.request.invoke_arn
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.uploads.id,
      aws_api_gateway_method.post.id,
      aws_api_gateway_integration.post.id,
      aws_api_gateway_rest_api.this.binary_media_types,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.stage_name
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.request.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}
