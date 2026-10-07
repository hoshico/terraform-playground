resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_notification" "incoming" {
  bucket = aws_s3_bucket.this.id

  queue {
    queue_arn     = var.queue_arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "incoming/"
  }
}
