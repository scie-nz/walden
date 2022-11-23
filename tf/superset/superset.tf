resource "random_password" "superset_key" {
  length = 32
  special = false
}

resource "random_password" "superset_admin_pass" {
  count = var.password == "" ? 1 : 0
  length = 32
  special = false
}

resource "kubernetes_secret" "superset_key" {
  metadata {
    labels = {
      app = "superset"
    }
    name = "superset-key"
    namespace = var.namespace
  }
  type = "Opaque"
  data = {
    key = random_password.superset_key.result
  }
}

resource "kubernetes_secret" "superset_admin" {
  metadata {
    labels = {
      app = "superset"
    }
    name = "superset-admin"
    namespace = var.namespace
  }
  type = "Opaque"
  data = {
    pass = var.password == "" ? random_password.superset_admin_pass[0].result : var.password
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
    "superset_copy_configs.sh" = file("${path.module}/superset_copy_configs.sh")
    "superset_datasources.yaml" = templatefile(
      "${path.module}/superset_datasources.yaml.template",
      {
        extra_datasources = var.extra_datasources,
      }
    ),
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

resource "kubernetes_deployment" "superset_scheduler" {
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
                name = "superset-key"
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
          env_from {
            # Custom environment variables to include in the superset nodes.
            # This may be used for customizing configuration, e.g. SMTP auth
            secret_ref {
              name = "superset-env-extra"
              optional = true
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
            "/ro/superset_copy_configs.sh",
          ]
          image = var.image_busybox
          name = "init-config"
          volume_mount {
            mount_path = "/out"
            name = "config"
          }
          volume_mount {
            mount_path = "/ro"
            name = "config-ro"
            read_only = true
          }
          volume_mount {
            mount_path = "/custom"
            name = "config-custom"
            read_only = true
          }
          volume_mount {
            mount_path = "/secrets"
            name = "secrets-custom"
            read_only = true
          }
        }
        init_container {
          command = [
            "/bin/sh",
            "-c",
            "until nc -zv $POSTGRES_HOST $POSTGRES_PORT -w1; do echo waiting for postgres: $${POSTGRES_HOST}:$${POSTGRES_PORT}; sleep 1; done",
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
            effect = toleration.effect
            key = toleration.key
            operator = toleration.operator
            value = toleration.value
          }
        }
        volume {
          empty_dir {}
          name = "config"
        }
        volume {
          config_map {
            name = "superset"
          }
          name = "config-ro"
        }
        volume {
          config_map {
            name = "superset-extra"
            optional = true
          }
          name = "config-custom"
        }
        volume {
          name = "secrets-custom"
          secret {
            optional = true
            secret_name = "superset-extra"
          }
        }
      }
    }
  }
}

resource "kubernetes_deployment" "superset_worker" {
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
                name = "superset-key"
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
          env_from {
            # Custom environment variables to include in the superset nodes.
            # This may be used for customizing configuration, e.g. SMTP auth
            secret_ref {
              name = "superset-env-extra"
              optional = true
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
            "/ro/superset_copy_configs.sh",
          ]
          image = var.image_busybox
          name = "init-config"
          volume_mount {
            mount_path = "/out"
            name = "config"
          }
          volume_mount {
            mount_path = "/ro"
            name = "config-ro"
            read_only = true
          }
          volume_mount {
            mount_path = "/custom"
            name = "config-custom"
            read_only = true
          }
          volume_mount {
            mount_path = "/secrets"
            name = "secrets-custom"
            read_only = true
          }
        }
        init_container {
          command = [
            "/bin/sh",
            "-c",
            "until nc -zv $POSTGRES_HOST $POSTGRES_PORT -w1; do echo waiting for postgres: $${POSTGRES_HOST}:$${POSTGRES_PORT}; sleep 1; done",
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
            effect = toleration.effect
            key = toleration.key
            operator = toleration.operator
            value = toleration.value
          }
        }
        volume {
          empty_dir {}
          name = "config"
        }
        volume {
          config_map {
            name = "superset"
          }
          name = "config-ro"
        }
        volume {
          config_map {
            name = "superset-extra"
            optional = true
          }
          name = "config-custom"
        }
        volume {
          name = "secrets-custom"
          secret {
            optional = true
            secret_name = "superset-extra"
          }
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
                name = "superset-key"
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
          env_from {
            # Custom environment variables to include in the superset nodes.
            # This may be used for customizing configuration, e.g. SMTP auth
            secret_ref {
              name = "superset-env-extra"
              optional = true
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
                name = "superset-admin"
              }
            }
          }
          env {
            name = "ADMIN_PASS"
            value_from {
              secret_key_ref {
                key = "pass"
                name = "superset-admin"
              }
            }
          }
          env {
            name = "SECRET_KEY"
            value_from {
              secret_key_ref {
                key = "key"
                name = "superset-key"
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
          env_from {
            # Custom environment variables to include in the superset nodes.
            # This may be used for customizing configuration, e.g. SMTP auth
            secret_ref {
              name = "superset-env-extra"
              optional = true
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
            "/ro/superset_copy_configs.sh",
          ]
          image = var.image_busybox
          name = "init-config"
          volume_mount {
            mount_path = "/out"
            name = "config"
          }
          volume_mount {
            mount_path = "/ro"
            name = "config-ro"
            read_only = true
          }
          volume_mount {
            mount_path = "/custom"
            name = "config-custom"
            read_only = true
          }
          volume_mount {
            mount_path = "/secrets"
            name = "secrets-custom"
            read_only = true
          }
        }
        init_container {
          command = [
            "/bin/sh",
            "-c",
            "until nc -zv $POSTGRES_HOST $POSTGRES_PORT -w1; do echo waiting for postgres: $${POSTGRES_HOST}:$${POSTGRES_PORT}; sleep 1; done",
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
            effect = toleration.effect
            key = toleration.key
            operator = toleration.operator
            value = toleration.value
          }
        }
        volume {
          empty_dir {}
          name = "config"
        }
        volume {
          config_map {
            name = "superset"
          }
          name = "config-ro"
        }
        volume {
          config_map {
            name = "superset-extra"
            optional = true
          }
          name = "config-custom"
        }
        volume {
          name = "secrets-custom"
          secret {
            optional = true
            secret_name = "superset-extra"
          }
        }
      }
    }
  }
}
