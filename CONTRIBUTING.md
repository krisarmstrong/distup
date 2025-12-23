# Contributing to distup

First off, thanks for taking the time to contribute! 🎉

## How Can I Contribute?

### Reporting Bugs

- Check if the bug has already been reported in [Issues](https://github.com/krisarmstrong/distup/issues)
- If not, open a new issue with:
  - Distribution name and version
  - Script name and version
  - Steps to reproduce
  - Expected vs actual behavior
  - Relevant log output

### Suggesting New Distributions

Open an issue with:
- Distribution name
- Upgrade mechanism (package manager, tools used)
- Links to official upgrade documentation

### Pull Requests

1. Fork the repo
2. Create your feature branch (`git checkout -b feature/add-mint-support`)
3. Make your changes
4. Run linting locally (see below)
5. Commit (`git commit -am 'Add Linux Mint support'`)
6. Push (`git push origin feature/add-mint-support`)
7. Open a Pull Request

## Development Setup

### Requirements

- Bash 4.0+
- [ShellCheck](https://www.shellcheck.net/) for linting
- [shfmt](https://github.com/mvdan/sh) for formatting

### Install tools (macOS)

```bash
brew install shellcheck shfmt
```

### Install tools (Ubuntu/Debian)

```bash
sudo apt install shellcheck
# shfmt via snap or binary
sudo snap install shfmt
```

## Code Style

### Linting

All scripts must pass ShellCheck:

```bash
shellcheck -x -s bash upgrade-*.sh
```

### Formatting

Scripts use 4-space indentation. Format with shfmt:

```bash
# Check formatting
shfmt -i 4 -ci -d upgrade-*.sh

# Auto-fix formatting
shfmt -i 4 -ci -w upgrade-*.sh
```

### Script Structure

New scripts should follow this structure:

```bash
#!/bin/bash
# =============================================================================
# Script Name:    upgrade-distro.sh
# Description:    Brief description
# Author:         Your Name
# Created:        YYYY-MM-DD
# Version:        1.0.0
# License:        MIT
#
# Usage:          sudo ./upgrade-distro.sh [options]
#
# Requirements:   List requirements
#
# Notes:          Additional notes
# =============================================================================

set -e

# CONFIGURATION section
# FUNCTIONS section  
# MAIN EXECUTION section
```

### Required Features

Every script must include:

- [ ] Root/sudo check
- [ ] Distribution detection
- [ ] Repository backup before changes
- [ ] Logging to `/var/log/`
- [ ] Error handling with rollback (where possible)
- [ ] Interactive menu AND CLI arguments
- [ ] Colored output
- [ ] Confirmation prompts before destructive actions
- [ ] Final reboot recommendation

## Testing

### Syntax check

```bash
bash -n upgrade-*.sh
```

### Test in VM

Always test scripts in a virtual machine before submitting. Never test on production systems.

## Commit Messages

Use clear, descriptive commit messages:

```
Add Linux Mint support

- Added upgrade-mint.sh with LTS and latest paths
- Updated README with Mint documentation
- Added Mint to CI test matrix
```

## Questions?

Open an issue or reach out to [@krisarmstrong](https://github.com/krisarmstrong).

Thanks for contributing! 🐧
