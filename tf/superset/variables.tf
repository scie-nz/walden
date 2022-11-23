variable "namespace" {
  type = string
}

variable "image_busybox" {
  type = string
}
variable "image_superset" {
  type = string
}

variable "username" {
  type = string
}
variable "password" {
  type = string
}
variable "worker_replicas" {
  type = number
}
variable "mem_limit_server" {
  type = string
}
variable "mem_limit_worker" {
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

variable "redis_host" {
  type = string
}
variable "redis_secret_name" {
  type = string
}

variable "extra_datasources" {
  type = string
}

variable "scheduler_node_selector" {
  type = map
}
variable "worker_node_selector" {
  type = map
}
variable "app_node_selector" {
  type = map
}
variable "scheduler_tolerations" {
  type = list(object({
    effect = string
    key = string
    operator = string
    value = string
  }))
}
variable "worker_tolerations" {
  type = list(object({
    effect = string
    key = string
    operator = string
    value = string
  }))
}
variable "app_tolerations" {
  type = list(object({
    effect = string
    key = string
    operator = string
    value = string
  }))
}
