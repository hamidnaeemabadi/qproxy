apply_proxy_to_current_session() {
    # Exports apply only inside this script; the user's shell must source the session file
    export HTTP_PROXY="http://$HTTP_HOST:$HTTP_PORT"
    export http_proxy="http://$HTTP_HOST:$HTTP_PORT"
    export HTTPS_PROXY="http://$HTTP_HOST:$HTTP_PORT"
    export https_proxy="http://$HTTP_HOST:$HTTP_PORT"
    export NO_PROXY="$NO_PROXY_HOSTS"
    export no_proxy="$NO_PROXY_HOSTS"
    export HTTP_PROXY_CONNECTION_TIMEOUT="$PROXY_TIMEOUT"
    export HTTP_PROXY_READ_TIMEOUT="$PROXY_READ_TIMEOUT"

    write_http_session_env_file
    apply_session_to_user_shell
}

# Function to set os http proxy

set_os_env_http_proxy() {
    # Check proxy health before setting
    if ! check_proxy_health "http://$HTTP_HOST:$HTTP_PORT"; then
        dialog --title "Warning" --msgbox "Proxy health check failed. Proceeding anyway, but you may experience issues." 7 50
    fi
    
    # Create the persistent configuration file
    cat << EOP > $USER_PROXY_ENV_PATH
export HTTP_PROXY="http://$HTTP_HOST:$HTTP_PORT"
export http_proxy="http://$HTTP_HOST:$HTTP_PORT"
export HTTPS_PROXY="http://$HTTP_HOST:$HTTP_PORT"
export https_proxy="http://$HTTP_HOST:$HTTP_PORT"
export NO_PROXY="$NO_PROXY_HOSTS"
export no_proxy="$NO_PROXY_HOSTS"
export HTTP_PROXY_CONNECTION_TIMEOUT="$PROXY_TIMEOUT"
export HTTP_PROXY_READ_TIMEOUT="$PROXY_READ_TIMEOUT"
EOP
    
    # Apply to current session immediately
    apply_proxy_to_current_session
    
    dialog --title "Success" --msgbox "HTTP Proxy enabled (persistent).\n\nNew shells: /etc/profile.d\nThis terminal: $(session_auto_apply_msg)\n\nPersists after reboot." 11 58
}

# Function to apply SOCKS5 proxy to current session

apply_socks5_proxy_to_current_session() {
    export HTTP_PROXY="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
    export http_proxy="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
    export HTTPS_PROXY="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
    export https_proxy="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
    export NO_PROXY="$NO_PROXY_HOSTS"
    export no_proxy="$NO_PROXY_HOSTS"
    export HTTP_PROXY_CONNECTION_TIMEOUT="$PROXY_TIMEOUT"
    export HTTP_PROXY_READ_TIMEOUT="$PROXY_READ_TIMEOUT"

    write_socks5_session_env_file
    apply_session_to_user_shell
}

# Function to set os socks5 proxy

set_os_env_socks5_proxy() {
    # Check proxy health before setting
    if ! check_proxy_health "socks5h://$SOCKS5_HOST:$SOCKS5_PORT"; then
        dialog --title "Warning" --msgbox "Proxy health check failed. Proceeding anyway, but you may experience issues." 7 50
    fi
    
    # Create the persistent configuration file
    sudo cat << EOP > $USER_PROXY_ENV_PATH
export HTTP_PROXY="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export http_proxy="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export HTTPS_PROXY="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export https_proxy="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export NO_PROXY="$NO_PROXY_HOSTS"
export no_proxy="$NO_PROXY_HOSTS"
export HTTP_PROXY_CONNECTION_TIMEOUT="$PROXY_TIMEOUT"
export HTTP_PROXY_READ_TIMEOUT="$PROXY_READ_TIMEOUT"
EOP
    
    # Apply to current session immediately
    apply_socks5_proxy_to_current_session
    
    dialog --title "Success" --msgbox "SOCKS5 Proxy enabled (persistent).\n\nNew shells: /etc/profile.d\nThis terminal: $(session_auto_apply_msg)\n\nPersists after reboot." 11 58
}

# Function to remove proxy from current session

remove_proxy_from_current_session() {
    unset HTTP_PROXY
    unset http_proxy
    unset HTTPS_PROXY
    unset https_proxy
    unset NO_PROXY
    unset no_proxy
    unset HTTP_PROXY_CONNECTION_TIMEOUT
    unset HTTP_PROXY_READ_TIMEOUT

    write_unset_session_env_file
    apply_session_to_user_shell
}

# Function to disable os proxy

disable_os_env_proxy() {
    # Remove the persistent configuration file
    rm -f $USER_PROXY_ENV_PATH
    
    # Remove from current session immediately
    remove_proxy_from_current_session
    
    dialog --title "Success" --msgbox "Persistent proxy disabled.\n\n$(session_auto_apply_msg)" 9 58
}

# Function to remove apt proxy

