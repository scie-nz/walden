resource "random_password" "key" {
  length = 32
  special = false
}

resource "random_password" "admin_pass" {
  count = var.password == "" ? 1 : 0
  length = 32
  special = false
}

resource "kubernetes_secret" "key" {
  metadata {
    labels = {
      app = "superset"
    }
    name = "superset-key"
    namespace = var.namespace
  }
  type = "Opaque"
  data = {
    key = random_password.key.result
  }
}

resource "kubernetes_secret" "admin" {
  metadata {
    labels = {
      app = "superset"
    }
    name = "superset-admin"
    namespace = var.namespace
  }
  type = "Opaque"
  data = {
    pass = var.password == "" ? random_password.admin_pass[0].result : var.password
    user = var.username
  }
}

resource "kubernetes_config_map" "superset" {
  metadata {
    labels = {
      app = "superset"
    }
    name = "superset"
    namespace = var.namespace
  }
  data = {
    "superset_config.py" = file("${path.module}/superset_config.py")

    "superset_datasources.yaml" = <<-EOT
databases:
- database_name: trino-hive
  allow_ctas: true
  allow_cvas: true
  allow_run_async: true
  extra: '{"cost_estimate_enabled":true,"allows_virtual_table_explore":true,"metadata_params":{},"engine_params":{},"schemas_allowed_for_csv_upload":[]}'
  sqlalchemy_uri: trino://trino:80/hive
- database_name: trino-system
  allow_run_async: true
  extra: '{"cost_estimate_enabled":true,"allows_virtual_table_explore":true,"metadata_params":{},"engine_params":{},"schemas_allowed_for_csv_upload":[]}'
  sqlalchemy_uri: trino://trino:80
${var.extra_datasources}
EOT

    "superset_init.sh" = file("${path.module}/superset_init.sh")
  }
}

resource "kubernetes_service" "superset" {
  metadata {
    labels = {
      app = "superset"
    }
    name = "superset"
    namespace = var.namespace
  }
  spec {
    port {
      name = "http"
      port = 80
      target_port = "http"
    }
    selector = {
      app = "superset"
    }
  }
}

resource "kubernetes_deployment" "scheduler" {
  metadata {
    labels = {
      app = "superset-scheduler"
    }
    name = "superset-scheduler"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "superset-scheduler"
      }
    }
    template {
      metadata {
        labels = {
          app = "superset-scheduler"
        }
      }
      spec {
        container {
          command = [
            "celery",
            "--pidfile=",
            "--schedule=/tmp/celerybeat-schedule",
            "--app=superset.tasks.celery_app:app",
            "beat",
          ]
          env {
            name = "SECRET_KEY"
            value_from {
              secret_key_ref {
                key = "key"
                name = kubernetes_secret.key.metadata[0].name
              }
            }
          }
          env {
            name = "REDIS_HOST"
            value = var.redis_host
          }
          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                key = "pass"
                name = var.redis_secret_name
              }
            }
          }
          env {
            name = "POSTGRES_HOST"
            value = var.postgres_host
          }
          env {
            name = "POSTGRES_PORT"
            value = var.postgres_port
          }
          env {
            name = "POSTGRES_DB"
            value = var.postgres_db
          }
          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                key = "user"
                name = var.postgres_secret_name
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                key = "pass"
                name = var.postgres_secret_name
              }
            }
          }
          image = var.image_superset
          name = "superset"
          resources {
            limits = {
              memory = "256Mi"
            }
          }
          volume_mount {
            mount_path = "/app/pythonpath"
            name = "config"
            read_only = true
          }
        }
        init_container {
          command = [
            "/bin/sh",
            "-c",
            "until nc -zv $POSTGRES_HOST $POSTGRES_PORT -w1; do echo waiting for postgres: $POSTGRES_HOST:$POSTGRES_PORT; sleep 1; done",
          ]
          env {
            name = "POSTGRES_HOST"
            value = var.postgres_host
          }
          env {
            name = "POSTGRES_PORT"
            value = var.postgres_port
          }
          image = var.image_busybox
          name = "wait-for-postgres"
        }
        node_selector = var.scheduler_node_selector
        dynamic "toleration" {
          for_each = var.scheduler_tolerations
          content {
            effect = toleration.value.effect
            key = toleration.value.key
            operator = toleration.value.operator
            value = toleration.value.value
          }
        }
        volume {
          config_map {
            name = kubernetes_config_map.superset.metadata[0].name
          }
          name = "config"
        }
      }
    }
  }
}

