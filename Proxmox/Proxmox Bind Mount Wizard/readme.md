# Proxmox Bind Mount Wizard

A comprehensive bash utility for managing CIFS (SMB) share bind mounts in Proxmox LXC containers. This wizard automates the setup, configuration, and management of network share mounts with full UID/GID mapping support.

Is it overkill? Yes, most likely! Does it do exactly what I need? Of course!

I'm one of those people, which do not want to repeat the same things over and over again when creating new LXCs, doing some testing. Thus, this script was created :) 

## Features

- **Interactive Setup Wizard**: Easy-to-use guided setup for mounting CIFS shares
- **Credential Management**: Secure credential file handling with automatic reuse of existing credentials
- **UID/GID Mapping**: Automatic detection and mapping of user IDs between host and container
- **Manifest System**: Complete operation tracking and management via JSON manifest file
- **Rollback Support**: Safely remove previously created mounts with full cleanup
- **Dry-Run Preview**: Preview changes before applying them with the diff mode
- **Multiple Modes**: Setup, rollback, list, and diff preview modes

## Requirements

### System Requirements
- **OS**: Proxmox VE (Linux-based system)
- **Bash**: Version 4.0 or higher
- **Root Access**: Script must be run with sudo/root privileges

### Required Packages
- `cifs-utils`: For mounting CIFS/SMB shares
  ```bash
  sudo apt-get install cifs-utils
  ```
- `jq`: For JSON manifest processing
  ```bash
  sudo apt-get install jq
  ```

Both packages can be installed automatically by the script if not present.

## Installation

1. **Download the script:**
   ```bash
   curl -O https://raw.githubusercontent.com/DasIgeli/Little-Garden-of-Automations/refs/heads/main/Proxmox/Proxmox%20Bind%20Mount%20Wizard/ProxmoxBindMountWizard.sh
   ```

2. **Make it executable:**
   ```bash
   chmod +x ProxmoxBindMountWizard.sh
   ```

3. **Run with root privileges:**
   ```bash
   sudo ./ProxmoxBindMountWizard.sh
   ```

## Alternatively run the script straight from the repo in help mode.
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/DasIgeli/Little-Garden-of-Automations/refs/heads/main/Proxmox/Proxmox%20Bind%20Mount%20Wizard/ProxmoxBindMountWizard.sh)" -- --help
```

## Usage

### Basic Setup (Interactive Mode)

```bash
sudo ./ProxmoxBindMountWizard.sh --setup
```

This launches the interactive wizard which will guide you through:
1. LXC Container ID
2. NAS/SMB Server IP or hostname
3. Share path on the server
4. Local mount name
5. Credential selection or creation
6. Container mount path
7. Read-only/Read-write preference
8. User selection inside the container
9. UID/GID confirmation

### List Configured Mounts

View all previously configured mounts:

```bash
sudo ./ProxmoxBindMountWizard.sh --list
```

Output example:
```
Index | LXC | Mount Name          | Share Path                    | Status
------|-----|---------------------|-----------| ---------
[1] ... | myshare_docs | 192.168.1.100/Documents | success
[2] ... | myshare_media | 192.168.1.100/Media | success
```

### Rollback Mounts

Remove previously created mounts:

```bash
sudo ./ProxmoxBindMountWizard.sh --rollback
```

The wizard will:
1. Display all configured mounts
2. Allow selection of one or multiple mounts to remove
3. Remove entries from `/etc/fstab`
4. Remove entries from LXC configuration
5. Unmount the shares
6. Update the manifest file

### Dry-Run Preview (Diff Mode)

Preview what will be removed before running rollback:

```bash
sudo ./ProxmoxBindMountWizard.sh --diff
```

Shows the exact changes that would be made (fstab entries, LXC config entries, unmount commands) without applying them.

### Display Version

```bash
sudo ./ProxmoxBindMountWizard.sh --version
```

### Display Help

```bash
sudo ./ProxmoxBindMountWizard.sh --help
```

## Advanced Options

### Disable Colored Output

Use the `--no-color` flag with any mode to disable ANSI color codes:

```bash
sudo ./ProxmoxBindMountWizard.sh --setup --no-color
```

Useful for logging or piping output to other commands.

## Directory Structure

The script uses the following directory structure:

```
/mnt/lxc_shares/                    # Mount point base directory
├── .wizard-manifest.json           # Manifest file (operation tracking)
├── myshare_docs/                   # Individual mount directory
├── myshare_media/
└── ...

