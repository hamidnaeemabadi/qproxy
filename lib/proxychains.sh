proxychains_is_available() {
    proxychains_bin >/dev/null 2>&1
}

proxychains_cmd() {
    proxychains_bin
}

proxychains_backup_config() {
    if [ -f "$PROXYCHAINS_CONF_PATH" ]; then
        cp "$PROXYCHAINS_CONF_PATH" "${PROXYCHAINS_CONF_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "Backed up existing proxychains configuration"
    fi
}

proxychains_install_config() {
    local template="$1" dest_dir
    dest_dir=$(dirname "$PROXYCHAINS_CONF_PATH")
    mkdir -p "$dest_dir"
    proxychains_backup_config
    install_template "$template" "$PROXYCHAINS_CONF_PATH"
}

proxychains_set_http_proxy() {
    proxychains_install_config "$QPROXY_TEMPLATES/proxychains-http.conf"
}

proxychains_set_socks5_proxy() {
    proxychains_install_config "$QPROXY_TEMPLATES/proxychains-socks5.conf"
}

proxychains_set_dual_proxy() {
    proxychains_install_config "$QPROXY_TEMPLATES/proxychains-dual.conf"
}

proxychains_disable_config() {
    if [ ! -f "$PROXYCHAINS_CONF_PATH" ]; then
        return 2
    fi
    proxychains_install_config "$QPROXY_TEMPLATES/proxychains-default.conf"
}

proxychains_test_config() {
    local test_result pc
    if [ ! -f "$PROXYCHAINS_CONF_PATH" ]; then
        echo "proxychains: configuration file not found" >&2
        return 1
    fi
    pc=$(proxychains_cmd) || {
        echo "proxychains: binary not found" >&2
        return 1
    }
    test_result=$("$pc" curl -s --connect-timeout 10 --max-time 15 http://httpbin.org/ip 2>&1)
    if [ $? -eq 0 ] && [[ "$test_result" == *"origin"* ]]; then
        echo "$test_result"
        return 0
    fi
    echo "$test_result" >&2
    return 1
}
