#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Shellcheck all scripts
for f in upgrade-*.sh lib/*.sh; do
  shellcheck "$f"
done
