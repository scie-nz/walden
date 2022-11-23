variable "namespace" {
  type = string
}

variable "name" {
  type = string
}

variable "image_busybox" {
  type = string
}
variable "image_metastore" {
  type = string
}

variable "minio_host" {
  type = string
}
variable "minio_port" {
  type = number
}
variable "minio_secret_name" {
  type = string
}

variable "postgres_host" {
  type = string
}
variable "postgres_port" {
  type = number
}
variable "postgres_db" {
  type = string
}
variable "postgres_secret_name" {
  type = string
}
