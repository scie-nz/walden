resource "random_password" "pass" {
  length = 32
  special = false
}

resource "kubernetes_secret" "redis" {
  metadata {
    labels = {
      app = var.name
    }
    name = var.name
    namespace = var.namespace
  }
  type = "Opaque"
  data = {
    pass = random_password.pass.result
  }
}

resource "kubernetes_service" "redis" {
  metadata {
    labels = {
      app = var.name
    }
    name = var.name
    namespace = var.namespace
  }
  spec {
    port {
      name = "redis"
      port = 6379
      target_port = "redis"
    }
    selector = {
      app = var.name
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_stateful_set" "redis" {
  metadata {
    labels = {
      app = var.name
    }
    name = var.name
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = var.name
      }
    }
    service_name = var.name
    template {
      metadata {
        labels = {
          app = var.name
        }
      }
      spec {
        container {
          command = [
            "/bin/sh",
            "-c",
            "redis-server --bind 0.0.0.0 --requirepass $REDIS_PASSWORD --loglevel $LOG_LEVEL --dir /data --maxmemory ${var.max_memory} --maxmemory-policy allkeys-lru --lazyfree-lazy-eviction yes --lazyfree-lazy-expire yes --io-threads 3",
          ]
          env {
            name = "LOG_LEVEL"
            value = "notice"
          }
          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                key = "pass"
                name = kubernetes_secret.redis.metadata[0].name
              }
            }
          }
          image = var.image
          name = "server"
          port {
            container_port = 6379
            name = "redis"
          }
          startup_probe {
            initial_delay_seconds = 5
            period_seconds = 10
            tcp_socket {
              port = "redis"
            }
          }
          volume_mount {
            mount_path = "/data"
            name = "storage"
          }
        }
      }
    }
    volume_claim_template {
      metadata {
        name = "storage"
      }
      spec {
        access_modes = [
          "ReadWriteOnce",
        ]
        resources {
          requests = {
            storage = var.storage
          }
        }
      }
    }
  }
}
