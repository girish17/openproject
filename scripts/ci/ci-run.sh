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

# Postgres conf tuned for the 2-vCPU/8GB CI host. The default docker/ci conf
# targets 32GB/16-core runners and cannot map its shared memory here.
cat > "$LOCAL_CACHE_PATH/postgresql.conf" <<EOF
fsync = off
synchronous_commit = off
checkpoint_timeout = 30min
full_page_writes = off
deadlock_timeout = 20s
autovacuum = off
listen_addresses = '127.0.0.1'
unix_socket_directories = '/tmp'
max_connections = 30
shared_buffers = 128MB
effective_cache_size = 512MB
maintenance_work_mem = 128MB
wal_buffers = 4MB
max_parallel_workers_per_gather = 2
max_parallel_workers = 2
max_parallel_maintenance_workers = 2
EOF

exec docker run --rm \
  -e CI_JOBS \
  -e RSPEC_RETRY_RETRY_COUNT="${CI_RETRY_COUNT:-4}" \
  --tmpfs /tmp \
  -v "$WS_HOST:/app" \
  -v "$LOCAL_CACHE_PATH/postgresql.conf:/app/docker/ci/postgresql.conf" \
  -v "$LOCAL_CACHE_PATH/node/.npm:/app/.npm" \
  -v "$LOCAL_CACHE_PATH/node/node_modules:/app/node_modules" \
  -v "$LOCAL_CACHE_PATH/node/frontend/node_modules:/app/frontend/node_modules" \
  -v "$LOCAL_CACHE_PATH/bundle:/usr/local/bundle" \
  -v "$LOCAL_CACHE_PATH/angular:/app/frontend/.angular/cache" \
  openproject/ci:v1 "$@"