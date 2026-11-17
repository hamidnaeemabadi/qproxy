cli_usage() {
    local os_label="Linux/macOS"
    cat <<EOF
QProxy $VERSION — $os_label proxy management

Usage:
  qproxy                              Interactive TUI (default)
  qproxy install [options]            Install QProxy system-wide
  qproxy install status               Show install location / status
  qproxy uninstall                    Remove system-wide install
  qproxy completion bash|zsh          Generate shell completion script
  qproxy completion install           Install Bash and Zsh completions
  qproxy config show                  Show current proxy configuration
  qproxy enable <target> [type]       Enable proxy on a target
  qproxy disable <target>             Disable proxy on a target
  qproxy test <check> [type]          Run proxy tests

Targets (enable/disable):
  os-env          System environment (Linux: /etc/profile.d; macOS: brew/etc/qproxy + zprofile)
  apt             APT package manager (Debian/Ubuntu; Linux only)
  pkgmgr          Auto-detect package manager (Homebrew on macOS)
  docker          Docker service (systemd on Linux; Docker Desktop daemon.json on macOS)
  docker-cli      Docker CLI config.json (all users on Linux; current user on macOS)
  containerd      Containerd systemd service (Linux only)
  proxychains     Proxychains (http|socks5|dual)

Types:
  enable os-env http|socks5
  enable apt http|socks5
  enable docker|docker-cli|containerd http|socks5h
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

# Returns 0 if root is required for this CLI invocation
cli_needs_root() {
    local cmd="${1:-}" target="${2:-}"
    case "$cmd" in
        install|uninstall) return 0 ;;
        config) return 1 ;;
        enable|disable)
            case "$target" in
                docker-cli) return 1 ;;
                docker)
                    [ "$(detect_os)" = "darwin" ] && return 1
                    return 0
                    ;;
                *) return 0 ;;
            esac
            ;;
        test)
            case "$target" in
                health|docker-cli) return 1 ;;
                docker)
                    [ "$(detect_os)" = "darwin" ] && return 1
                    return 0
                    ;;
                *) return 0 ;;
            esac
            ;;
        *) return 0 ;;
    esac
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
OS: $(detect_os) / $(detect_distro)
OS env path: $USER_PROXY_ENV_PATH
Proxychains: $PROXYCHAINS_CONF_PATH
EOF
}

cli_enable() {
    local target="${1:-}" ptype="${2:-http}"
    case "$target" in
        os-env)
            case "$ptype" in
                http)
                    write_os_env_http_file
                    apply_proxy_to_current_session
                    echo "OS environment HTTP proxy enabled."
                    ;;
                socks5)
                    write_os_env_socks5_file
                    apply_socks5_proxy_to_current_session
                    echo "OS environment SOCKS5 proxy enabled."
                    ;;
                *) echo "Unknown type: $ptype (use http or socks5)" >&2; return 1 ;;
            esac
            ;;
        apt)
            if [ "$(detect_os)" = "darwin" ]; then
                echo "apt: not available on macOS (use pkgmgr / Homebrew)" >&2
                return 1
            fi
            case "$ptype" in
                http) apt_set_http_proxy && echo "APT HTTP proxy enabled." ;;
                socks5) apt_set_socks5_proxy && echo "APT SOCKS5 proxy enabled." ;;
                *) echo "Unknown type: $ptype (use http or socks5)" >&2; return 1 ;;
            esac
            ;;
        pkgmgr) pkgmgr_set_http_proxy && echo "Package manager HTTP proxy enabled." ;;
        docker) docker_set_proxy "$ptype" && echo "Docker $ptype proxy enabled." ;;
        docker-cli)
            docker_cli_set_proxy "$ptype" && echo "Docker CLI $ptype proxy enabled."
            ;;
        containerd)
            if [ "$(detect_os)" = "darwin" ]; then
                echo "containerd: not supported on macOS (use Docker Desktop)" >&2
                return 1
            fi
            containerd_set_proxy "$ptype" && echo "Containerd $ptype proxy enabled."
            ;;
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
        apt)
            if [ "$(detect_os)" = "darwin" ]; then
                echo "apt: not available on macOS" >&2
                return 1
            fi
            apt_remove_proxy && echo "APT proxy disabled."
            ;;
        pkgmgr) pkgmgr_remove_http_proxy && echo "Package manager proxy disabled." ;;
        docker) docker_disable_proxy && echo "Docker proxy disabled." ;;
        docker-cli) docker_cli_disable_proxy && echo "Docker CLI proxy disabled." ;;
        containerd)
            if [ "$(detect_os)" = "darwin" ]; then
                echo "containerd: not supported on macOS" >&2
                return 1
            fi
            containerd_disable_proxy && echo "Containerd proxy disabled."
            ;;
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
        apt)
            if [ "$(detect_os)" = "darwin" ]; then
                echo "apt: not available on macOS" >&2
                return 1
            fi
            apt_test_proxy
            ;;
        pkgmgr) pkgmgr_test_http_proxy ;;
        docker) docker_test_proxy ;;
        docker-cli) docker_cli_test_proxy ;;
        containerd)
            if [ "$(detect_os)" = "darwin" ]; then
                echo "containerd: not supported on macOS" >&2
                return 1
            fi
            containerd_test_proxy
            ;;
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
        completion)
            case "${2:-}" in
                bash|zsh) qproxy_completion_generate "$2" ;;
                install)
                    cli_require_root "$@"
                    qproxy_completion_install
                    ;;
                -h|--help) echo 'Usage: qproxy completion bash|zsh|install' ;;
                *) echo 'Usage: qproxy completion bash|zsh|install' >&2; return 1 ;;
            esac
            ;;
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
            if cli_needs_root "$1" "${2:-}"; then
                cli_require_root "$@"
            fi
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
