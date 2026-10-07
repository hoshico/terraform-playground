output "upload_url" {
  value = "http://localhost:4566/restapis/${module.upload_api.api_id}/${module.upload_api.stage_name}/_user_request_/uploads"
}

output "bucket_name" {
  value = module.s3.bucket_name
}

output "queue_url" {
  value = module.sqs.queue_url
}

output "dlq_url" {
  value = module.sqs.dlq_url
}

output "request_log_group" {
  value = module.upload_api.log_group_name
}

output "worker_log_group" {
  value = module.upload_worker.log_group_name
}
