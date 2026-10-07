output "api_id" {
  value = aws_api_gateway_rest_api.this.id
}

output "stage_name" {
  value = aws_api_gateway_stage.this.stage_name
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.request.name
}
