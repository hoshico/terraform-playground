locals {
  # Provider calls stay on localhost. Lambda runs in a container, so it uses the host gateway.
  lambda_endpoint = "http://host.docker.internal:4566"
  bucket_name     = "dev-upload-incoming"
}

data "external" "lambda_build" {
  program     = ["node", "${path.module}/../../scripts/build-lambdas.mjs"]
  working_dir = "${path.module}/../.."
}

module "vpc" {
  source = "../../modules/vpc"

  name   = "dev"
  region = "ap-northeast-1"
}

module "sqs" {
  source = "../../modules/sqs"

  bucket_name = local.bucket_name
}

module "s3" {
  source = "../../modules/s3"

  bucket_name = local.bucket_name
  queue_arn   = module.sqs.queue_arn
}

module "upload_api" {
  source = "../../modules/upload-api"

  bucket_name      = local.bucket_name
  aws_endpoint_url = local.lambda_endpoint
  build_id         = data.external.lambda_build.result.request
}

module "upload_worker" {
  source = "../../modules/upload-worker"

  bucket_name        = local.bucket_name
  queue_arn          = module.sqs.queue_arn
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.lambda_security_group_id]
  aws_endpoint_url   = local.lambda_endpoint
  build_id           = data.external.lambda_build.result.worker
}
