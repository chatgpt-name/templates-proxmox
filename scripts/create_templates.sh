#!/bin/bash

# This script downloads Ubuntu cloud images and creates Proxmox templates
# for versions 18.04, 20.04, 22.04 and 24.04. It must be executed on the
# Proxmox server.

set -euo pipefail

# --- Configuration ---
STORAGE="local-lvm"        # Storage where disks will be imported
BRIDGE="vmbr0"             # Network bridge to attach VMs
RAM=2048                   # Memory for each template VM
CI_USER="root"            # cloud-init username
CI_PASS="root"            # cloud-init password

# Map of VMID to image details
declare -A IMAGES=(
  [1000]="18.04"
  [1001]="20.04"
  [1002]="22.04"
  [1003]="24.04"
)

BASE_URL="http://cloud-images.ubuntu.com/releases"

# --- Main loop ---
for VMID in "${!IMAGES[@]}"; do
    VERSION="${IMAGES[$VMID]}"
    IMAGE="ubuntu-${VERSION}-server-cloudimg-amd64.img"
    URL="$BASE_URL/${VERSION%%.*}/release/$IMAGE"
    VMNAME="u${VERSION%%.*}s-tpl"

    echo "=== Processing Ubuntu $VERSION (VMID $VMID) ==="
    if [[ ! -f /tmp/$IMAGE ]]; then
        echo "Downloading $IMAGE ..."
        wget -q -O "/tmp/$IMAGE" "$URL"
    fi

    echo "Creating VM ..."
    qm create "$VMID" \
        --memory "$RAM" \
        --net0 virtio,bridge="$BRIDGE" \
        --name "$VMNAME" \
        --scsihw virtio-scsi-pci

    virt-customize -a "/tmp/$IMAGE" --install qemu-guest-agent >/dev/null

    qm set "$VMID" --scsi0 "$STORAGE:0,import-from=/tmp/$IMAGE"
    qm set "$VMID" --ide2 "$STORAGE:cloudinit"
    qm set "$VMID" --boot order=scsi0
    qm set "$VMID" --serial0 socket --vga serial0
    qm set "$VMID" --ipconfig0 ip=dhcp
    qm set "$VMID" --agent enabled=1
    qm set "$VMID" -ciuser "$CI_USER"
    qm set "$VMID" -cipassword "$CI_PASS"
    qm template "$VMID"
    echo "Template $VMID ($VMNAME) ready."
    echo "------------------------------------"

done

echo "All templates created."
