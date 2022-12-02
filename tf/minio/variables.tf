variable "namespace" {
  type = string
}

variable "name" {
  type = string
}

variable "image" {
  type = string
}

variable "username" {
  type = string
  validation {
    condition = length(var.username) >= 3
    error_message = "Minio username must be at least 3 characters long"
  }
}
variable "password" {
  type = string
  validation {
    condition = var.password == "" || length(var.password) >= 8
    error_message = "Minio password must be at least 8 characters long"
  }
}
variable "replicas" {
  type = number
  validation {
    condition = var.replicas == 1 || var.replicas >= 4
    error_message = "Minio requires a minimum of four replicas"
  }
}
variable "mem_limit" {
  type = string
}
variable "node_selector" {
  type = map
}
variable "tolerations" {
  type = list(object({
    effect = string
    key = string
    operator = string
    value = string
  }))
}
variable "storage" {
  type = string
}
variable "nfs_server" {
  type = string
}
variable "nfs_path" {
  type = string
}
