#!/bin/bash
set -euxo pipefail

DOCKER=${DOCKER:-0}

if [ -f config/frontend_assets.manifest.json ]; then
  echo "Assets have already been precompiled. Reusing."
else
  echo "Assets need to be compiled"

  JOBS=4 npm install

  SECRET_KEY_BASE="$(openssl rand -hex 64)" RAILS_ENV=production DATABASE_URL=nulldb://db \
    bin/rails openproject:plugins:register_frontend assets:precompile

  if [ "$DOCKER" = "1" ]; then
    # Disable swap
    if [ -f /swapfile ]; then
      swapoff /swapfile
      rm -f /swapfile
    fi

    rm -rf /tmp/nulldb
    # Remove sprockets cache
    rm -rf "$APP_PATH/tmp/cache/assets"
    # Remove node_modules and entire frontend
    rm -rf "$APP_PATH/node_modules/" "$APP_PATH/frontend/node_modules/"
    # Remove angular cache
    rm -rf "$APP_PATH/frontend/.angular"
    # Clean cache in root
    rm -rf /root/.npm
    rm -f "$APP_PATH/log/production.log"
  fi
fi