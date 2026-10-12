# Pure APT package-manager logic (no dialog)

apt_is_available() {
    command -v apt &>/dev/null
}

apt_remove_proxy() {
    local files
    if ! apt_is_available; then
        echo "apt: package manager not found" >&2
        return 1
    fi
    files=$(grep -irl "proxy" /etc/apt/ 2>/dev/null || true)
    if [ -n "$files" ]; then
        echo "$files" | xargs rm -f
    fi
    apt clean >/dev/null 2>&1
    apt autoclean >/dev/null 2>&1
}

apt_set_http_proxy() {
    if ! apt_is_available; then
        echo "apt: package manager not found" >&2
        return 1
    fi
    apt_remove_proxy || return 1
    install_template "$QPROXY_TEMPLATES/apt_proxy_http.conf" /etc/apt/apt.conf.d/apt_proxy_http
}

apt_set_socks5_proxy() {
    if ! apt_is_available; then
        echo "apt: package manager not found" >&2
        return 1
    fi
    apt_remove_proxy || return 1
    install_template "$QPROXY_TEMPLATES/apt_proxy_socks5.conf" /etc/apt/apt.conf.d/apt_proxy_socks5
}

apt_test_proxy() {
    if ! apt_is_available; then
        echo "apt: package manager not found" >&2
        return 1
    fi
    apt clean >/dev/null 2>&1 && apt autoclean >/dev/null 2>&1 && apt update -qq >/dev/null 2>&1
}
