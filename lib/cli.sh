cli_usage() {
    cat <<EOF
QProxy $VERSION — Linux proxy management

Usage:
  qproxy                              Interactive TUI (default)
  qproxy install [options]            Install QProxy system-wide
  qproxy install status               Show install location / status
  qproxy uninstall                    Remove system-wide install
  qproxy config show                  Show current proxy configuration
  qproxy enable <target> [type]       Enable proxy on a target
  qproxy disable <target>             Disable proxy on a target
  qproxy test <check> [type]          Run proxy tests

Targets (enable/disable):
  os-env          System environment (/etc/profile.d)
  apt             APT package manager (Debian/Ubuntu)
  pkgmgr          Auto-detect package manager for this distro
  docker          Docker systemd service
  docker-cli      Docker CLI config.json for all users (+ /etc/skel)
  containerd      Containerd systemd service
  proxychains     Proxychains (http|socks5|dual)

Types:
  enable os-env http|socks5
  enable apt http|socks5
  enable proxychains http|socks5|dual
  test health http|socks5
  test pkgmgr|apt|docker|docker-cli|containerd|proxychains

Examples:
  sudo ./qproxy.sh install
  qproxy install status
  qproxy config show
  qproxy enable os-env http
  qproxy enable docker-cli
  qproxy disable docker
  qproxy disable docker-cli
  qproxy test health http
EOF
}

cli_require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: root privileges required (try: sudo qproxy $*)" >&2
        exit 1
    fi
}

cli_config_show() {
    resolve_qproxy_env_file
    cat <<EOF
HTTP Proxy:  $HTTP_HOST:$HTTP_PORT
SOCKS5 Proxy: $SOCKS5_HOST:$SOCKS5_PORT
NO_PROXY: $NO_PROXY_HOSTS
Timeouts: connect=${PROXY_TIMEOUT}s read=${PROXY_READ_TIMEOUT}s
Config file: $QPROXY_ENV_FILE
HTTP URL: $(config_http_url)
SOCKS5 URL: $(config_socks5_url)
EOF
}

cli_enable() {
    local target="${1:-}" ptype="${2:-http}"
    case "$target" in
        os-env)
            case "$ptype" in
                http) apply_proxy_to_current_session; write_http_session_env_file; cat > "$USER_PROXY_ENV_PATH" <<EOF
export HTTP_PROXY="$(config_http_url)"
export http_proxy="$(config_http_url)"
export HTTPS_PROXY="$(config_http_url)"
export https_proxy="$(config_http_url)"
export NO_PROXY="$NO_PROXY_HOSTS"
export no_proxy="$NO_PROXY_HOSTS"
export HTTP_PROXY_CONNECTION_TIMEOUT="$PROXY_TIMEOUT"
export HTTP_PROXY_READ_TIMEOUT="$PROXY_READ_TIMEOUT"
EOF
                    echo "OS environment HTTP proxy enabled." ;;
                socks5) apply_socks5_proxy_to_current_session; cat > "$USER_PROXY_ENV_PATH" <<EOF
export HTTP_PROXY="$(config_socks5_url)"
export http_proxy="$(config_socks5_url)"
export HTTPS_PROXY="$(config_socks5_url)"
export https_proxy="$(config_socks5_url)"
export NO_PROXY="$NO_PROXY_HOSTS"
export no_proxy="$NO_PROXY_HOSTS"
export HTTP_PROXY_CONNECTION_TIMEOUT="$PROXY_TIMEOUT"
export HTTP_PROXY_READ_TIMEOUT="$PROXY_READ_TIMEOUT"
EOF
                    echo "OS environment SOCKS5 proxy enabled." ;;
                *) echo "Unknown type: $ptype (use http or socks5)" >&2; return 1 ;;
            esac
            ;;
        apt)
            case "$ptype" in
                http) apt_set_http_proxy && echo "APT HTTP proxy enabled." ;;
                socks5) apt_set_socks5_proxy && echo "APT SOCKS5 proxy enabled." ;;
                *) echo "Unknown type: $ptype (use http or socks5)" >&2; return 1 ;;
            esac
            ;;
        pkgmgr) pkgmgr_set_http_proxy && echo "Package manager HTTP proxy enabled." ;;
        docker) docker_set_http_proxy && echo "Docker HTTP proxy enabled." ;;
        docker-cli) docker_cli_set_http_proxy && echo "Docker CLI HTTP proxy enabled for all users." ;;
        containerd) containerd_set_http_proxy && echo "Containerd HTTP proxy enabled." ;;
        proxychains)
            case "$ptype" in
                http) proxychains_set_http_proxy && echo "Proxychains HTTP proxy enabled." ;;
                socks5) proxychains_set_socks5_proxy && echo "Proxychains SOCKS5 proxy enabled." ;;
                dual) proxychains_set_dual_proxy && echo "Proxychains dual proxy enabled." ;;
                *) echo "Unknown type: $ptype (use http, socks5, or dual)" >&2; return 1 ;;
            esac
            ;;
        *) cli_usage; return 1 ;;
    esac
}

cli_disable() {
    local target="${1:-}"
    case "$target" in
        os-env) rm -f "$USER_PROXY_ENV_PATH"; remove_proxy_from_current_session; echo "OS environment proxy disabled." ;;
        apt) apt_remove_proxy && echo "APT proxy disabled." ;;
        pkgmgr) pkgmgr_remove_http_proxy && echo "Package manager proxy disabled." ;;
        docker) docker_disable_proxy && echo "Docker proxy disabled." ;;
        docker-cli) docker_cli_disable_proxy && echo "Docker CLI proxy disabled." ;;
        containerd) containerd_disable_proxy && echo "Containerd proxy disabled." ;;
        proxychains) proxychains_disable_config && echo "Proxychains proxy disabled." ;;
        *) cli_usage; return 1 ;;
    esac
}

cli_test() {
    local check="${1:-}" ptype="${2:-http}"
    case "$check" in
        health)
            case "$ptype" in
                http) check_proxy_health "$(config_http_url)" ;;
                socks5) check_proxy_health "$(config_socks5_url)" ;;
                *) echo "Unknown type: $ptype (use http or socks5)" >&2; return 1 ;;
            esac
            ;;
        apt) apt_test_proxy ;;
        pkgmgr) pkgmgr_test_http_proxy ;;
        docker) docker_test_proxy ;;
        docker-cli) docker_cli_test_proxy ;;
        containerd) containerd_test_proxy ;;
        proxychains) proxychains_test_config ;;
        *) cli_usage; return 1 ;;
    esac
}

cli_main() {
    if [ $# -eq 0 ]; then
        init_qproxy_config
        main
        return
    fi

    case "${1:-}" in
        -h|--help|help) cli_usage ;;
        install)
            case "${2:-}" in
                status) qproxy_install_status ;;
                -h|--help) qproxy_install --help ;;
                *)
                    cli_require_root "$@"
                    init_qproxy_config
                    qproxy_install "${@:2}"
                    ;;
            esac
            ;;
        uninstall)
            cli_require_root "$@"
            qproxy_uninstall
            ;;
        config)
            init_qproxy_config
            case "${2:-}" in
                show) cli_config_show ;;
                *) cli_usage; return 1 ;;
            esac
            ;;
        *)
            cli_require_root "$@"
            init_qproxy_config
            case "${1:-}" in
                enable) shift; cli_enable "$@" ;;
                disable) shift; cli_disable "$@" ;;
                test) shift; cli_test "$@" ;;
                *) cli_usage; return 1 ;;
            esac
            ;;
    esac
}
