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

ensure_os_env_profile_hooks() {
    [ "$(detect_os)" = "darwin" ] || return 0
    local dest dir fragment
    dir=$(dirname "$USER_PROXY_ENV_PATH")
    mkdir -p "$dir"
    fragment=$(cat <<EOF

$QPROXY_OS_ENV_MARKER_START
[ -f "$USER_PROXY_ENV_PATH" ] && . "$USER_PROXY_ENV_PATH"
$QPROXY_OS_ENV_MARKER_END
EOF
)
    for dest in /etc/zprofile /etc/profile; do
        if [ ! -f "$dest" ]; then
            touch "$dest" 2>/dev/null || true
        fi
        if [ -f "$dest" ] && ! grep -qF "$QPROXY_OS_ENV_MARKER_START" "$dest" 2>/dev/null; then
            printf '%s\n' "$fragment" >> "$dest"
        fi
    done
}

os_env_persist_msg() {
    if [ "$(detect_os)" = "darwin" ]; then
        echo "New shells: /etc/zprofile + /etc/profile (source $USER_PROXY_ENV_PATH)"
    else
        echo "New shells: /etc/profile.d"
    fi
}

write_os_env_http_file() {
    local dir
    dir=$(dirname "$USER_PROXY_ENV_PATH")
    mkdir -p "$dir"
    ensure_os_env_profile_hooks
    cat << EOP > "$USER_PROXY_ENV_PATH"
export HTTP_PROXY="http://$HTTP_HOST:$HTTP_PORT"
export http_proxy="http://$HTTP_HOST:$HTTP_PORT"
export HTTPS_PROXY="http://$HTTP_HOST:$HTTP_PORT"
export https_proxy="http://$HTTP_HOST:$HTTP_PORT"
export NO_PROXY="$NO_PROXY_HOSTS"
export no_proxy="$NO_PROXY_HOSTS"
export HTTP_PROXY_CONNECTION_TIMEOUT="$PROXY_TIMEOUT"
export HTTP_PROXY_READ_TIMEOUT="$PROXY_READ_TIMEOUT"
EOP
}

write_os_env_socks5_file() {
    local dir
    dir=$(dirname "$USER_PROXY_ENV_PATH")
    mkdir -p "$dir"
    ensure_os_env_profile_hooks
    cat << EOP > "$USER_PROXY_ENV_PATH"
export HTTP_PROXY="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export http_proxy="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export HTTPS_PROXY="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export https_proxy="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export NO_PROXY="$NO_PROXY_HOSTS"
export no_proxy="$NO_PROXY_HOSTS"
export HTTP_PROXY_CONNECTION_TIMEOUT="$PROXY_TIMEOUT"
export HTTP_PROXY_READ_TIMEOUT="$PROXY_READ_TIMEOUT"
EOP
}

# Function to set os http proxy

set_os_env_http_proxy() {
    # Check proxy health before setting
    if ! check_proxy_health "http://$HTTP_HOST:$HTTP_PORT"; then
        dialog --title "Warning" --msgbox "Proxy health check failed. Proceeding anyway, but you may experience issues." 7 50
    fi

    write_os_env_http_file

    # Apply to current session immediately
    apply_proxy_to_current_session

    dialog --title "Success" --msgbox "HTTP Proxy enabled (persistent).\n\n$(os_env_persist_msg)\nThis terminal: $(session_auto_apply_msg)\n\nPersists after reboot." 12 62
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

    write_os_env_socks5_file

    # Apply to current session immediately
    apply_socks5_proxy_to_current_session

    dialog --title "Success" --msgbox "SOCKS5 Proxy enabled (persistent).\n\n$(os_env_persist_msg)\nThis terminal: $(session_auto_apply_msg)\n\nPersists after reboot." 12 62
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
    rm -f "$USER_PROXY_ENV_PATH"

    # Remove from current session immediately
    remove_proxy_from_current_session

    dialog --title "Success" --msgbox "Persistent proxy disabled.\n\n$(session_auto_apply_msg)" 9 58
}
