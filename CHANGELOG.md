# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned

- Support for additional distributions (Gentoo, Void Linux, NixOS)
- Configuration file support for custom mirrors
- Backup verification before upgrades
- Integration with timeshift/snapper for system snapshots

---

## [1.1.0] - 2025-12-23

### Added

- **GitHub Templates:**
  - Bug report issue template with structured form
  - Feature request issue template
  - Pull request template with checklist

- **Project Configuration:**
  - `.gitignore` for logs, OS files, editor files, and temp files
  - `.editorconfig` for consistent code style across editors
  - `SECURITY.md` with security policy and vulnerability reporting

### Changed

- Moved configuration files from `files/` directory to project root

---

## [1.0.0] - 2025-12-23

### Added

- **Main `distup` wrapper script** - Auto-detects Linux distribution and runs appropriate upgrade script
- **8 distribution-specific upgrade scripts:**
  - `upgrade-ubuntu.sh` - Ubuntu LTS and release upgrades
  - `upgrade-debian.sh` - Debian stable, testing, and sid
  - `upgrade-fedora.sh` - Fedora stable and Rawhide
  - `upgrade-arch.sh` - Arch Linux rolling updates
  - `upgrade-alpine.sh` - Alpine Linux stable and Edge
  - `upgrade-kali.sh` - Kali Linux rolling and bleeding-edge
  - `upgrade-opensuse.sh` - openSUSE Leap and Tumbleweed
  - `upgrade-rhel-clone.sh` - Rocky Linux and AlmaLinux major version upgrades

- **Common features across all scripts:**
  - `--dry-run` mode to preview changes without applying them
  - `--version` flag to display script version
  - `--help` flag for usage information
  - Interactive menus when run without arguments
  - Automatic repository backup before changes
  - Detailed logging to `/var/log/`
  - Error handling with automatic rollback
  - Color-coded output for better readability
  - Root privilege verification

- **Development tooling:**
  - Makefile with `lint`, `format`, `check`, `test` targets
  - `make install` and `make uninstall` for system-wide installation
  - GitHub Actions CI pipeline for linting and validation
  - GitHub Actions release workflow

- **Documentation:**
  - Comprehensive README with usage examples
  - CONTRIBUTING guide
  - MIT License
  - Bash and Zsh shell completions

### Security

- All scripts verify root/sudo privileges before executing
- Repository configurations are backed up before modification
- Automatic rollback on failure prevents partial upgrades
- No hardcoded credentials or sensitive data
