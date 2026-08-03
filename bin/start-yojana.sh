#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ ! -f "$PROJECT_ROOT/.env" ]; then
  echo "ERROR: .env not found. Create it with your Azure/VM config."
  exit 1
fi
source "$PROJECT_ROOT/.env"

: "${AZURE_SUBSCRIPTION:?Must be set in .env}"
: "${AZURE_RG:?Must be set in .env}"
: "${VM_NAME:?Must be set in .env}"
: "${HOSTNAME:?Must be set in .env}"
: "${CONTAINER_NAME:?Must be set in .env}"
: "${IMAGE_NAME:?Must be set in .env}"
: "${PGDATA_HOST:?Must be set in .env}"
: "${SECRET_FILE:?Must be set in .env}"
: "${VOLUME_NAME:?Must be set in .env}"
: "${BACKUP_DIR:?Must be set in .env}"

ssh_vm() {
  # `az ssh vm` masks the remote exit code (always returns 0), so append a
  # sentinel on the remote side and use it to derive the real exit status.
  local out rc
  out=$(az ssh vm --subscription "$AZURE_SUBSCRIPTION" \
    --resource-group "$AZURE_RG" --name "$VM_NAME" -- "$*; echo \"__RC=\$?\"" 2>/dev/null || true)
  rc=$(printf '%s\n' "$out" | sed -n 's/^__RC=//p' | tail -1)
  printf '%s\n' "$out" | sed '$d'
  [ "${rc:-1}" = "0" ]
}

echo "=========================================="
echo " Yojana Production Restart"
echo "=========================================="

echo ""
echo "=== 1. Start VM ==="
echo "Starting VM '$VM_NAME'..."
az vm start --subscription "$AZURE_SUBSCRIPTION" \
  --resource-group "$AZURE_RG" --name "$VM_NAME"
echo "VM started."

echo ""
echo "=== 2. Backup volumes ==="
echo "Creating backup directory and backing up attachments volume..."
ssh_vm \
  "sudo mkdir -p $BACKUP_DIR && \
   sudo docker run --rm -v $VOLUME_NAME:/data -v $BACKUP_DIR:/backup alpine \
     tar czf /backup/attachments-$(date +%Y%m%d-%H%M%S).tar.gz -C /data ." \
  || echo "WARNING: Volume backup failed (non-fatal)"

echo "Backing up pgdata (file-level, PostgreSQL is stopped so consistent)..."
ssh_vm \
  "sudo docker run --rm -v $PGDATA_HOST:/pgdata -v $BACKUP_DIR:/backup alpine \
     tar czf /backup/pgdata-$(date +%Y%m%d-%H%M%S).tar.gz -C /pgdata ." \
  || echo "WARNING: pgdata backup failed (non-fatal)"
echo "Backups saved to $BACKUP_DIR on VM."

echo ""
echo "=== 3. Start container ==="
if ssh_vm "sudo docker start $CONTAINER_NAME"; then
  echo "Existing container '$CONTAINER_NAME' started successfully."
else
  echo "Container '$CONTAINER_NAME' not found. Creating from image..."
  SECRET_VAL=$(ssh_vm "sudo cat $SECRET_FILE")
  ssh_vm \
    "sudo docker run -d \
      --name $CONTAINER_NAME \
      -p 8080:80 \
      -e SECRET_KEY_BASE='$SECRET_VAL' \
      -e OPENPROJECT_HOST__NAME='$HOSTNAME' \
      -v $PGDATA_HOST:/var/openproject/pgdata \
      -v $VOLUME_NAME:/var/openproject/assets \
      $IMAGE_NAME"
  echo "Container created. Applying hotfixes..."
  sleep 15
  # Apply definition.rb hotfix (organization_name setting)
  base64 < "$PROJECT_ROOT/config/constants/settings/definition.rb" | \
    ssh_vm \
      "cat | base64 -d | sudo docker exec -i $CONTAINER_NAME bash -c \
        'cat > /app/config/constants/settings/definition.rb'"
  echo "  definition.rb applied."
  # Apply en.yml hotfix (translation key)
  ssh_vm \
    "sudo docker exec $CONTAINER_NAME bash -c \
      'grep -q setting_organization_name /app/config/locales/en.yml || \
       echo \"  setting_organization_name: \\\"Organization name\\\"\" \
       >> /app/config/locales/en.yml'"
  echo "  en.yml translation applied."
  # Graceful Puma restart to pick up changes
  PUMAPID=$(ssh_vm "sudo docker exec $CONTAINER_NAME cat /app/tmp/pids/server.pid 2>/dev/null" || true)
  if [ -n "$PUMAPID" ]; then
    ssh_vm "sudo docker exec $CONTAINER_NAME kill -USR1 $PUMAPID" || true
    echo "  Puma restarted gracefully (USR1)."
  fi
  echo "Hotfixes applied."
fi

echo ""
echo "=== 4. Wait for readiness ==="
echo "Waiting 45 seconds for services to start..."
sleep 45

echo ""
echo "=== 5. Verify ==="
HTTP_CODE=$(ssh_vm "curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: $HOSTNAME' http://localhost:8080" 2>/dev/null | tr -d '[:space:]' || echo "000")
echo "HTTP status: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
  echo "SUCCESS: Yojana is running at https://$HOSTNAME"
else
  echo "WARNING: HTTP status $HTTP_CODE. Check manually:"
  echo "  az ssh vm --subscription $AZURE_SUBSCRIPTION --resource-group $AZURE_RG --name $VM_NAME"
  echo "  sudo docker logs $CONTAINER_NAME --tail 50"
fi

echo ""
echo "=== 6. Database backup (post-start) ==="
ssh_vm \
  "sudo docker exec -u postgres $CONTAINER_NAME pg_dump -U postgres openproject 2>/dev/null \
    | sudo tee $BACKUP_DIR/db-$(date +%Y%m%d-%H%M%S).sql >/dev/null && sudo chown azureuser:azureuser $BACKUP_DIR/db-*.sql" \
  || echo "WARNING: DB backup failed (non-fatal. Container may still be starting.)"

echo ""
echo "Done. Yojana should be back online at https://$HOSTNAME"
