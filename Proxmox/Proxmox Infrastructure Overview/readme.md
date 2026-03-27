# Proxmox Infrastructure Documentation Script

Generate a comprehensive, Markdown snapshot of your Proxmox node configuration for backup, auditing, and disaster recovery purposes.

---

## Overview

`proxmox-config-snapshot.sh` is a Bash script that collects key configuration and state information from a Proxmox node and outputs it as a well-structured Markdown document. The generated file is suitable for version control (e.g., GitHub) and serves as a reference for rebuilding or auditing your Proxmox environment.

---

## Features

- Captures:
  - `/etc/fstab` and network configuration
  - GRUB and ZFS settings
  - LXC and QEMU VM summaries (with tables)
  - Crontab and system cron jobs
  - LXC Bind Mount Wizard manifest (if present)
- Embeds both file contents and command outputs
- Handles missing files and tools gracefully
- Designed for easy Git integration

---

## Requirements

- Proxmox VE (run directly on the node)
- Bash shell
- Tools: `jq`, `pvesh`, `zpool`, `zfs` (optional, for full output)
- Root privileges (required)
- _Optional: You have used the [Proxmox Bind Mount Wizard](https://github.com/DasIgeli/Little-Garden-of-Automations/tree/main/Proxmox/Proxmox%20Bind%20Mount%20Wizard) to generate and capture bind mount configurations, which will be included in the output if available._

---

## Usage

1. **Download the script:**
   ```bash
   curl -O https://raw.githubusercontent.com/DasIgeli/Little-Garden-of-Automations/refs/heads/main/Proxmox/Proxmox%20Infrastructure%20Overview/proxmox-config-snapshot.sh
   ```

2. **Make it executable:**
   ```bash
   chmod +x proxmox-config-snapshot.sh
   ```

3. **Run with root privileges:**
   ```bash
   sudo ./proxmox-config-snapshot.sh
   ```

## Alternatively run the script straight from the repo in help mode.
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/DasIgeli/Little-Garden-of-Automations/refs/heads/main/Proxmox/Proxmox%20Infrastructure%20Overview/proxmox-config-snapshot.sh)"
```

- The script must be run as root on the Proxmox node.
- Output is written to `proxmox-config-doc.md` in the current directory.

---

## Output

- Markdown file: `proxmox-config-doc.md`
- Includes tables, code blocks, and detailed configuration sections
- Example sections:
  - FSTAB
  - Network Configuration
  - GRUB Configuration
  - ZFS Pools and Datasets
  - LXC Containers and VMs (summaries)
  - Crontab entries
  - LXC Bind Mount Wizard manifest (if available)

---

## Example

![Example Output](https://raw.githubusercontent.com/DasIgeli/Little-Garden-of-Automations/refs/heads/main/Proxmox/Proxmox%20Infrastructure%20Overview/example.md)

---

## Contributing

Suggestions are welcome! Please open an issue for feature requests or bug reports.

---

## License

MIT License. See [LICENSE](../../LICENSE) for details.
