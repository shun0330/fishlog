variable "region" {
  type    = string
  default = "ap-northeast-1"
}

variable "project" {
  type    = string
  default = "fishlog"
}

variable "alert_email" {
  type        = string
  description = "アラーム通知先のメールアドレス"
}
