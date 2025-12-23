# distup

**Safely upgrade any Linux distribution with one command.**

A collection of well-documented Bash scripts to upgrade major Linux distributions to their latest releases.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)

## Overview

distup provides a consistent, safe, and interactive way to upgrade various Linux distributions. Each script includes:

- **Interactive menus** for selecting upgrade paths
- **Pre-flight checks** to verify system compatibility
- **Automatic backups** of repository configurations
- **Detailed logging** of all operations
- **Error handling** with automatic rollback
- **Post-upgrade recommendations**

## Supported Distributions

| Distribution | Script | Upgrade Paths |
|-------------|--------|---------------|
| Ubuntu | `upgrade-ubuntu.sh` | LTS → LTS, Release → Release |
| Fedora | `upgrade-fedora.sh` | Stable, Rawhide |
| Debian | `upgrade-debian.sh` | Stable, Testing, Sid |
| Alpine | `upgrade-alpine.sh` | Stable, Edge |
| Kali Linux | `upgrade-kali.sh` | Rolling, Bleeding-edge |
| Arch Linux | `upgrade-arch.sh` | Rolling (always latest) |
| Rocky/Alma | `upgrade-rhel-clone.sh` | EL8 → EL9 (major version) |
| openSUSE | `upgrade-opensuse.sh` | Leap, Tumbleweed |

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/krisarmstrong/distup.git
cd distup

# Make scripts executable
chmod +x upgrade-*.sh
```

### Usage

Each script can be run interactively (with menu) or with command-line arguments:

```bash
# Interactive mode (shows menu)
sudo ./upgrade-ubuntu.sh

