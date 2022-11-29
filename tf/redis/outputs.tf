output "pass" {
  value = random_password.pass.result
  sensitive = true
}
output "secret_name" {
  value = kubernetes_secret.redis.metadata[0].name
}
