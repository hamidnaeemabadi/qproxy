#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! command -v bats >/dev/null 2>&1; then
    echo "bats not installed; install with: apt install bats" >&2
    exit 1
fi
exec bats "$root/tests"
