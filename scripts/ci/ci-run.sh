#!/bin/bash

# Run a command inside the openproject/ci:v1 test container.
#
# The Jenkins agent is itself a Docker container: its workspace is at
# /var/jenkins_home/workspace/... (bind-mounted from /var/lib/jenkins on the
# host). Docker bind mounts are resolved against the host filesystem, so paths
# must use the host-visible location (/var/lib/jenkins/...).
#
# Notes:
# - Persistent caches (bundler gems, npm) live OUTSIDE the workspace tree so
#   the per-build `git clean -fdx` never wipes or conflicts with them.
# - Never create docker bind mounts whose target directories live inside the
#   checkout: docker creates missing targets as root, which breaks the next
#   checkout's git clean. Angular's cache dir therefore uses NG_CACHE_PATH
#   (tmpfs) instead of a volume.
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

# Persistent host-side cache locations (kept outside the workspace so the
# per-build `git clean -fdx` does not touch them).
CI_CACHE_HOST=/var/lib/jenkins/yojana-ci-cache
conf_dir="${PWD}/.ci-cache"          # container-visible (workspace) for scratch files
mkdir -p "$conf_dir"
conf_dir_host="$WS_HOST/.ci-cache"   # same dir as seen by the docker daemon (host FS)

# Create + own the host cache dirs through the daemon (the script itself can
# only see /var/jenkins_home/..., not /var/lib/jenkins).
docker run --rm -u root \
  -v "$CI_CACHE_HOST:/ci-cache" \
  openproject/ci:v1 bash -c \
  'mkdir -p /ci-cache/bundle /ci-cache/npm && chown -R 1000:1000 /ci-cache'

# Postgres conf tuned for the 2-vCPU/8GB CI host. The default docker/ci conf
# targets 32GB/16-core runners and cannot map its shared memory here.
cat > "$conf_dir/postgresql.conf" <<EOF
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
  -e npm_config_cache=/usr/local/npm-cache \
  -e NG_CACHE_PATH=/tmp/ng-cache \
  --tmpfs /tmp \
  -v "$WS_HOST:/app" \
  -v "$conf_dir_host/postgresql.conf:/app/docker/ci/postgresql.conf" \
  -v "$CI_CACHE_HOST/bundle:/usr/local/bundle" \
  -v "$CI_CACHE_HOST/npm:/usr/local/npm-cache" \
  openproject/ci:v1 "$@"