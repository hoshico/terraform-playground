output "queue_arn" {
  value      = aws_sqs_queue.incoming.arn
  depends_on = [aws_sqs_queue_policy.allow_s3]
}

output "queue_url" {
  value = aws_sqs_queue.incoming.url
}

output "dlq_url" {
  value = aws_sqs_queue.dlq.url
}
