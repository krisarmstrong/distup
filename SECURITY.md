# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |

## Security Considerations

distup scripts require root/sudo privileges to perform system upgrades. Please consider the following:

### Before Running

1. **Always use `--dry-run` first** - Review what changes will be made before executing
2. **Back up your data** - System upgrades can fail; have backups ready
3. **Verify script integrity** - Ensure scripts haven't been tampered with
4. **Review the source** - Understand what commands will be executed

### Script Safety Features

- All scripts create backups of configuration files before modifications
- Automatic rollback on failure (where supported)
- Detailed logging to `/var/log/upgrade-*.log`
- Non-interactive mode available for automation

### Best Practices

1. Download from official repository only
2. Verify checksums if provided
3. Test in non-production environment first
4. Keep your system updated before major upgrades

## Reporting a Vulnerability

If you discover a security vulnerability, please:

1. **Do NOT** open a public issue
2. Email the maintainer directly at krisarmstrong@users.noreply.github.com
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### Response Timeline

- **Initial response**: Within 48 hours
- **Status update**: Within 7 days
- **Fix timeline**: Depends on severity
  - Critical: 24-48 hours
  - High: 7 days
  - Medium: 30 days
  - Low: Next release

## Security Updates

Security updates will be:
1. Released as patch versions (e.g., 1.0.1)
2. Announced in release notes
3. Documented in CHANGELOG.md
