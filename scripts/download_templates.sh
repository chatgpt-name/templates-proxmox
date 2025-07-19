#!/bin/bash

# Download template raw disks and cloud-init images from a Proxmox server
# to the local machine. Each template will be placed in a directory named
# after its VMID.

set -euo pipefail

# --- Config ---
PROXMOX_HOST="192.168.1.110"
PROXMOX_USER="root"
BASE_PATH="$(pwd)"

# Map VMIDs to human readable names (optional)
declare -A VM_NAMES=(
  [1000]="u18s-tpl"
  [1001]="u20s-tpl"
  [1002]="u22s-tpl"
  [1003]="u24s-tpl"
)

# --- Prompt user ---
echo "Available templates on Proxmox:"
for VMID in "${!VM_NAMES[@]}"; do
    echo "  [$VMID] - ${VM_NAMES[$VMID]}"
    done

read -p "Enter VMIDs to download (separated by spaces): " -a SELECTED_VMS

# --- Download loop ---
for VMID in "${SELECTED_VMS[@]}"; do
    DIR="$BASE_PATH/$VMID"
    mkdir -p "$DIR"

    echo "Fetching files for VMID $VMID ..."
    DISK_FILE=$(ssh "$PROXMOX_USER@$PROXMOX_HOST" "ls /var/lib/vz/images/$VMID | grep -o 'base-$VMID-disk-0\\.raw' || true")
    CLOUDINIT_FILE="vm-${VMID}-cloudinit.qcow2"

    if [[ -z "$DISK_FILE" ]]; then
        echo "  Disk file for $VMID not found on server, skipping.";
        continue
    fi

    scp "$PROXMOX_USER@$PROXMOX_HOST:/var/lib/vz/images/$VMID/$DISK_FILE" "$DIR/"
    if ssh "$PROXMOX_USER@$PROXMOX_HOST" "test -f /var/lib/vz/images/$VMID/$CLOUDINIT_FILE"; then
        scp "$PROXMOX_USER@$PROXMOX_HOST:/var/lib/vz/images/$VMID/$CLOUDINIT_FILE" "$DIR/"
    fi

    echo "  Downloaded $VMID to $DIR"
done

echo "Done." 
