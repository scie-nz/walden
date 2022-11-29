output "user" {
  value = random_password.user.result
  sensitive = true
}
output "pass" {
  value = random_password.pass.result
  sensitive = true
}
output "secret_name" {
  value = kubernetes_secret.postgres.metadata[0].name
}