resource "kubernetes_deployment" "worker" {
  metadata {
    labels = {
      app = "superset-worker"
    }
    name = "superset-worker"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "superset-worker"
      }
    }
    template {
      metadata {
        labels = {
          app = "superset-worker"
        }
      }
      spec {
        container {
          command = [
            "celery",
            "--app=superset.tasks.celery_app:app",
            "worker",
            "--pool=prefork",
            "--max-tasks-per-child=128",
          ]
          env {
            name = "SECRET_KEY"
            value_from {
              secret_key_ref {
                key = "key"
                name = kubernetes_secret.key.metadata[0].name
              }
            }
          }
          env {
            name = "REDIS_HOST"
            value = var.redis_host
          }
          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                key = "pass"
                name = var.redis_secret_name
              }
            }
          }
          env {
            name = "POSTGRES_HOST"
            value = var.postgres_host
          }
          env {
            name = "POSTGRES_PORT"
            value = var.postgres_port
          }
          env {
            name = "POSTGRES_DB"
            value = var.postgres_db
          }
          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                key = "user"
                name = var.postgres_secret_name
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                key = "pass"
                name = var.postgres_secret_name
              }
            }
          }
          image = var.image_superset
          name = "superset"
          resources {
            limits = {
              memory = var.mem_limit_worker
            }
          }
          volume_mount {
            mount_path = "/app/pythonpath"
            name = "config"
            read_only = true
          }
        }
        init_container {
          command = [
            "/bin/sh",
            "-c",
            "until nc -zv $POSTGRES_HOST $POSTGRES_PORT -w1; do echo waiting for postgres: $POSTGRES_HOST:$POSTGRES_PORT; sleep 1; done",
          ]
          env {
            name = "POSTGRES_HOST"
            value = var.postgres_host
          }
          env {
            name = "POSTGRES_PORT"
            value = var.postgres_port
          }
          image = var.image_busybox
          name = "wait-for-postgres"
        }
        node_selector = var.worker_node_selector
        dynamic "toleration" {
          for_each = var.worker_tolerations
          content {
            effect = toleration.value.effect
            key = toleration.value.key
            operator = toleration.value.operator
            value = toleration.value.value
          }
        }
        volume {
          config_map {
            name = kubernetes_config_map.superset.metadata[0].name
          }
          name = "config"
        }
      }
    }
  }
}

resource "kubernetes_deployment" "superset" {
  metadata {
    labels = {
      app = "superset"
    }
    name = "superset"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "superset"
      }
    }
    template {
      metadata {
        labels = {
          app = "superset"
        }
      }
      spec {
        container {
          command = [
            "/bin/sh",
            "-c",
            <<-EOT
sed -i s/ctrl+x/alt+x/ /app/superset/static/assets/sqllab.*.js \
&& gunicorn \
    --bind 0.0.0.0:8088 \
    --access-logfile - \
    --error-logfile - \
    --workers 1 \
    --worker-class gthread \
    --threads 20 \
    --timeout 60 \
    --limit-request-line 0 \
    --limit-request-field_size 0 \
    "superset.app:create_app()"
EOT
            ,
          ]
          env {
            name = "SECRET_KEY"
            value_from {
              secret_key_ref {
                key = "key"
                name = kubernetes_secret.key.metadata[0].name
              }
            }
          }
          env {
            name = "REDIS_HOST"
            value = var.redis_host
          }
          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                key = "pass"
                name = var.redis_secret_name
              }
            }
          }
          env {
            name = "POSTGRES_HOST"
            value = var.postgres_host
          }
          env {
            name = "POSTGRES_PORT"
            value = var.postgres_port
          }
          env {
            name = "POSTGRES_DB"
            value = var.postgres_db
          }
          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                key = "user"
                name = var.postgres_secret_name
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                key = "pass"
                name = var.postgres_secret_name
              }
            }
          }
          image = var.image_superset
          name = "superset"
          port {
            container_port = 8088
            name = "http"
          }
          resources {
            limits = {
              memory = var.mem_limit_server
            }
          }
          volume_mount {
            mount_path = "/app/pythonpath"
            name = "config"
            read_only = true
          }
        }
        container {
          command = [
            "/bin/sh",
            "-c",
            <<-EOT
. /app/pythonpath/superset_init.sh;
echo 'Done, sleeping forever';
touch /tmp/ready;
sleep infinity
EOT
            ,
          ]
          env {
            name = "ADMIN_USER"
            value_from {
              secret_key_ref {
                key = "user"
                name = kubernetes_secret.admin.metadata[0].name
              }
            }
          }
          env {
            name = "ADMIN_PASS"
            value_from {
              secret_key_ref {
                key = "pass"
                name = kubernetes_secret.admin.metadata[0].name
              }
            }
          }
          env {
            name = "SECRET_KEY"
            value_from {
              secret_key_ref {
                key = "key"
                name = kubernetes_secret.key.metadata[0].name
              }
            }
          }
          env {
            name = "REDIS_HOST"
            value = var.redis_host
          }
          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                key = "pass"
                name = var.redis_secret_name
              }
            }
          }
          env {
            name = "POSTGRES_HOST"
            value = var.postgres_host
          }
          env {
            name = "POSTGRES_PORT"
            value = var.postgres_port
          }
          env {
            name = "POSTGRES_DB"
            value = var.postgres_db
          }
          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                key = "user"
                name = var.postgres_secret_name
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                key = "pass"
                name = var.postgres_secret_name
              }
            }
          }
          image = var.image_superset
          name = "init"
          startup_probe {
            exec {
              command = [
                "/bin/sh",
                "-c",
                "if [ ! -f /tmp/ready ]; then exit 1; fi",
              ]
            }
            initial_delay_seconds = 10
            period_seconds = 30
            timeout_seconds = 90
          }
          volume_mount {
            mount_path = "/app/pythonpath"
            name = "config"
            read_only = true
          }
        }
        init_container {
          command = [
            "/bin/sh",
            "-c",
            "until nc -zv $POSTGRES_HOST $POSTGRES_PORT -w1; do echo waiting for postgres: $POSTGRES_HOST:$POSTGRES_PORT; sleep 1; done",
          ]
          env {
            name = "POSTGRES_HOST"
            value = var.postgres_host
          }
          env {
            name = "POSTGRES_PORT"
            value = var.postgres_port
          }
          image = var.image_busybox
          name = "wait-for-postgres"
        }
        node_selector = var.app_node_selector
        dynamic "toleration" {
          for_each = var.app_tolerations
          content {
            effect = toleration.value.effect
            key = toleration.value.key
            operator = toleration.value.operator
            value = toleration.value.value
          }
        }
        volume {
          config_map {
            name = kubernetes_config_map.superset.metadata[0].name
          }
          name = "config"
        }
      }
    }
  }
}
