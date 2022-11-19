resource "random_password" "superset_postgres_user" {
  count = var.superset_postgres_internal ? 1 : 0
  length = 32
  special = false
}
resource "random_password" "superset_postgres_pass" {
  count = var.superset_postgres_internal ? 1 : 0
  length = 32
  special = false
}

resource "kubernetes_secret" "superset_postgres" {
  count = var.superset_postgres_internal ? 1 : 0
  metadata {
    labels = {
      app = "superset-postgres"
    }
    name = "superset-postgres"
    namespace = "walden"
  }
  type = "Opaque"
  data = {
    pass = random_password.superset_postgres_pass[0].result
    user = random_password.superset_postgres_user[0].result
  }
}

resource "kubernetes_service" "superset_postgres" {
  count = var.superset_postgres_internal ? 1 : 0
  metadata {
    name = "superset-postgres"
    namespace = "walden"
  }
  spec {
    port {
      name = "postgres"
      port = 5432
      target_port = "postgres"
    }
    selector = {
      app = "superset-postgres"
    }
  }
}

resource "kubernetes_stateful_set" "superset_postgres" {
  count = var.superset_postgres_internal ? 1 : 0
  metadata {
    name = "superset-postgres"
    namespace = "walden"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "superset-postgres"
      }
    }
    service_name = "superset-postgres"
    template {
      metadata {
        labels = {
          app = "superset-postgres"
        }
      }
      spec {
        container {
          command = [
            "bash",
            "-c",
            "mkdir -p $PGDATA && chown -R postgres:postgres \"$PGDATA\" && chmod 777 \"$PGDATA\" && /usr/local/bin/docker-entrypoint.sh postgres",
          ]
          env {
            name = "PGDATA"
            value = "/storage/postgres"
          }
          env {
            name = "POSTGRES_DB"
            value = "superset"
          }
          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                key = "user"
                name = "superset-postgres"
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                key = "pass"
                name = "superset-postgres"
              }
            }
          }
          image = var.image_postgres
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
            storage = "1Gi"
          }
        }
      }
    }
  }
}
