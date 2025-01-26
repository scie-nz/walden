variable "namespace" {
  type = string
}

variable "image_busybox" {
  type = string
}
variable "image_trino" {
  type = string
}

variable "metastore_host" {
  type = string
}
variable "metastore_port" {
  type = number
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

variable "coordinator_worker" {
  type = bool
}
variable "worker_replicas" {
  type = number
}
variable "coordinator_mem_limit" {
  type = string
}
variable "worker_mem_limit" {
  type = string
}
variable "worker_mem_cache" {
  type = string
}
variable "heap_mem_percent" {
  type = number
}

variable "extra_command" {
  type = string
}
variable "extra_ports" {
  type = map
}
variable "extra_catalogs" {
  type = map
}

variable "coordinator_node_selector" {
  type = map
}
variable "worker_node_selector" {
  type = map
}
variable "coordinator_tolerations" {
  type = list(object({
    effect = string
    key = string
    operator = string
    value = string
  }))
  default = []
}
variable "worker_tolerations" {
  type = list(object({
    effect = string
    key = string
    operator = string
    value = string
  }))
  default = []
}
