# Azure VM Deployment Guide for Yojana

This guide documents how to build and deploy the Yojana Docker image to Azure VM.

## Overview

- **Image**: `girish17/yojana:dev-azure`
- **Type**: All-in-one (includes PostgreSQL, Apache, Memcached)
- **Platform**: x86/amd64 (linux/amd64)
- **Azure VM**: element in AzureQuantum resource group
- **Domain**: yojana.girishm.info

## Prerequisites

- Docker Desktop (for building)
- Azure CLI installed
- SSH access to Azure VM

## Build and Deploy

### Step 1: Build the Docker Image

From the project root:

```bash
# Build for x86/amd64 and push to Docker Hub
./bin/build-docker-azure --push --build-type all-in-one
```

This builds the image targeting `linux/amd64` platform and pushes to `girish17/yojana:dev-azure`.

### Step 2: SSH into Azure VM

```bash
# Using Azure CLI
az login
az ssh vm --ip 127.0.0.1 --subscription <subscription-id>
```

Or use the public IP: `127.0.0.1`

### Step 3: Pull and Deploy

On the Azure VM:

```bash
# Stop and remove existing container
docker rm -f openproject

# Pull latest image
docker pull girish17/yojana:dev-azure

# Start new container
docker run -d --name openproject \
  -p 8080:80 \
  -e SECRET_KEY_BASE="$(openssl rand -hex 64)" \
  girish17/yojana:dev-azure

# Check logs
docker logs openproject
```

### Step 4: Configure Caddy Reverse Proxy

The Caddy server handles HTTPS and forwards requests to the Docker container.

Edit the Caddyfile (usually at `/etc/caddy/Caddyfile` or `/opt/caddy/Caddyfile`):

```
yojana.girishm.info {
    reverse_proxy localhost:8080
}
```

Reload Caddy:

```bash
sudo systemctl reload caddy
```

## Troubleshooting

### Check Container Status

```bash
docker ps
docker logs openproject
```

### Container keeps restarting

```bash
docker logs openproject | tail -50
```

### Check if port 8080 is listening

```bash
sudo ss -tlnp | grep 8080
```

### Database issues

The all-in-one image includes PostgreSQL. If migrations are pending:

```bash
# Run migrations inside container
docker exec openproject rake db:migrate
```

### Clean up Docker (if disk space issues)

```bash
docker system prune -af
docker rm -f $(docker ps -aq)
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SECRET_KEY_BASE` | Rails secret key | Yes |
| `DATABASE_URL` | External PostgreSQL (leave empty for internal) | No |
| `PGDATA` | PostgreSQL data directory | Auto |
| `OPENPROJECT_RAILS__CACHE__STORE` | Cache backend (memcache/file_store) | Auto |

## Rollback

To rollback to a previous version:

```bash
# List available tags (if using tags)
docker images girish17/yojana

# Pull specific version
docker pull girish17/yojana:<tag>

# Redeploy
docker rm -f openproject
docker run -d --name openproject \
  -p 8080:80 \
  -e SECRET_KEY_BASE="your-secret-key" \
  girish17/yojana:<tag>
```

## Automated CI/CD (Future Enhancement)

To automate deployments:

1. Set up GitHub Actions workflow to build and push on main/dev branch
2. Use Azure Container Registry (ACR) instead of Docker Hub
3. Configure webhooks to trigger deployments on Azure VM

## Quick Reference

### Local Build Commands
```bash
# Build only (no push)
./bin/build-docker-azure

# Build and push
./bin/build-docker-azure --push

# Build specific type (slim or all-in-one)
./bin/build-docker-azure --push --build-type all-in-one
./bin/build-docker-azure --push --build-type slim
```

### Azure VM Commands
```bash
# Start
docker start openproject

# Stop
docker stop openproject

# Restart
docker restart openproject

# View logs
docker logs -f openproject

# Execute command in container
docker exec -it openproject /bin/bash

# Run rake task
docker exec openproject rake db:migrate
```

### Check Application Health
```bash
# Inside container
docker exec openproject rake db:migrate:status

# Check processes
docker exec openproject ps aux
```
