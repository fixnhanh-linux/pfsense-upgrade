# Quick Reference — pfSense CE Upgrade (one page)

> Vietnamese full playbook: [README.md](../README.md) · Vietnamese checklist: [checklist-vn.md](checklist-vn.md)

## Facts (as of October 2026)

- Latest pfSense **CE** release: **2.9.0**.
- 2.8.x branch: **2.8.0** = major (new FreeBSD base), **2.8.1** = maintenance fix.
- pfSense **Plus** is a separate track (25.x / 26.x) — never mix tracks.

## Which path?

| Current version | Action |
| --- | --- |
| 2.8.x | GUI upgrade to 2.9.0 |
| 2.7.x | Step via 2.8.1 first, **or** clean install + restore `config.xml` |
| < 2.7 | Clean install (ISO/USB) + restore `config.xml` |

## Pre-flight

- Backup: `Diagnostics → Backup & Restore`, plus console `cp /conf/config.xml`.
- Enable **AutoConfigBackup**; snapshot the VM (Proxmox/ESXi) if virtualized.
- Download installer media for the target version.
- Read-only pre-check: `scripts/pfsense-prep-check.sh` (run over SSH).
- Note custom packages and aliases with urltable/overload rules.

## Console / SSH rescue (community-verified commands)

```sh
certctl rehash && pkg-static update -f && pkg-static install -fy pkg pfSense-repo pfSense-upgrade
```

```sh
pkg-static clean -ay; pkg-static install -fy pkg pfSense-repo pfSense-upgrade
```

Useful console menu entries: `8) Shell`, `13) Upgrade from console`, `15) Restore recent configuration`.

## 2.8.0 gotchas

| Change | What to do |
| --- | --- |
| State policy default → **Interface Bound** | Revert in System → Advanced → Firewall & NAT if needed |
| DHCP: ISC → **Kea** | Keep ISC for a while if required; verify leases |
| New PPPoE driver **if_pppoe** | Opt-in; re-test WAN PPPoE (MTU/MRU) |
| New installer UI | Nothing to do, just re-orient |
| ZFS + low RAM | Needs care below ~2 GB RAM; add RAM before upgrading |

## Post-upgrade checks

`cat /etc/version` · WAN ping · DHCP leases · DNS lookup · VPN handshakes · NAT/port-forward test · Status → Services · Aliases intact · Package Manager (custom packages reinstalled) · CARP/pfsync sync.

## Recover

Console option 15 (restore recent config) · AutoConfigBackup restore · VM snapshot rollback · reinstall from ISO + restore `config.xml`.

## Never do this

- Do **not** `pkg install php` on pfSense. PHP ships with pfSense itself and is upgraded **as part of the pfSense upgrade**. A standalone PHP install can break the GUI/JSON layer — PHP is pfSense core.
