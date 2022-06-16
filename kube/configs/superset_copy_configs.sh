#!/bin/sh

# This script sets up superset_config.py including any user customizations.
# Broken out into a standalone script file to be executed by both superset and superset-worker on startup.

# Expected volumes/mounts:
# - superset-config ConfigMap to /ro/
# - superset-config-custom ConfigMap to /custom/
# - EmptyDir to /out/

# BEFORE:
#   /ro/superset_copy_configs.sh (this script)
#   /ro/superset_config.py (default config)
#   /custom/superset_config.py (user config to append, if present)
#   /custom/* (other user files)
#   /secrets/* (any user secrets)
# AFTER:
#   /out/superset_config.py (default + user configs, appended)
#   /out/* (all provided+user files, with user files taking precedence)

echo "Copying default configs/scripts from /ro"
cp -aLv /ro/* /out/

# Users may completely override ro configs (except for superset_config.py),
# or can just make additive changes via e.g. the superset_init_custom.sh hook.
echo "Copying custom configs/scripts from /custom (superset-custom ConfigMap)"
cp -aLv /custom/* /out/

# Users may want to e.g. have OAuth/OIDC content in a separate Secret.
echo "Copying custom secrets from /secrets (superset-custom Secret)"
cp -aLv /secrets/* /out/

# Special case for superset_config.py: Concatenate the two files
if [ -f "/custom/superset_config.py" ]; then
    echo "Using concatenated /ro/superset_config.py + /custom/superset_config.py"
    cat /ro/superset_config.py /custom/superset_config.py > /out/superset_config.py
fi

echo "Superset config:"
ls -l /out/
