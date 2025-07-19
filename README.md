# Proxmox Template Scripts

This repository contains simple bash utilities for working with Proxmox VM templates.

* `scripts/create_templates.sh` – download Ubuntu cloud images and create template VMs directly on the Proxmox host.
* `scripts/download_templates.sh` – fetch existing template disks from a Proxmox server to your local machine.
* `scripts/upload_templates.sh` – upload local template disks to a Proxmox server and convert them to templates.

Each script contains configuration variables at the top for the Proxmox host, user and storage. Edit them to match your environment before running.
