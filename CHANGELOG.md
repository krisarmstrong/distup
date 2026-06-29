# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.1](https://github.com/krisarmstrong/distup/compare/v1.2.0...v1.2.1) (2026-06-29)


### Miscellaneous

* add platinum Bash linting standards ([23582c4](https://github.com/krisarmstrong/distup/commit/23582c4a56000963780a654c74977fd8a5f44b60))
* **ci:** refresh GitHub Actions pins ([#9](https://github.com/krisarmstrong/distup/issues/9)) ([37199cd](https://github.com/krisarmstrong/distup/commit/37199cdbdde14bfef086971e3bd1519d48aaf410))
* **github:** standardize repo governance ([#6](https://github.com/krisarmstrong/distup/issues/6)) ([5c34f8f](https://github.com/krisarmstrong/distup/commit/5c34f8f33a9d24fb41414f8a611c94dd69b72d65))
* standardize repo governance tooling ([#15](https://github.com/krisarmstrong/distup/issues/15)) ([b34e598](https://github.com/krisarmstrong/distup/commit/b34e59809bfa59ef84ebd69edcf5d15eddf924c9))

## [Unreleased]

### Planned

- Support for additional distributions (Gentoo, Void Linux, NixOS)
- Configuration file support for custom mirrors ([#1](https://github.com/krisarmstrong/distup/issues/1))
- Backup verification before upgrades

---

## [1.2.0] - 2025-12-23

### Added

- **Pre-upgrade System Checks (`lib/checks.sh`):**
  - Disk space verification (configurable minimum, default 5GB)
  - Network connectivity validation (tests multiple endpoints)
  - Battery status check for laptops (warns if on battery with low charge)
  - `--skip-checks` flag to bypass pre-upgrade checks

- **Snapshot Integration (`lib/snapshot.sh`):**
  - Automatic detection of snapshot tools (Timeshift, Snapper, btrfs, LVM)
  - Pre-upgrade snapshot creation with prompts
  - Support for Timeshift snapshots (desktop systems)
  - Support for Snapper snapshots (openSUSE/server systems)
  - Support for native btrfs snapshots
  - Support for LVM snapshots

- **Post-upgrade Hook System (`lib/hooks.sh`):**
  - System-wide hooks in `/etc/distup/hooks.d/`
  - User-specific hooks in `~/.config/distup/hooks.d/`
  - Separate pre-upgrade and post-upgrade hook directories
  - Automatic hook discovery and execution

- **Man Pages:**
  - Added man pages for distup and all 8 upgrade scripts
  - Installed to `$PREFIX/share/man/man1/` via Makefile

### Fixed

- **POSIX Compatibility:**
  - Replaced `grep -P` (PCRE) with POSIX-compatible `sed` patterns
  - Fixed Alpine Linux version detection (BusyBox grep compatibility)
  - Fixed Fedora version detection from release page
  - Fixed Arch Linux news title extraction

- **Version Detection:**
  - Fixed openSUSE Leap version detection (handles `./15.6/` format)
  - Added filtering for legacy openSUSE versions (42.x)

### Changed

- Updated all scripts to source shared library files
- Improved help text formatting with consistent spacing

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
