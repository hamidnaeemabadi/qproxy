CONTAINERD_PROXY_CONF="/etc/systemd/system/containerd.service.d/proxy.conf"

containerd_is_available() {
    command -v containerd &>/dev/null
}

containerd_set_http_proxy() {
    if ! containerd_is_available; then
        echo "containerd: not found" >&2
        return 1
    fi
    mkdir -p /etc/systemd/system/containerd.service.d
    if [ -f "$CONTAINERD_PROXY_CONF" ]; then
        rm -f "$CONTAINERD_PROXY_CONF"
    fi
    install_template "$QPROXY_TEMPLATES/containerd-proxy.conf" "$CONTAINERD_PROXY_CONF"
    systemctl daemon-reload
    systemctl restart containerd
}

containerd_disable_proxy() {
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
    if ! containerd_is_available; then
        echo "containerd: not found" >&2
        return 1
    fi
    if ! grep -q 'http://' "$CONTAINERD_PROXY_CONF" 2>/dev/null; then
        echo "containerd: proxy.conf missing or invalid" >&2
        return 1
    fi
    ctr images pull docker.io/library/alpine:latest >/dev/null 2>&1
}
