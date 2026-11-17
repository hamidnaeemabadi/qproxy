CONTAINERD_PROXY_CONF="/etc/systemd/system/containerd.service.d/proxy.conf"

containerd_is_available() {
    command -v containerd &>/dev/null
}

containerd_unsupported_on_darwin() {
    if [ "$(detect_os)" = "darwin" ]; then
        echo "containerd: not supported on macOS (use Docker Desktop)" >&2
        return 0
    fi
    return 1
}

containerd_set_proxy() {
    local proxy_url
    proxy_url=$(config_proxy_url "${1:-http}") || return 1
    if containerd_unsupported_on_darwin; then
        return 1
    fi
    if ! containerd_is_available; then
        echo "containerd: not found" >&2
        return 1
    fi
    mkdir -p /etc/systemd/system/containerd.service.d
    install_template "$QPROXY_TEMPLATES/containerd-proxy.conf" "$CONTAINERD_PROXY_CONF" "$proxy_url" || return 1
    systemctl daemon-reload
    systemctl restart containerd
}

containerd_disable_proxy() {
    if containerd_unsupported_on_darwin; then
        return 1
    fi
    if ! containerd_is_available; then
        echo "containerd: not found" >&2
        return 1
    fi
    if [ -f "$CONTAINERD_PROXY_CONF" ]; then
        rm -f "$CONTAINERD_PROXY_CONF"
        systemctl daemon-reload
        systemctl restart containerd
        return 0
    fi
    return 2
}

containerd_test_proxy() {
    if containerd_unsupported_on_darwin; then
        return 1
    fi
    if ! containerd_is_available; then
        echo "containerd: not found" >&2
        return 1
    fi
    if ! grep -q -E 'http://|socks5h://' "$CONTAINERD_PROXY_CONF" 2>/dev/null; then
        echo "containerd: proxy.conf missing or invalid" >&2
        return 1
    fi
    ctr images pull docker.io/library/alpine:latest >/dev/null 2>&1
}
