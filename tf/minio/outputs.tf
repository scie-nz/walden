output "user" {
  value = var.username
  sensitive = true
}
output "pass" {
  value = var.password == "" ? random_password.admin_pass[0].result : var.password
  sensitive = true
}
output "secret_name" {
  value = kubernetes_secret.minio.metadata[0].name
}
