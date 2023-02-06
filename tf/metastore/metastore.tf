resource "kubernetes_config_map" "metastore" {
  metadata {
    labels = {
      app = var.name
    }
    name = var.name
    namespace = var.namespace
  }
  data = {
    "metastore-site.xml.template" = templatefile(
      "${path.module}/metastore-site.xml.template",
      {
        minio_host = var.minio_host,
        minio_port = var.minio_port,
        postgres_host = var.postgres_host,
        postgres_port = var.postgres_port,
        postgres_db = var.postgres_db,
      }
    )
  }
}

resource "kubernetes_service" "metastore" {
  metadata {
    labels = {
      app = var.name
    }
    name = var.name
    namespace = var.namespace
  }
  spec {
    port {
      name = "metastore"
      port = 9083
      target_port = "metastore"
    }
    selector = {
      app = var.name
    }
  }
}

resource "kubernetes_deployment" "metastore" {
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
    template {
      metadata {
        labels = {
          app = var.name
        }
      }
      spec {
        container {
          command = [
            "/bin/bash",
            "-c",
            # Init: Try -validate explicitly. If it works, then skip -initSchema.
            #   When schema already exists, -initSchema can fail with 'relation "BUCKETING_COLS" already exists'
            #   Turns out they forgot an "IF NOT EXISTS" in a "CREATE TABLE" lol
            <<-EOT
bash -c "echo -e \"$(cat /config/metastore-site.xml.template)\" > /opt/hive-metastore/conf/metastore-site.xml" &&
(/opt/hive-metastore/bin/schematool -validate -dbType postgres || /opt/hive-metastore/bin/schematool -initSchema -dbType postgres -ifNotExists) &&
/opt/hive-metastore/bin/start-metastore
EOT
            ,
          ]
          env {
            name = "METASTORE_PORT"
            value = "9083"
          }
          # use whatever user/pw is provided by the secret: user provides this when !postgres_internal
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
          # Provide credentials for metastore to access minio directly when creating tables.
          env {
            name = "AWS_ACCESS_KEY_ID"
            value_from {
              secret_key_ref {
                key = "user"
                name = var.minio_secret_name
              }
            }
          }
          env {
            name = "AWS_SECRET_KEY"
            value_from {
              secret_key_ref {
                key = "pass"
                name = var.minio_secret_name
              }
            }
          }
          image = var.image_metastore
          name = "metastore"
          port {
            container_port = 9083
            name = "metastore"
          }
          volume_mount {
            # Avoid collision with /opt/hive-metastore/conf/metastore-log4j2.properties
            mount_path = "/config"
            name = "config"
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
        # We only build an amd64 metastore image
        node_selector = {
          "kubernetes.io/arch" = "amd64"
        }
        restart_policy = "Always"
        volume {
          config_map {
            name = var.name
          }
          name = "config"
        }
      }
    }
  }
}
