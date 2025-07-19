#!/usr/bin/env bash

# Advanced template upload script for Proxmox
# This script automatically detects available template directories
# and uploads them to a remote Proxmox host with basic validations.

set -euo pipefail

# Use script directory as base unless BASE_PATH is set
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_PATH="${BASE_PATH:-$SCRIPT_DIR}"

# Default configuration - can be overridden with environment variables
PROXMOX_HOST="${PROXMOX_HOST:-}"
PROXMOX_USER="${PROXMOX_USER:-root}"
STORAGE="${STORAGE:-local}"
BRIDGE="${BRIDGE:-vmbr0}"
RAM="${RAM:-2048}"
MAKE_TEMPLATE="${MAKE_TEMPLATE:-true}"

# Optional mapping of VMID to human readable name
declare -A VM_NAMES=(
  [1000]="u18s-tpl"
  [1001]="u20s-tpl"
  [1002]="u22s-tpl"
  [1003]="u24s-tpl"
)

# --- Dependency checks ---
for cmd in ssh scp; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' is required but not installed." >&2
    exit 1
  fi
done

# --- Obtain host if not predefined ---
if [[ -z "$PROXMOX_HOST" ]]; then
  read -rp "Enter Proxmox host: " PROXMOX_HOST
fi

# Verify we can reach the host
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$PROXMOX_USER@$PROXMOX_HOST" "true" 2>/dev/null; then
  echo "Unable to connect to $PROXMOX_HOST as $PROXMOX_USER" >&2
  exit 1
fi

# --- List local templates ---
AVAILABLE=()
echo "Available local templates:"
for DIR in "$BASE_PATH"/*/; do
  [[ -d "$DIR" ]] || continue
  VMID="$(basename "$DIR")"
  [[ $VMID =~ ^[0-9]+$ ]] || continue
  DISK_FILE="$DIR/base-${VMID}-disk-0.raw"
  CI_FILE="$DIR/vm-${VMID}-cloudinit.qcow2"
  if [[ -f "$DISK_FILE" && -f "$CI_FILE" ]]; then
    echo "  [$VMID] - ${VM_NAMES[$VMID]:-unknown}"
    AVAILABLE+=("$VMID")
  fi
done

if [[ ${#AVAILABLE[@]} -eq 0 ]]; then
  echo "No template directories found in $BASE_PATH" >&2
  exit 1
fi

read -rp "Enter VMIDs to upload (separated by spaces): " -a SELECTED_VMS

# --- Upload loop ---
for VMID in "${SELECTED_VMS[@]}"; do
  DIR="$BASE_PATH/$VMID"
  DISK_FILE="base-${VMID}-disk-0.raw"
  CI_FILE="vm-${VMID}-cloudinit.qcow2"

  if [[ ! -f "$DIR/$DISK_FILE" || ! -f "$DIR/$CI_FILE" ]]; then
    echo "Skipping $VMID: required files missing" >&2
    continue
  fi

  # Skip if VM already exists on remote host
  if ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm status $VMID" &>/dev/null; then
    echo "VMID $VMID already exists on $PROXMOX_HOST, skipping"
    continue
  fi

  echo "Uploading $VMID ..."
  ssh "$PROXMOX_USER@$PROXMOX_HOST" "mkdir -p /var/lib/vz/images/$VMID"
  scp "$DIR/$DISK_FILE" "$PROXMOX_USER@$PROXMOX_HOST:/var/lib/vz/images/$VMID/"
  if ! ssh "$PROXMOX_USER@$PROXMOX_HOST" "test -f /var/lib/vz/images/$VMID/$CI_FILE"; then
    scp "$DIR/$CI_FILE" "$PROXMOX_USER@$PROXMOX_HOST:/var/lib/vz/images/$VMID/"
  fi

  ssh "$PROXMOX_USER@$PROXMOX_HOST" \
    "qm create $VMID --name ${VM_NAMES[$VMID]:-template-$VMID} --memory $RAM --net0 virtio,bridge=$BRIDGE"

  ssh "$PROXMOX_USER@$PROXMOX_HOST" \
    "qm importdisk $VMID /var/lib/vz/images/$VMID/$DISK_FILE $STORAGE"

  DISK_NAME=$(ssh "$PROXMOX_USER@$PROXMOX_HOST" "ls /var/lib/vz/images/$VMID | grep -o 'vm-${VMID}-disk-[0-9]*\\.raw' | head -n1")
  if [[ -z "$DISK_NAME" ]]; then
    echo "Failed to detect imported disk for VMID $VMID" >&2
    continue
  fi

  ssh "$PROXMOX_USER@$PROXMOX_HOST" \
    "qm set $VMID --scsihw virtio-scsi-pci --scsi0 $STORAGE:$VMID/$DISK_NAME"
  ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm set $VMID --ide2 $STORAGE:cloudinit --boot order=scsi0"

  if [[ "$MAKE_TEMPLATE" == "true" ]]; then
    ssh "$PROXMOX_USER@$PROXMOX_HOST" "qm template $VMID"
  fi

  echo "VMID $VMID uploaded successfully"
  echo "-------------------------------------"
done

echo "Selected templates uploaded."
