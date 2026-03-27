
# Immich Config.sh

Automated Immich Media Directory Migration & Symlink Setup for Proxmox LXC

---

## Overview

This script automates the migration of Immich media directories to external mount points (e.g., NAS), sets up the required folder structure, manages symlinks, updates the Immich `.env` configuration, and restarts Immich services. It is designed for use in a Proxmox LXC container running Immich, where media storage is offloaded to mounted network shares.

## Features

- Stops Immich services before making changes
- Verifies required mount points are available
- Ensures target directory structure exists
- Migrates existing media data to new locations
- Creates symlinks from Immich's internal paths to external storage
- Updates the `IMMICH_MEDIA_LOCATION` in the `.env` file
- Fixes machine-learning upload symlink
- Adjusts file ownership for Immich
- Restarts Immich services and shows recent logs


## Prerequisites

- Immich installed in a Proxmox LXC container
- External storage (e.g., NAS) mounted at:
   - `/mnt/immich_appconfig`
   - `/mnt/immich_ingest`
   - `/mnt/immich_library`
- Script must be run as root or with sufficient privileges to manage services and file ownership
- `systemctl` and standard GNU utilities available


## Usage

1. **Mount your NAS or external storage** at the required mount points.
2. **Copy this script** to your Immich LXC container, e.g. `/root/Immich Config.sh`.
3. **Run the script as root:**

   ```bash
   bash "Immich Config.sh"
   ```

4. **Monitor the output** for any errors or manual steps required.


## How it works

- Stops Immich services to prevent data corruption
- Checks that all required mount points exist
- Creates necessary subfolders and marker files
- Updates the Immich `.env` file to set the correct media location
- Moves any existing data to the new locations (if present)
- Creates symlinks from Immich's internal directories to the external storage
- Fixes the machine-learning upload symlink
- Sets correct ownership for all Immich files
- Runs a database update for media paths (if supported)
- Restarts Immich services and displays the last 10 lines of the web log


## Notes

- **Data Safety:** The script attempts to move existing data, but always ensure you have backups before running.
- **Customization:** Adjust mount point paths at the top of the script if your setup differs.
- **Troubleshooting:** If you see errors about missing directories, ensure your NAS or external storage is mounted.
- **Manual Verification:** If the database update step fails, follow the script's advice to verify manually.


---

## Contributing

Feel free to contribute by submitting pull requests or issues if you encounter any problems or have suggestions for improvements.

## License

This script is released under the [MIT License](LICENSE).