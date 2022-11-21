resource "random_password" "superset_redis_pass" {
  length = 32
  special = false
}

resource "random_password" "superset_key" {
  length = 32
  special = false
}

resource "random_password" "superset_admin_pass" {
  count = var.superset_password == "" ? 1 : 0
  length = 32
  special = false
}

resource "kubernetes_secret" "superset_redis" {
  metadata {
    labels = {
      app = "superset-redis"
    }
    name = "superset-redis"
    namespace = "walden"
  }
  type = "Opaque"
  data = {
    pass = random_password.superset_redis_pass.result
  }
}

resource "kubernetes_secret" "superset_key" {
  metadata {
    labels = {
      app = "superset"
    }
    name = "superset-key"
    namespace = "walden"
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
    namespace = "walden"
  }
  type = "Opaque"
  data = {
    pass = var.superset_password == "" ? random_password.superset_admin_pass[0].result : var.superset_password
    user = var.superset_username
  }
}

resource "kubernetes_config_map" "superset" {
  metadata {
    labels = {
      app = "superset"
    }
    name = "superset"
    namespace = "walden"
  }
  data = {
    "superset_config.py" = file("configs/superset_config.py")
    "superset_copy_configs.sh" = file("configs/superset_copy_configs.sh")
    "superset_datasources.yaml" = templatefile(
      "configs/superset_datasources.yaml.template",
      {
        extra_datasources = var.superset_extra_datasources,
      }
    ),
    "superset_init.sh" = file("configs/superset_init.sh")
  }
}

resource "kubernetes_service" "superset_redis" {
  metadata {
    labels = {
      app = "superset-redis"
    }
    name = "superset-redis"
    namespace = "walden"
  }
  spec {
    port {
      name = "redis"
      port = 6379
      target_port = "redis"
    }
    selector = {
      app = "superset-redis"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_service" "superset" {
  metadata {
    labels = {
      app = "superset"
    }
    name = "superset"
    namespace = "walden"
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
    namespace = "walden"
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
            value = "superset-redis"
          }
          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                key = "pass"
                name = "superset-redis"
              }
            }
          }
          env {
            name = "POSTGRES_HOST"
            value = var.superset_postgres_host
          }
          env {
            name = "POSTGRES_PORT"
            value = var.superset_postgres_port
          }
          env {
            name = "POSTGRES_DB"
            value = var.superset_postgres_db
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
            value = var.superset_postgres_host
          }
          env {
            name = "POSTGRES_PORT"
            value = var.superset_postgres_port
          }
          image = var.image_busybox
          name = "wait-for-postgres"
        }
        node_selector = var.superset_scheduler_node_selector
        dynamic "toleration" {
          for_each = var.superset_scheduler_tolerations
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
    namespace = "walden"
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
            value = "superset-redis"
          }
          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                key = "pass"
                name = "superset-redis"
              }
            }
          }
          env {
            name = "POSTGRES_HOST"
            value = var.superset_postgres_host
          }
          env {
            name = "POSTGRES_PORT"
            value = var.superset_postgres_port
          }
          env {
            name = "POSTGRES_DB"
            value = var.superset_postgres_db
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
              memory = "1Gi"
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
            value = var.superset_postgres_host
          }
          env {
            name = "POSTGRES_PORT"
            value = var.superset_postgres_port
          }
          image = var.image_busybox
          name = "wait-for-postgres"
        }
        node_selector = var.superset_worker_node_selector
        dynamic "toleration" {
          for_each = var.superset_worker_tolerations
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
            name = "superset-custom"
            optional = true
          }
          name = "config-custom"
        }
        volume {
          name = "secrets-custom"
          secret {
            optional = true
            secret_name = "superset-custom"
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
    namespace = "walden"
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
            value = "superset-redis"
          }
          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                key = "pass"
                name = "superset-redis"
              }
            }
          }
          env {
            name = "POSTGRES_HOST"
            value = var.superset_postgres_host
          }
          env {
            name = "POSTGRES_PORT"
            value = var.superset_postgres_port
          }
          env {
            name = "POSTGRES_DB"
            value = var.superset_postgres_db
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
              memory = "512Mi"
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
            value = "superset-redis"
          }
          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                key = "pass"
                name = "superset-redis"
              }
            }
          }
          env {
            name = "POSTGRES_HOST"
            value = var.superset_postgres_host
          }
          env {
            name = "POSTGRES_PORT"
            value = var.superset_postgres_port
          }
          env {
            name = "POSTGRES_DB"
            value = var.superset_postgres_db
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
            value = var.superset_postgres_host
          }
          env {
            name = "POSTGRES_PORT"
            value = var.superset_postgres_port
          }
          image = var.image_busybox
          name = "wait-for-postgres"
        }
        node_selector = var.superset_app_node_selector
        dynamic "toleration" {
          for_each = var.superset_app_tolerations
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
            name = "superset-custom"
            optional = true
          }
          name = "config-custom"
        }
        volume {
          name = "secrets-custom"
          secret {
            optional = true
            secret_name = "superset-custom"
          }
        }
      }
    }
  }
}

resource "kubernetes_stateful_set" "superset_redis" {
  metadata {
    labels = {
      app = "superset-redis"
    }
    name = "superset-redis"
    namespace = "walden"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "superset-redis"
      }
    }
    service_name = "superset-redis"
    template {
      metadata {
        labels = {
          app = "superset-redis"
        }
      }
      spec {
        container {
          command = [
            "/bin/sh",
            "-c",
            "redis-server --bind 0.0.0.0 --requirepass $REDIS_PASSWORD --loglevel $LOG_LEVEL --dir /data --maxmemory 100mb --maxmemory-policy allkeys-lru --lazyfree-lazy-eviction yes --lazyfree-lazy-expire yes --io-threads 3",
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
                name = "superset-redis"
              }
            }
          }
          image = var.image_redis
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
            storage = "1Gi"
          }
        }
      }
    }
  }
}
