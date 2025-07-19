#!/bin/bash

# Upload local template disks and cloud-init images to a Proxmox server and
# create the VMs as templates. Files for each VMID should be stored in a
# directory named after the VMID.

set -euo pipefail

# --- Config ---
PROXMOX_HOST="192.168.1.110"
PROXMOX_USER="root"
STORAGE="local"
BRIDGE="vmbr0"
RAM=2048
MAKE_TEMPLATE=true
BASE_PATH="$(pwd)"

# Map VMIDs to names
declare -A VM_NAMES=(
  [1000]="u18s-tpl"
  [1001]="u20s-tpl"
  [1002]="u22s-tpl"
  [1003]="u24s-tpl"
)

# --- List templates available locally ---
echo "Available local templates:"
for DIR in "$BASE_PATH"/100*/; do
    VMID=$(basename "$DIR")
    echo "  [$VMID] - ${VM_NAMES[$VMID]:-unknown}"
done

read -p "Enter VMIDs to upload (separated by spaces): " -a SELECTED_VMS

# --- Main loop ---
for VMID in "${SELECTED_VMS[@]}"; do
    DIR="$BASE_PATH/$VMID"
    VMNAME="${VM_NAMES[$VMID]}"

    DISK_FILE="base-${VMID}-disk-0.raw"
    CLOUDINIT_FILE="vm-${VMID}-cloudinit.qcow2"

    if [[ ! -f "$DIR/$DISK_FILE" || ! -f "$DIR/$CLOUDINIT_FILE" ]]; then
        echo "Skipping $VMID: files missing";
        continue
    fi

    echo "Uploading files for $VMID ..."
    ssh "$PROXMOX_USER@$PROXMOX_HOST" "mkdir -p /var/lib/vz/images/$VMID"
    scp "$DIR/$DISK_FILE" "$PROXMOX_USER@$PROXMOX_HOST:/var/lib/vz/images/$VMID/"

    if ! ssh "$PROXMOX_USER@$PROXMOX_HOST" "test -f /var/lib/vz/images/$VMID/$CLOUDINIT_FILE"; then
        scp "$DIR/$CLOUDINIT_FILE" "$PROXMOX_USER@$PROXMOX_HOST:/var/lib/vz/images/$VMID/"
    fi

    ssh "$PROXMOX_USER@$PROXMOX_HOST" \
        "qm create $VMID --name $VMNAME --memory $RAM --net0 virtio,bridge=$BRIDGE"
    ssh "$PROXMOX_USER@$PROXMOX_HOST" \
        "qm importdisk $VMID /var/lib/vz/images/$VMID/$DISK_FILE $STORAGE"

    DISK_NAME=$(ssh "$PROXMOX_USER@$PROXMOX_HOST" "ls /var/lib/vz/images/$VMID | grep -o 'vm-${VMID}-disk-[0-9]*\\.raw' | head -n1")
    if [[ -z "$DISK_NAME" ]]; then
        echo "  Failed to detect imported disk for VMID $VMID";
        continue
    fi

    ssh "$PROXMOX_USER@$PROXMOX_HOST" \
        "qm set $VMID --scsihw virtio-scsi-pci --scsi0 $STORAGE:$VMID/$DISK_NAME"
    ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm set $VMID --ide2 $STORAGE:cloudinit"
    ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm set $VMID --boot order=scsi0"

    if [ "$MAKE_TEMPLATE" = true ]; then
        ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm template $VMID"
    fi

    echo "VMID $VMID uploaded and configured"
    echo "-------------------------------------"
done

echo "Selected templates uploaded."
