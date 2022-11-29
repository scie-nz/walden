resource "random_password" "user" {
  length = 32
  special = false
}
resource "random_password" "pass" {
  length = 32
  special = false
}

resource "kubernetes_secret" "postgres" {
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
    user = random_password.user.result
  }
}

resource "kubernetes_service" "postgres" {
  metadata {
    labels = {
      app = var.name
    }
    name = var.name
    namespace = var.namespace
  }
  spec {
    port {
      name = "postgres"
      port = 5432
      target_port = "postgres"
    }
    selector = {
      app = var.name
    }
  }
}

resource "kubernetes_stateful_set" "postgres" {
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
            "bash",
            "-c",
            "mkdir -p $PGDATA && chown -R postgres:postgres $PGDATA && chmod 777 $PGDATA && /usr/local/bin/docker-entrypoint.sh postgres",
          ]
          env {
            name = "PGDATA"
            value = "/storage/postgres"
          }
          env {
            name = "POSTGRES_DB"
            value = var.db
          }
          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                key = "user"
                name = kubernetes_secret.postgres.metadata[0].name
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                key = "pass"
                name = kubernetes_secret.postgres.metadata[0].name
              }
            }
          }
          image = var.image
          name = "postgres"
          port {
            container_port = 5432
            name = "postgres"
          }
          resources {
            limits = {
              hugepages-2Mi = "512Mi"
              memory = "512Mi"
            }
          }
          startup_probe {
            exec {
              command = [
                "/bin/bash",
                "-c",
                "pg_isready -q -d $POSTGRES_DB -U $POSTGRES_USER",
              ]
            }
            failure_threshold = 60
            initial_delay_seconds = 10
            period_seconds = 5
            timeout_seconds = 10
          }
          volume_mount {
            mount_path = "/storage"
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
