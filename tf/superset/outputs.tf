output "user" {
  value = var.username
  sensitive = true
}
output "pass" {
  value = var.password == "" ? random_password.admin_pass[0].result : var.password
  sensitive = true
}
