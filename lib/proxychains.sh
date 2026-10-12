proxychains_is_available() {
    command -v proxychains4 &>/dev/null
}

proxychains_backup_config() {
    if [ -f "$PROXYCHAINS_CONF_PATH" ]; then
        cp "$PROXYCHAINS_CONF_PATH" "${PROXYCHAINS_CONF_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "Backed up existing proxychains configuration"
    fi
}

proxychains_install_config() {
    local template="$1"
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
    local test_result
    if [ ! -f "$PROXYCHAINS_CONF_PATH" ]; then
        echo "proxychains: configuration file not found" >&2
        return 1
    fi
    test_result=$(proxychains4 curl -s --connect-timeout 10 --max-time 15 http://httpbin.org/ip 2>&1)
    if [ $? -eq 0 ] && [[ "$test_result" == *"origin"* ]]; then
        echo "$test_result"
        return 0
    fi
    echo "$test_result" >&2
    return 1
}
