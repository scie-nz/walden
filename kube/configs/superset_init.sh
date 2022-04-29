#!/bin/sh
set -eu

echo "Upgrading DB schema..."
superset db upgrade

echo "Initializing roles..."
superset init

if [ -n "$ADMIN_USER" -a -n "$ADMIN_PASS" ]; then
    echo "Creating admin user '${ADMIN_USER}'..."
    superset fab create-admin \
             --username "${ADMIN_USER}" \
             --firstname Superset \
             --lastname Admin \
             --email admin@superset.com \
             --password "${ADMIN_PASS}" \
        || true
fi

if [ -f "/app/pythonpath/superset_datasources.yaml" ]; then
  echo "Importing database connections..."
  superset import_datasources -p /app/pythonpath/superset_datasources.yaml
fi

# Custom hook for user to execute their own superset CLI commands
if [ -f "/app/pythonpath/superset_init_custom.sh" ]; then
  echo "Executing user superset_init_custom.sh"
  /bin/sh /app/pythonpath/superset_init_custom.sh
else
  echo "No superset_init_custom.sh found, skipping custom user init"
fi
