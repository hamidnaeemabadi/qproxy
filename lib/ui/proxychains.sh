set_proxychains_http_proxy() {
    if ! check_and_install_proxychains; then
        return 1
    fi
    proxychains_set_http_proxy
    ui_success "Success" "Proxychains HTTP Proxy configured successfully!"
}

set_proxychains_socks5_proxy() {
    if ! check_and_install_proxychains; then
        return 1
    fi
    proxychains_set_socks5_proxy
    ui_success "Success" "Proxychains SOCKS5 Proxy configured successfully!"
}

set_proxychains_dual_proxy() {
    if ! check_and_install_proxychains; then
        return 1
    fi
    proxychains_set_dual_proxy
    ui_success "Success" "Proxychains Dual Proxy configured successfully!"
}

disable_proxychains_config() {
    local rc
    proxychains_disable_config
    rc=$?
    case $rc in
        0) ui_success "Success" "Proxychains configuration disabled successfully!" ;;
        2) ui_info "Info" "No proxychains configuration found." ;;
        *) ui_error "Error" "Failed to disable proxychains configuration."; return 1 ;;
    esac
}

test_proxychains_config() {
    local test_result
    if ! check_and_install_proxychains; then
        return 1
    fi
    echo "Testing proxychains configuration..."
    echo "Configuration file: $PROXYCHAINS_CONF_PATH"
    echo ""
    if test_result=$(proxychains_test_config); then
        echo "Proxychains test successful!"
        echo "Response: $test_result"
        ui_success "Success" "Proxychains test successful!"
    else
        echo "Proxychains test failed!" >&2
        ui_error "Error" "Proxychains test failed!\n\nPlease check your proxy configuration."
        return 1
    fi
}

launch_proxychains_shell() {
    local test_result
    if ! check_and_install_proxychains; then
        return 1
    fi
    if [ ! -f "$PROXYCHAINS_CONF_PATH" ]; then
        ui_error "Error" "Proxychains configuration file not found!\n\nPlease configure proxychains first."
        return 1
    fi
    dialog --title "Testing Proxy Health" --infobox "Testing proxy server health before launching shell..." 4 50
    if grep -q "http.*$HTTP_HOST.*$HTTP_PORT" "$PROXYCHAINS_CONF_PATH" 2>/dev/null; then
        if ! check_proxy_health "http://$HTTP_HOST:$HTTP_PORT"; then
            ui_error "Error" "HTTP Proxy health check failed!\n\nCannot launch proxychains shell with unhealthy proxy."
            return 1
        fi
    fi
    if grep -q "socks5.*$SOCKS5_HOST.*$SOCKS5_PORT" "$PROXYCHAINS_CONF_PATH" 2>/dev/null; then
        if ! check_proxy_health "socks5h://$SOCKS5_HOST:$SOCKS5_PORT"; then
            ui_error "Error" "SOCKS5 Proxy health check failed!\n\nCannot launch proxychains shell with unhealthy proxy."
            return 1
        fi
    fi
    dialog --title "Testing Proxychains" --infobox "Testing proxychains connectivity..." 4 50
    if test_result=$(proxychains_test_config); then
        dialog --title "Success" --msgbox "Proxy health check passed!\n\nLaunching proxychains shell..." 6 50
        clear
        echo "=========================================="
        echo "  Proxychains Shell Launched"
        echo "=========================================="
        echo "Proxy health check: PASSED"
        echo "Proxychains test: PASSED"
        echo "All network traffic will go through proxy"
        echo "Type 'exit' to return to QProxy"
        echo "=========================================="
        echo ""
        exec proxychains4 bash
    else
        ui_error "Error" "Proxychains test failed!\n\nCannot launch shell with non-functional proxy."
        return 1
    fi
}
