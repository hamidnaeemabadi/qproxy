ui_has_dialog() {
    command -v dialog &>/dev/null
}

remove_old_apt_proxy() {
    if ! apt_remove_proxy; then
        ui_error "Error" "APT package manager not found!"
        return 1
    fi
    if [ "${1:-}" != "-q" ]; then
        ui_success "Success" "APT proxy disabled successfully!"
    fi
}

set_apt_http_proxy() {
    enable_apt_http_proxy
}

enable_apt_http_proxy() {
    if apt_set_http_proxy; then
        ui_success "Success" "APT HTTP Proxy configured successfully!"
    else
        ui_error "Error" "APT package manager not found!"
        return 1
    fi
}

set_apt_socks5_proxy() {
    enable_apt_socks5_proxy
}

enable_apt_socks5_proxy() {
    if apt_set_socks5_proxy; then
        ui_success "Success" "APT SOCKS5 Proxy configured successfully!"
    else
        ui_error "Error" "APT package manager not found!"
        return 1
    fi
}

test_apt_proxy() {
    if apt_test_proxy; then
        ui_success "Success" "APT Proxy test successful!"
    else
        ui_error "Error" "APT Proxy test failed!"
        return 1
    fi
}
