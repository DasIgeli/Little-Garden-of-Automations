# Proxmox Configuration Snapshot — node01

> Generated: 2026-03-27  
> Node: node01  
> Version: pve-manager/9.x  
>
> Auto-generated. Read-only reference for rebuilds.

---

## fstab (excerpt)

```text
/dev/pve/root / ext4 defaults 0 1
UUID=XXXX-XXXX /boot/efi vfat defaults 0 1

# CIFS mounts
//NAS/share/appdata /mnt/appdata cifs _netdev,credentials=/root/.creds,uid=1000,gid=1000,dir_mode=0770,file_mode=0770 0 0
//NAS/share/media   /mnt/media   cifs _netdev,credentials=/root/.creds,uid=1000,gid=1000,dir_mode=0775,file_mode=0775 0 0
````

---

## Network

```text
auto lo
iface lo inet loopback

auto vmbr0
iface vmbr0 inet static
  address 10.0.0.10/24
  gateway 10.0.0.1
  bridge-ports eth0
```

---

## Storage

```text
dir: local
  path /var/lib/vz

lvmthin: local-lvm
  vgname pve

cifs: nas
  server 10.0.0.20
  share data
```

---

## LXC Containers

| ID  | Name  | CPU | RAM | Disk | IP       |
| --- | ----- | --- | --- | ---- | -------- |
| 100 | dns   | 1   | 512 | 8G   | 10.0.0.2 |
| 101 | proxy | 2   | 2G  | 8G   | 10.0.0.3 |
| 102 | media | 4   | 4G  | 50G  | dhcp     |

---

## Virtual Machines

| ID  | Name       | CPU | RAM | Disk |
| --- | ---------- | --- | --- | ---- |
| 200 | home-auto  | 2   | 4G  | 32G  |
| 201 | linux-test | 2   | 2G  | iso  |

---

## Cron (root)

```text
@reboot echo powersave > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

---

## Notes

* Uses CIFS for shared storage
* No ZFS configured
* Static + DHCP mixed network

---

*End of snapshot*