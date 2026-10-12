set_docker_http_proxy() {
    if docker_set_http_proxy; then
        ui_success "Success" "Docker HTTP Proxy configured successfully!"
    else
        ui_error "Error" "Docker not found!"
        return 1
    fi
}

disable_docker_proxy() {
    local rc=0
    if ! docker_is_available; then
        ui_error "Error" "Docker not found!"
        return 1
    fi
    docker_disable_proxy
    rc=$?
    case $rc in
        0) ui_success "Success" "Docker proxy disabled successfully!" ;;
        2) ui_info "Info" "No Docker proxy configuration found." ;;
        *) ui_error "Error" "Failed to disable Docker proxy."; return 1 ;;
    esac
}

test_docker_proxy() {
    if ! docker_is_available; then
        ui_error "Error" "Docker could not be found. Please install Docker first."
        return 1
    fi
    if docker_test_proxy; then
        ui_success "Success" "Docker Proxy test successful!"
    else
        ui_error "Error" "Docker Proxy test failed!"
        return 1
    fi
}

set_docker_cli_http_proxy() {
    if docker_cli_set_http_proxy; then
        ui_success "Success" "Docker CLI HTTP Proxy configured for all users!"
    else
        ui_error "Error" "Failed to configure Docker CLI proxy!"
        return 1
    fi
}

disable_docker_cli_proxy() {
    local rc=0
    docker_cli_disable_proxy
    rc=$?
    case $rc in
        0) ui_success "Success" "Docker CLI proxy disabled for all users!" ;;
        2) ui_info "Info" "No Docker CLI proxy configuration found." ;;
        *) ui_error "Error" "Failed to disable Docker CLI proxy."; return 1 ;;
    esac
}

test_docker_cli_proxy() {
    if docker_cli_test_proxy; then
        ui_success "Success" "Docker CLI Proxy config found!"
    else
        ui_error "Error" "Docker CLI Proxy config not found!"
        return 1
    fi
}
