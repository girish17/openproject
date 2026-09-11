#!/bin/bash

# Run a command inside the openproject/ci:v1 test container.
#
# The Jenkins agent is itself a Docker container: its workspace is at
# /var/jenkins_home/workspace/... (bind-mounted from /var/lib/jenkins on the
# host). Docker bind mounts are resolved against the host filesystem, so paths
# must use the host-visible location (/var/lib/jenkins/...) rather than relying
# on relative paths in docker-compose.ci.yml.
#
# Usage: CI_JOBS=n scripts/ci/ci-run.sh <command...>

set -eo pipefail

if ! docker image inspect openproject/ci:v1 >/dev/null 2>&1; then
  echo "openproject/ci:v1 not found - building it (first run)."
  export DOCKER_BUILDKIT=1
  export APP_USER_UID="$(id -u)"
  export APP_USER_GID="$(id -g)"
  export RUBY_VERSION="$(cat .ruby-version)"
  docker compose -f docker-compose.ci.yml build app
fi

WS_HOST="$(echo "$PWD" | sed 's|^/var/jenkins_home|/var/lib/jenkins|')"
export LOCAL_CACHE_PATH="${WS_HOST}/cache"

# cache lives in the checked-out workspace (host path used for the docker bind
# mount, container-relative path for creating it)
mkdir -p "${PWD}/cache"/{bundle,node/.npm,node/node_modules,node/frontend/node_modules,angular,runtime-logs}

exec docker run --rm \
  -e CI_JOBS \
  -e RSPEC_RETRY_RETRY_COUNT="${CI_RETRY_COUNT:-4}" \
  --tmpfs /tmp \
  -v "$WS_HOST:/app" \
  -v "$LOCAL_CACHE_PATH/node/.npm:/app/.npm" \
  -v "$LOCAL_CACHE_PATH/node/node_modules:/app/node_modules" \
  -v "$LOCAL_CACHE_PATH/node/frontend/node_modules:/app/frontend/node_modules" \
  -v "$LOCAL_CACHE_PATH/bundle:/usr/local/bundle" \
  -v "$LOCAL_CACHE_PATH/angular:/app/frontend/.angular/cache" \
  openproject/ci:v1 "$@"