/mnt/Creds/                         # Credential files directory
├── .creds-myshare_docs             # Individual credential files
├── .creds-myshare_media
└── ...
```

**Permissions**: Credential files are created with 600 permissions (readable/writable by root only).

## Credential Management

### Automatic Credential Reuse

When setting up a new mount, the wizard checks for existing credential files and offers to reuse them. This prevents duplicate credential files for multiple shares on the same server.

### Credential File Format

Credential files are stored in `/mnt/Creds/.creds-<mount_name>` with the following format:

```
username=myuser
password=mypassword
domain=MYDOMAIN
```

### Security Considerations

- Credential files have restrictive permissions (600 - root only)
- Passwords are stored in plain text (inherent limitation of CIFS mount credentials)
- Ensure proper file system permissions on the `/mnt/Creds` directory
- Consider using a dedicated service account for share access

## Manifest System

The manifest file (`/mnt/lxc_shares/.wizard-manifest.json`) tracks all mount operations for reversibility and auditing:

### Manifest Structure

```json
{
  "wizard_version": "2.0",
  "created": "2026-03-21T10:30:45Z",
  "operations": [
    {
      "timestamp": "2026-03-21T10:30:45Z",
      "lxc_id": "100",
      "mount_name": "myshare_docs",
      "share_ip": "192.168.1.100",
      "share_path": "Documents",
      "mount_point": "/mnt/lxc_shares/myshare_docs",
      "target_path": "/mnt/media",
      "creds_file": "/mnt/Creds/.creds-myshare_docs",
      "username": "user",
      "domain": "MYDOMAIN",
      "host_uid": 100000,
      "host_gid": 110000,
      "container_uid": 1000,
      "container_gid": 1000,
      "read_only": false,
      "fstab_comment": "# Added share using Proxmox Bind Mount Wizard...",
      "fstab_entry": "//192.168.1.100/Documents /mnt/lxc_shares/myshare_docs cifs...",
      "lxc_conf_entry": "mp0: /mnt/lxc_shares/myshare_docs,mp=/mnt/media,shared=1",
      "status": "success"
    }
  ]
}
```

## UID/GID Mapping

The wizard automatically detects and configures UID/GID mapping for proper file permission handling between the Proxmox host and LXC containers.

### How It Works

1. **Detection**: Reads UID/GID offset from `/etc/subuid` and `/etc/subgid`
2. **User Selection**: Lists non-system users in the container
3. **Mapping Calculation**: 
   - Host UID = Container UID + UID Offset
   - Host GID = Container GID + GID Offset
4. **Verification**: Allows manual override if automatic detection fails

### Example

```
Container UID: 1000 (user account)
UID Offset: 100000 (from /etc/subuid)
Host UID: 101000 (calculated)

Container GID: 1000 (user group)
GID Offset: 110000 (from /etc/subgid)
Host GID: 111000 (calculated)
```

## Configuration Files Modified

The script modifies the following system files:

### `/etc/fstab`
Adds CIFS mount entries with the following options:
- `_netdev`: Mount after network is available
- `x-systemd.automount`: Systemd auto-mount support
- `credentials=<file>`: Path to credential file
- `uid/gid`: UID/GID of host user
- `dir_mode=0770`: Directory permissions
- `file_mode=0770`: File permissions
- `ro` (optional): Read-only mode

### `/etc/pve/lxc/<lxc_id>.conf`
Adds bind mount entries in the format:
```
mp0: /mnt/lxc_shares/<mount_name>,mp=/container/path,shared=1[,ro=1]
```

## Troubleshooting

### Permission Denied Errors

**Problem**: Mount fails with "Permission denied"

**Solutions**:
- Ensure UID/GID mapping is correct
- Check if the share is accessible from the Proxmox host:
  ```bash
  mkdir -p /test-mount
  mount -t cifs //<server>/<share> /test-mount -o credentials=/mnt/Creds/.creds-xxx
  ```
- Verify credential file: `sudo cat /mnt/Creds/.creds-<mount_name>`

### Mount not visible in container

**Problem**: Mount is created but not visible inside the container

**Solutions**:
- Restart container: `pct reboot <lxc_id>`
- Verify LXC config: `grep "mp[0-9]:" /etc/pve/lxc/<lxc_id>.conf`
- Check mount on host: `mount | grep <mount_name>`

### Network timeout during mount

**Problem**: "No route to host" or timeout errors

**Solutions**:
- Verify connectivity: `ping <nas_ip>`
- Check firewall rules (SMB uses port 445/139)
- Ensure NAS/SMB server is accessible from Proxmox network
- Try using hostname instead of IP (or vice versa)

### jq or cifs-utils not found

**Problem**: Script fails with "command not found"

**Solutions**:
- The script can attempt automatic installation
- Or manually install: `sudo apt-get install jq cifs-utils`

## Examples

### Example 1: Mount Synology NAS Share

```bash
sudo ./ProxmoxBindMountWizard.sh --setup

# Responses:
# LXC ID: 100
# IP/Hostname: 192.168.1.50
# Share path: homes/personal
# Mount name: synology_share
# (Select or create credentials for Synology user)
# Container path: /mnt/nas
# Read-only: no
# (Select user inside container)
```

### Example 2: Rollback Specific Mount

```bash
sudo ./ProxmoxBindMountWizard.sh --rollback

# Select: 1
# (Removes myshare_docs mount)
```

### Example 3: Preview Changes Before Rollback

```bash
sudo ./ProxmoxBindMountWizard.sh --diff

# Select: 1,3
# (Shows changes for mounts 1 and 3 without applying)
```

## Best Practices

1. **Document Your Mounts**: Use descriptive mount names (e.g., `nas_backup_weekly` instead of `share1`)

2. **Test Before Production**: Use a test LXC container first to verify the setup

3. **Secure Credentials**: 
   - Restrict access to `/mnt/Creds` directory
   - Use dedicated service accounts for share access
   - Avoid sharing credentials between multiple shares if possible

4. **Backup Configuration**: 
   - Keep a backup of the manifest file
   - Document any manual modifications to `/etc/fstab` or container configs

5. **Monitor Mounts**: 
   - Use `--list` to verify configured mounts after system reboots
   - Check container logs if mounts fail to mount automatically

6. **Handle Failures Gracefully**:
   - Use `--diff` mode to preview before rollback
   - Keep documentation of which shares are critical

## Version History

- **v2.0** (Current)
  - Added manifest system for operation tracking
  - Improved credential reuse functionality
  - Added diff/dry-run mode
  - Enhanced error handling and validation
  - Complete rollback support

## Support

For issues, questions, or suggestions:
1. Check the Troubleshooting section above
2. Examine `/mnt/lxc_shares/.wizard-manifest.json` for operation history
3. Check Proxmox logs: `journalctl -u pvedaemon` or container logs: `pct logs <lxc_id>`

## Contributing

Contributions are welcome! Please test thoroughly in a controlled Proxmox environment before submitting changes.

---

**Created**: Proxmox Bind Mount Wizard v2.0  
**Last Updated**: March 2026

