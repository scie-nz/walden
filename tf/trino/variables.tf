variable "namespace" {
  type = string
}

variable "image_alluxio" {
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

variable "alluxio_enabled" {
  type = bool
}
variable "alluxio_root_mount" {
  type = string
}
variable "alluxio_mem_cache" {
  type = string
}

variable "trino_worker_replicas" {
  type = number
}
variable "trino_coordinator_mem_limit" {
  type = string
}
variable "trino_worker_mem_limit" {
  type = string
}
variable "trino_worker_mem_cache" {
  type = string
}

variable "trino_config_query_max_memory_per_node" {
  type = string
}
variable "trino_config_query_max_memory" {
  type = string
}
variable "trino_config_memory_heap_headroom_per_node" {
  type = string
}

variable "trino_worker_startup_command" {
  type = string
}
variable "trino_extra_ports" {
  type = map
}
variable "trino_extra_catalogs" {
  type = map
}

variable "trino_coordinator_node_selector" {
  type = map
}
variable "trino_worker_node_selector" {
  type = map
}
variable "trino_coordinator_tolerations" {
  type = list(object({
    effect = string
    key = string
    operator = string
    value = string
  }))
  default = []
}
variable "trino_worker_tolerations" {
  type = list(object({
    effect = string
    key = string
    operator = string
    value = string
  }))
  default = []
}
