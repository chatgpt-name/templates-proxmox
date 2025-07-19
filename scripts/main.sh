#!/usr/bin/env bash

# Orchestrate initial template setup with Proxmox.
# - Ensures scripts are present on the Proxmox host.
# - Runs create_templates.sh remotely if templates do not exist.
# - Downloads templates locally.
# - Optionally uploads them back after user confirmation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXMOX_HOST="${PROXMOX_HOST:-}"
PROXMOX_USER="${PROXMOX_USER:-root}"
REMOTE_PATH="${REMOTE_PATH:-~/templates-proxmox}"

for cmd in ssh scp; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' is required but not installed." >&2
    exit 1
  fi
done

if [[ -z "$PROXMOX_HOST" ]]; then
  read -rp "Enter Proxmox host: " PROXMOX_HOST
fi

# Ensure destination directory exists
ssh "$PROXMOX_USER@$PROXMOX_HOST" "mkdir -p $REMOTE_PATH/scripts"

# Upload local scripts if missing on remote
if ! ssh "$PROXMOX_USER@$PROXMOX_HOST" "test -f $REMOTE_PATH/scripts/create_templates.sh"; then
  echo "Uploading scripts to $PROXMOX_HOST ..."
  scp "$SCRIPT_DIR"/*.sh "$PROXMOX_USER@$PROXMOX_HOST:$REMOTE_PATH/scripts/"
fi

# Run create_templates.sh remotely
echo "Creating templates on $PROXMOX_HOST ..."
ssh "$PROXMOX_USER@$PROXMOX_HOST" "bash $REMOTE_PATH/scripts/create_templates.sh"

# Download templates back to local machine
echo "Downloading templates to local machine ..."
PROXMOX_HOST="$PROXMOX_HOST" PROXMOX_USER="$PROXMOX_USER" "$SCRIPT_DIR/download_templates.sh"

# Ask user about uploading templates
read -rp "Upload templates back to Proxmox now? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
  PROXMOX_HOST="$PROXMOX_HOST" PROXMOX_USER="$PROXMOX_USER" "$SCRIPT_DIR/upload_templates.sh"
fi

echo "Done."
