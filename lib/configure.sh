configure_proxy_settings() {
    init_qproxy_config
    dialog --title "Proxy Configuration Setup" \
    --msgbox "Welcome to QProxy Configuration!\n\nThis will help you set up your proxy settings easily.\n\nYou can configure:\n- HTTP Proxy\n- SOCKS5 Proxy\n- Both (for redundancy)\n\nLet's start!" 10 50
    
    # Ask for HTTP Proxy
    dialog --title "HTTP Proxy Configuration" \
    --yesno "Do you want to configure an HTTP Proxy?\n\nHTTP proxies are good for web browsing and most applications." 8 50
    
    if [ $? -eq 0 ]; then
        # Get HTTP Proxy details
        dialog --title "HTTP Proxy Settings" \
        --form "Enter your HTTP Proxy details:" 12 50 0 \
        "HTTP Proxy Host/IP:" 1 1 "$HTTP_HOST" 1 25 20 0 \
        "HTTP Proxy Port:" 2 1 "$HTTP_PORT" 2 25 10 0 2>tempfile
        
        if [ $? -eq 0 ]; then
            read -r new_http_host new_http_port < tempfile
            if [ -n "$new_http_host" ] && [ -n "$new_http_port" ]; then
                HTTP_HOST="$new_http_host"
                HTTP_PORT="$new_http_port"
                save_qproxy_env_file
                dialog --title "Success" --msgbox "HTTP Proxy configured and saved:\nHost: $HTTP_HOST\nPort: $HTTP_PORT\n\nConfig file:\n$QPROXY_ENV_FILE" 9 60
            fi
        fi
    fi
    
    # Ask for SOCKS5 Proxy
    dialog --title "SOCKS5 Proxy Configuration" \
    --yesno "Do you want to configure a SOCKS5 Proxy?\n\nSOCKS5 proxies support more protocols and are more versatile." 8 50
    
    if [ $? -eq 0 ]; then
        # Get SOCKS5 Proxy details
        dialog --title "SOCKS5 Proxy Settings" \
        --form "Enter your SOCKS5 Proxy details:" 12 50 0 \
        "SOCKS5 Proxy Host/IP:" 1 1 "$SOCKS5_HOST" 1 25 20 0 \
        "SOCKS5 Proxy Port:" 2 1 "$SOCKS5_PORT" 2 25 10 0 2>tempfile
        
        if [ $? -eq 0 ]; then
            read -r new_socks5_host new_socks5_port < tempfile
            if [ -n "$new_socks5_host" ] && [ -n "$new_socks5_port" ]; then
                SOCKS5_HOST="$new_socks5_host"
                SOCKS5_PORT="$new_socks5_port"
                save_qproxy_env_file
                dialog --title "Success" --msgbox "SOCKS5 Proxy configured and saved:\nHost: $SOCKS5_HOST\nPort: $SOCKS5_PORT\n\nConfig file:\n$QPROXY_ENV_FILE" 9 60
            fi
        fi
    fi
    
    # Show current configuration
    show_current_configuration
}

# Function to save proxy configuration to the user env file

save_proxy_configuration() {
    save_qproxy_env_file
    dialog --title "Success" --msgbox "Proxy configuration saved to:\n$QPROXY_ENV_FILE\n\nAll proxy actions will use these values." 8 60
}

# Function to show current configuration

show_current_configuration() {
    resolve_qproxy_env_file
    dialog --title "Current Proxy Configuration" \
    --msgbox "Current Proxy Settings:\n\nHTTP Proxy:\n  Host: $HTTP_HOST\n  Port: $HTTP_PORT\n\nSOCKS5 Proxy:\n  Host: $SOCKS5_HOST\n  Port: $SOCKS5_PORT\n\nNO_PROXY Hosts:\n  $NO_PROXY_HOSTS\n\nConfig file:\n  $QPROXY_ENV_FILE" 14 60
}

# Function to test current proxy configuration

test_current_proxy_config() {
    dialog --title "Testing Proxy Configuration" --infobox "Testing your current proxy settings..." 4 50
    
    local test_results=""
    local has_working_proxy=false
    
    # Test HTTP Proxy if configured
    if [ "$HTTP_HOST" != "$DEFAULT_HTTP_HOST" ] || [ "$HTTP_PORT" != "$DEFAULT_HTTP_PORT" ]; then
        if check_proxy_health "http://$HTTP_HOST:$HTTP_PORT"; then
            test_results="$test_results\n✅ HTTP Proxy: WORKING"
            has_working_proxy=true
        else
            test_results="$test_results\n❌ HTTP Proxy: FAILED"
        fi
    else
        test_results="$test_results\n⚪ HTTP Proxy: Not configured"
    fi
    
    # Test SOCKS5 Proxy if configured
    if [ "$SOCKS5_HOST" != "$DEFAULT_SOCKS5_HOST" ] || [ "$SOCKS5_PORT" != "$DEFAULT_SOCKS5_PORT" ]; then
        if check_proxy_health "socks5h://$SOCKS5_HOST:$SOCKS5_PORT"; then
            test_results="$test_results\n✅ SOCKS5 Proxy: WORKING"
            has_working_proxy=true
        else
            test_results="$test_results\n❌ SOCKS5 Proxy: FAILED"
        fi
    else
        test_results="$test_results\n⚪ SOCKS5 Proxy: Not configured"
    fi
    
    if [ "$has_working_proxy" = true ]; then
        dialog --title "Proxy Test Results" --msgbox "Proxy Test Results:$test_results\n\n🎉 You have working proxy servers!" 10 50
    else
        dialog --title "Proxy Test Results" --msgbox "Proxy Test Results:$test_results\n\n⚠️ No working proxies found.\nPlease check your configuration." 10 50
    fi
}

# Function to launch proxychains shell with health testing

