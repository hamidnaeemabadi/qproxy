#!/bin/bash
########################################################
# Author: [Hamid Naeemabadi]
# Script Name: QProxy
# Purpose: [Manage the proxy configs on Linux and services quickly.]
########################################################

QPROXY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -d "$QPROXY_ROOT/lib" ] && [ -d "/usr/local/lib/qproxy/lib" ]; then
    QPROXY_ROOT="/usr/local/lib/qproxy"
fi
if [ ! -d "$QPROXY_ROOT/lib" ]; then
    echo "Error: QProxy library files not found (expected lib/ next to qproxy.sh or under /usr/local/lib/qproxy)." >&2
    exit 1
fi
QPROXY_TEMPLATES="$QPROXY_ROOT/templates"
QPROXY_SHARE_DIR="$QPROXY_ROOT/share"
QPROXY_DOCS_DIR="$QPROXY_ROOT/docs"
QPROXY_BUNDLED_PROXYCHAINS_CONF="$QPROXY_SHARE_DIR/proxychains/proxychains4.conf"

source "$QPROXY_ROOT/lib/user.sh"
source "$QPROXY_ROOT/lib/config.sh"
source "$QPROXY_ROOT/lib/session.sh"
source "$QPROXY_ROOT/lib/deps.sh"
source "$QPROXY_ROOT/lib/test.sh"
source "$QPROXY_ROOT/lib/os-env.sh"
source "$QPROXY_ROOT/lib/pkgmgr/apt.sh"
source "$QPROXY_ROOT/lib/pkgmgr/dnf.sh"
source "$QPROXY_ROOT/lib/pkgmgr/pacman.sh"
source "$QPROXY_ROOT/lib/pkgmgr/zypper.sh"
source "$QPROXY_ROOT/lib/ui.sh"
source "$QPROXY_ROOT/lib/ui/pkgmgr-apt.sh"
source "$QPROXY_ROOT/lib/pkgmgr/facade.sh"
source "$QPROXY_ROOT/lib/docker.sh"
source "$QPROXY_ROOT/lib/ui/docker.sh"
source "$QPROXY_ROOT/lib/containerd.sh"
source "$QPROXY_ROOT/lib/ui/containerd.sh"
source "$QPROXY_ROOT/lib/proxychains.sh"
source "$QPROXY_ROOT/lib/ui/proxychains.sh"
source "$QPROXY_ROOT/lib/configure.sh"
source "$QPROXY_ROOT/lib/install.sh"
source "$QPROXY_ROOT/menus/main.sh"
source "$QPROXY_ROOT/lib/cli.sh"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -gt 0 ]; then
        cli_main "$@"
    else
        main "$@"
    fi
fi
