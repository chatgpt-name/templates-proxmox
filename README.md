# Proxmox Template Scripts

This repository contains simple bash utilities for working with Proxmox VM templates.

* `scripts/create_templates.sh` – download Ubuntu cloud images and create template VMs directly on the Proxmox host.
* `scripts/download_templates.sh` – fetch existing template disks from a Proxmox server to your local machine.
* `scripts/upload_templates.sh` – upload local template disks to a Proxmox server and convert them to templates.
* `scripts/upload.sh` – advanced uploader with automatic environment checks and interactive VM selection. The script only requires the raw disk image for each VMID; the cloud-init disk is created automatically on the Proxmox host.

Each script contains configuration variables at the top for the Proxmox host, user and storage. Edit them to match your environment before running.

* `scripts/main.sh` – one-shot helper that copies scripts to a Proxmox host (if needed), runs `create_templates.sh` remotely, downloads the resulting templates to the local machine, and optionally uploads them back.
