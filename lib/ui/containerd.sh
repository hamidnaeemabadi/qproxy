set_containerd_http_proxy() {
    if containerd_set_http_proxy; then
        ui_success "Success" "Containerd HTTP Proxy configured successfully!"
    else
        ui_error "Error" "Containerd not found!"
        return 1
    fi
}

disable_containerd_proxy() {
    local rc
    if ! containerd_is_available; then
        ui_error "Error" "Containerd not found!"
        return 1
    fi
    containerd_disable_proxy
    rc=$?
    case $rc in
        0) ui_success "Success" "Containerd proxy disabled successfully!" ;;
        2) ui_info "Info" "No containerd proxy configuration found." ;;
        *) ui_error "Error" "Failed to disable containerd proxy."; return 1 ;;
    esac
}

test_containerd_proxy() {
    if ! containerd_is_available; then
        ui_error "Error" "Containerd could not be found. Please install containerd first."
        return 1
    fi
    if containerd_test_proxy; then
        ui_success "Success" "Containerd Proxy test successful!"
    else
        ui_error "Error" "Containerd Proxy test failed!"
        return 1
    fi
}
