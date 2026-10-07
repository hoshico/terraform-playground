variable "queue_name" {
  type    = string
  default = "incoming-objects"
}

variable "bucket_name" {
  type = string
}

variable "max_receive_count" {
  type    = number
  default = 3
}

variable "visibility_timeout_seconds" {
  type    = number
  default = 60
}
