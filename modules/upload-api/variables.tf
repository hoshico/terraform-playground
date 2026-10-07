variable "bucket_name" {
  type = string
}

variable "build_id" {
  type        = string
  description = "TypeScript build hash. The zip waits on this so the compiled file exists."
}

variable "aws_endpoint_url" {
  type        = string
  description = "Endpoint the Lambda container uses to reach LocalStack."
}

variable "function_name" {
  type    = string
  default = "request-upload"
}

variable "stage_name" {
  type    = string
  default = "dev"
}