# Direct mode (skip menu)
sudo ./upgrade-ubuntu.sh lts
sudo ./upgrade-ubuntu.sh release
```

## Script Details

### Ubuntu (`upgrade-ubuntu.sh`)

Upgrade Ubuntu to latest LTS or standard release.

```bash
sudo ./upgrade-ubuntu.sh [lts|release]
```

| Option | Description |
|--------|-------------|
| `lts` | Upgrade to latest Long Term Support release (5-year support) |
| `release` | Upgrade to latest available release (including interim) |

**Examples:**
- `20.04 LTS → 22.04 LTS → 24.04 LTS` (LTS path)
- `24.04 → 24.10 → 25.04 → 25.10` (Release path)

---

### Fedora (`upgrade-fedora.sh`)

Upgrade Fedora to latest stable or Rawhide.

```bash
sudo ./upgrade-fedora.sh [stable|rawhide]
```

| Option | Description |
|--------|-------------|
| `stable` | Upgrade to latest stable Fedora release |
| `rawhide` | Switch to Rawhide (rolling development branch) |

**Note:** System reboots during upgrade to apply changes.

---

### Debian (`upgrade-debian.sh`)

Upgrade Debian to Stable, Testing, or Sid.

```bash
sudo ./upgrade-debian.sh [stable|testing|sid]
```

| Option | Description |
|--------|-------------|
| `stable` | Current stable release (recommended for servers) |
| `testing` | Next stable in preparation (newer packages) |
| `sid` | Unstable/rolling (bleeding edge, may break) |

**Warning:** Moving to Sid is generally a one-way trip.

---

### Alpine (`upgrade-alpine.sh`)

Upgrade Alpine Linux to latest stable or Edge.

```bash
sudo ./upgrade-alpine.sh [stable|edge]
```

| Option | Description |
|--------|-------------|
| `stable` | Latest stable Alpine release |
| `edge` | Rolling release with latest packages |

---

### Kali Linux (`upgrade-kali.sh`)

Update Kali rolling release or enable bleeding-edge.

```bash
sudo ./upgrade-kali.sh [rolling|bleeding-edge]
```

| Option | Description |
|--------|-------------|
| `rolling` | Standard Kali rolling release |
| `bleeding-edge` | Experimental/untested packages |

---

### Arch Linux (`upgrade-arch.sh`)

Update Arch Linux rolling release.

```bash
sudo ./upgrade-arch.sh [--refresh] [--clean]
```

| Option | Description |
|--------|-------------|
| `--refresh` | Force refresh package databases |
| `--clean` | Clean package cache after upgrade |

**Features:**
- Checks Arch Linux news before upgrading
- Detects orphaned packages
- Finds `.pacnew`/`.pacsave` files needing attention

---

### Rocky/AlmaLinux (`upgrade-rhel-clone.sh`)

Upgrade RHEL clones to next major version (e.g., EL8 → EL9).

```bash
sudo ./upgrade-rhel-clone.sh [--check|--upgrade]
```

| Option | Description |
|--------|-------------|
| `--check` | Run pre-upgrade assessment only |
| `--upgrade` | Perform the actual upgrade |

**Recommended workflow:**
1. `sudo ./upgrade-rhel-clone.sh --check` - Review the report
2. Resolve any high-severity issues
3. `sudo ./upgrade-rhel-clone.sh --upgrade` - Perform upgrade

---

### openSUSE (`upgrade-opensuse.sh`)

Upgrade openSUSE Leap or switch to Tumbleweed.

```bash
sudo ./upgrade-opensuse.sh [leap|tumbleweed]
```

| Option | Description |
|--------|-------------|
| `leap` | Upgrade to latest Leap release |
| `tumbleweed` | Switch to rolling release |

**Warning:** Switching to Tumbleweed is generally a one-way migration.

---

## Features

### Safety Features

- **Root check:** Scripts verify root/sudo privileges before running
- **Distribution detection:** Scripts verify they're running on the correct distro
- **Backup creation:** Repository configs are backed up before changes
- **Error handling:** Automatic rollback on failure (where possible)
- **Confirmation prompts:** User must confirm before destructive operations

### Logging

All scripts create detailed logs in `/var/log/`:

```
/var/log/upgrade-ubuntu-20251223-143022.log
/var/log/upgrade-fedora-20251223-143022.log
...
```

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Error (wrong distro, missing root, invalid args) |

## Requirements

- **Bash 4.0+**
- **Root/sudo privileges**
- **Active internet connection**
- **Sufficient disk space** (~5GB recommended for most upgrades)

### Per-Distribution Requirements

| Distribution | Package Manager | Additional Tools |
|-------------|-----------------|------------------|
| Ubuntu | apt | update-manager-core |
| Fedora | dnf | dnf-plugin-system-upgrade |
| Debian | apt | - |
| Alpine | apk | - |
| Kali | apt | - |
| Arch | pacman | - |
| Rocky/Alma | dnf | leapp-upgrade, elevate |
| openSUSE | zypper | - |

## Best Practices

### Before Upgrading

1. **Back up your data** - Always have a backup before major upgrades
2. **Read release notes** - Check for known issues with your target version
3. **Test first** - If possible, test upgrades in a VM before production
4. **Check disk space** - Ensure adequate free space (`df -h`)
5. **Update current system** - Run standard updates before upgrading

### During Upgrade

1. **Don't interrupt** - Let the upgrade complete, even if it seems slow
2. **Stay connected** - Ensure stable power and network
3. **Watch for prompts** - Some upgrades require user input

### After Upgrade

1. **Reboot** - Always reboot after a distribution upgrade
2. **Verify services** - Check that critical services are running
3. **Check logs** - Review upgrade logs for any warnings
4. **Clean up** - Remove old packages and kernels

## Troubleshooting

### Ubuntu: "No new release found"

```bash
# Enable normal releases (not just LTS)
sudo sed -i 's/Prompt=lts/Prompt=normal/' /etc/update-manager/release-upgrades

# Or use development release flag
sudo do-release-upgrade -d
```

### Fedora: Upgrade stuck

```bash
# If download completed but upgrade didn't start
sudo dnf system-upgrade reboot
```

### Debian: Dependency issues

```bash
# Fix broken packages
sudo apt --fix-broken install
sudo dpkg --configure -a
```

### Arch: PGP key issues

```bash
# Refresh keys
sudo pacman-key --refresh-keys
sudo pacman -Sy archlinux-keyring
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-distro`)
3. Commit your changes (`git commit -am 'Add support for DistroX'`)
4. Push to the branch (`git push origin feature/new-distro`)
5. Create a Pull Request

### Adding a New Distribution

When adding support for a new distribution:

1. Follow the existing script structure
2. Include comprehensive header documentation
3. Implement all safety features (root check, distro detection, backups)
4. Add logging throughout
5. Update this README

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

These scripts are provided as-is, without warranty. While they include safety features, **always back up your data before upgrading**. The authors are not responsible for any data loss or system issues resulting from the use of these scripts.

## Author

**Kris Armstrong**

- GitHub: [@krisarmstrong](https://github.com/krisarmstrong)

## Acknowledgments

- The Linux community for excellent documentation
- Distribution maintainers for reliable upgrade paths
- Contributors and testers

---

⭐ If distup helped you, consider giving it a star on GitHub!
