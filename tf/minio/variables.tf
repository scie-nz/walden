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
}
variable "password" {
  type = string
}
variable "replicas" {
  type = number
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
