# System install paths (FHS)
QPROXY_INSTALL_PREFIX="${QPROXY_INSTALL_PREFIX:-/usr/local}"
QPROXY_INSTALL_LIB="${QPROXY_INSTALL_LIB:-$QPROXY_INSTALL_PREFIX/lib/qproxy}"
QPROXY_INSTALL_BIN="${QPROXY_INSTALL_BIN:-$QPROXY_INSTALL_PREFIX/bin/qproxy}"
QPROXY_INSTALL_PROXYCHAINS_CONF="${QPROXY_INSTALL_PROXYCHAINS_CONF:-/etc/proxychains4.conf}"

qproxy_install_source_root() {
    echo "$QPROXY_ROOT"
}

qproxy_install_validate_source() {
    local source_root="${1:-}"
    local missing=0
    for path in lib menus templates qproxy.sh; do
        if [ ! -e "$source_root/$path" ]; then
            echo "Error: missing $source_root/$path" >&2
            missing=1
        fi
    done
    [ "$missing" -eq 0 ]
}

qproxy_install_is_installed() {
    [ -x "$QPROXY_INSTALL_LIB/qproxy.sh" ] && [ -L "$QPROXY_INSTALL_BIN" -o -x "$QPROXY_INSTALL_BIN" ]
}

qproxy_install_status() {
    echo "QProxy $VERSION"
    if qproxy_install_is_installed; then
        echo "Status: installed"
        echo "Library: $QPROXY_INSTALL_LIB"
        echo "Command: $QPROXY_INSTALL_BIN"
        if [ -L "$QPROXY_INSTALL_BIN" ]; then
            echo "Symlink: $(readlink -f "$QPROXY_INSTALL_BIN" 2>/dev/null || readlink "$QPROXY_INSTALL_BIN")"
        fi
        if [ -f "$QPROXY_INSTALL_LIB/VERSION" ]; then
            echo "Version: $(tr -d '[:space:]' < "$QPROXY_INSTALL_LIB/VERSION")"
        fi
    else
        echo "Status: not installed"
        echo "Expected library: $QPROXY_INSTALL_LIB"
        echo "Expected command: $QPROXY_INSTALL_BIN"
    fi
}

qproxy_install_write_version() {
    local source_root="$1" ver
    if [ -d "$source_root/.git" ] && command -v git >/dev/null 2>&1; then
        ver=$(git -C "$source_root" describe --tags --dirty --always 2>/dev/null)
    fi
    ver="${ver:-$QPROXY_DEFAULT_VERSION}"
    printf '%s\n' "$ver" > "$QPROXY_INSTALL_LIB/VERSION"
    chmod 644 "$QPROXY_INSTALL_LIB/VERSION"
}

qproxy_install_copy_tree() {
    local source_root="$1"
    local item
    for item in lib menus templates share docs; do
        if [ -d "$source_root/$item" ]; then
            rm -rf "$QPROXY_INSTALL_LIB/$item"
            cp -a "$source_root/$item" "$QPROXY_INSTALL_LIB/$item"
        fi
    done
    install -m 755 "$source_root/qproxy.sh" "$QPROXY_INSTALL_LIB/qproxy.sh"
    for item in LICENSE CHANGELOG.md README.md; do
        if [ -f "$source_root/$item" ]; then
            install -m 644 "$source_root/$item" "$QPROXY_INSTALL_LIB/$item"
        fi
    done
}

qproxy_install_link_command() {
    install -d "$(dirname "$QPROXY_INSTALL_BIN")"
    ln -sfn "$QPROXY_INSTALL_LIB/qproxy.sh" "$QPROXY_INSTALL_BIN"
}

qproxy_install_proxychains_conf() {
    local source_root="$1" force="${2:-false}"
    local bundled="$source_root/share/proxychains/proxychains4.conf"
    [ -f "$bundled" ] || bundled="${QPROXY_BUNDLED_PROXYCHAINS_CONF:-}"
    [ -f "$bundled" ] || return 0
    if [ -f "$QPROXY_INSTALL_PROXYCHAINS_CONF" ] && [ "$force" != "true" ]; then
        echo "Keeping existing $QPROXY_INSTALL_PROXYCHAINS_CONF (use --force-proxychains-conf to replace)"
        return 0
    fi
    install -m 644 "$bundled" "$QPROXY_INSTALL_PROXYCHAINS_CONF"
    echo "Installed default proxychains config: $QPROXY_INSTALL_PROXYCHAINS_CONF"
}

qproxy_install() {
    local source_root install_deps=true proxychains_conf=false force_proxychains=false
    local arg

    source_root="$(qproxy_install_source_root)"
    while [ $# -gt 0 ]; do
        case "$1" in
            --no-deps) install_deps=false ;;
            --proxychains-conf) proxychains_conf=true ;;
            --force-proxychains-conf) proxychains_conf=true; force_proxychains=true ;;
            --prefix)
                shift
                QPROXY_INSTALL_PREFIX="${1:?--prefix requires a path}"
                QPROXY_INSTALL_LIB="$QPROXY_INSTALL_PREFIX/lib/qproxy"
                QPROXY_INSTALL_BIN="$QPROXY_INSTALL_PREFIX/bin/qproxy"
                ;;
            -h|--help)
                cat <<EOF
Usage: qproxy install [options]

Install QProxy under $QPROXY_INSTALL_PREFIX (default).

Options:
  --no-deps                  Skip installing dialog, jq, and curl
  --proxychains-conf         Install share/proxychains/proxychains4.conf to /etc if missing
  --force-proxychains-conf   Replace /etc/proxychains4.conf with bundled file
  --prefix PATH              Install under PATH instead of /usr/local
  -h, --help                 Show this help

Examples:
  sudo ./qproxy.sh install
  sudo qproxy install --proxychains-conf
  qproxy install status
EOF
                return 0
                ;;
            *)
                echo "Unknown install option: $1" >&2
                return 1
                ;;
        esac
        shift
    done

    qproxy_install_validate_source "$source_root" || return 1

    echo "Installing QProxy $VERSION ..."
    echo "  from: $source_root"
    echo "  to:   $QPROXY_INSTALL_LIB"
    echo "  bin:  $QPROXY_INSTALL_BIN"

    install -d "$QPROXY_INSTALL_LIB"
    qproxy_install_copy_tree "$source_root"
    qproxy_install_write_version "$source_root"
    qproxy_install_link_command

    if [ "$install_deps" = true ]; then
        echo "Installing runtime dependencies ..."
        install_runtime_deps || echo "Warning: some dependencies could not be installed automatically." >&2
    fi

    if [ "$proxychains_conf" = true ]; then
        qproxy_install_proxychains_conf "$source_root" "$force_proxychains"
    fi

    echo ""
    echo "QProxy installed successfully."
    echo "Run: sudo qproxy"
    qproxy_install_status
}

qproxy_uninstall() {
    echo "Removing QProxy $VERSION ..."
    if [ -L "$QPROXY_INSTALL_BIN" ]; then
        rm -f "$QPROXY_INSTALL_BIN"
        echo "Removed: $QPROXY_INSTALL_BIN"
    elif [ -e "$QPROXY_INSTALL_BIN" ]; then
        echo "Warning: $QPROXY_INSTALL_BIN is not a symlink; not removed automatically." >&2
    fi
    if [ -d "$QPROXY_INSTALL_LIB" ]; then
        rm -rf "$QPROXY_INSTALL_LIB"
        echo "Removed: $QPROXY_INSTALL_LIB"
    fi
    echo "User config files (~/.qproxy.env) were not removed."
    echo "QProxy uninstalled."
}
