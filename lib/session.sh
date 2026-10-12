QPROXY_HOOK_MARKER_START='# >>> QProxy session auto-apply START >>>'

find_invoking_shell_pid() {
    local quser pid owner comm
    quser=$(get_qproxy_user)
    pid=$(ps -o ppid= -p $$ 2>/dev/null | tr -d ' ')
    while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
        owner=$(ps -o user= -p "$pid" 2>/dev/null | tr -d ' ')
        comm=$(ps -o comm= -p "$pid" 2>/dev/null | sed 's/^-//')
        case "$comm" in
            bash|zsh|sh|fish|dash)
                if [ "$owner" = "$quser" ]; then
                    echo "$pid"
                    return 0
                fi
                ;;
        esac
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    done
    return 1
}

find_invoking_shell_tty() {
    local pid tty
    pid=$(find_invoking_shell_pid) || return 1
    tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
    case "$tty" in
        ?|??)
            echo "/dev/$tty"
            return 0
            ;;
    esac
    return 1
}

ensure_qproxy_shell_hook_installed() {
    local qhome quser bashrc zshrc
    qhome=$(get_qproxy_user_home)
    quser=$(get_qproxy_user)
    bashrc="$qhome/.bashrc"
    zshrc="$qhome/.zshrc"

    if [ ! -f "$bashrc" ]; then
        touch "$bashrc"
        chown_qproxy_user_file "$bashrc"
    fi
    if ! grep -qF "$QPROXY_HOOK_MARKER_START" "$bashrc" 2>/dev/null; then
        cat >> "$bashrc" <<'EOF'

# >>> QProxy session auto-apply START >>>
__qproxy_session_auto_apply() {
    [ -f "${HOME}/.qproxy.session.pending" ] || return 0
    [ -f "${HOME}/.qproxy.session.env" ] && . "${HOME}/.qproxy.session.env"
    rm -f "${HOME}/.qproxy.session.pending"
}
if [[ $- == *i* ]] && [[ "${PROMPT_COMMAND:-}" != *__qproxy_session_auto_apply* ]]; then
    PROMPT_COMMAND="__qproxy_session_auto_apply${PROMPT_COMMAND:+;${PROMPT_COMMAND}}"
fi
# <<< QProxy session auto-apply END <<<
EOF
        chown_qproxy_user_file "$bashrc"
    fi

    if [ -f "$zshrc" ]; then
        if ! grep -qF "$QPROXY_HOOK_MARKER_START" "$zshrc" 2>/dev/null; then
            cat >> "$zshrc" <<'EOF'

# >>> QProxy session auto-apply START >>>
__qproxy_session_auto_apply() {
    [ -f "${HOME}/.qproxy.session.pending" ] || return 0
    [ -f "${HOME}/.qproxy.session.env" ] && . "${HOME}/.qproxy.session.env"
    rm -f "${HOME}/.qproxy.session.pending"
}
if [[ -o interactive ]] && [[ "${precmd_functions[*]:-}" != *__qproxy_session_auto_apply* ]]; then
    precmd_functions+=(__qproxy_session_auto_apply)
fi
# <<< QProxy session auto-apply END <<<
EOF
            chown_qproxy_user_file "$zshrc"
        fi
    fi
}

mark_session_apply_pending() {
    local pending
    pending=$(resolve_qproxy_session_pending_file)
    : > "$pending"
    chown_qproxy_user_file "$pending"
}

inject_source_into_invoking_shell() {
    local shell_pid session_file quser cmd pending
    resolve_qproxy_session_env_file
    pending=$(resolve_qproxy_session_pending_file)
    [ -f "$pending" ] || return 1
    session_file="$QPROXY_SESSION_ENV_FILE"
    [ -f "$session_file" ] || return 1
    shell_pid=$(find_invoking_shell_pid) || return 1
    quser=$(get_qproxy_user)
    cmd="source $(printf '%q' "$session_file")"

    if [ ! -r "/proc/$shell_pid/fd/0" ]; then
        return 1
    fi

    if [ "$(id -u)" -eq 0 ] && [ "$quser" != "root" ]; then
        if echo "$cmd" | sudo -u "$quser" tee "/proc/$shell_pid/fd/0" >/dev/null 2>&1; then
            rm -f "$pending"
            return 0
        fi
    elif echo "$cmd" > "/proc/$shell_pid/fd/0" 2>/dev/null; then
        rm -f "$pending"
        return 0
    fi
    return 1
}

apply_session_to_user_shell() {
    ensure_qproxy_shell_hook_installed
    mark_session_apply_pending
    inject_source_into_invoking_shell || true
}

finalize_qproxy_session_apply() {
    local pending
    pending=$(resolve_qproxy_session_pending_file)
    [ -f "$pending" ] || return 0
    inject_source_into_invoking_shell || true
}

session_auto_apply_msg() {
    echo "Proxy settings will be applied automatically in your shell when you return to the prompt (usually right after you exit QProxy)."
}

write_http_session_env_file() {
    resolve_qproxy_session_env_file
    cat > "$QPROXY_SESSION_ENV_FILE" <<EOF
# QProxy temporary session proxy (applied automatically by shell hook)
export HTTP_PROXY="http://$HTTP_HOST:$HTTP_PORT"
export http_proxy="http://$HTTP_HOST:$HTTP_PORT"
export HTTPS_PROXY="http://$HTTP_HOST:$HTTP_PORT"
export https_proxy="http://$HTTP_HOST:$HTTP_PORT"
export NO_PROXY="$NO_PROXY_HOSTS"
export no_proxy="$NO_PROXY_HOSTS"
export HTTP_PROXY_CONNECTION_TIMEOUT="$PROXY_TIMEOUT"
export HTTP_PROXY_READ_TIMEOUT="$PROXY_READ_TIMEOUT"
EOF
    chown_qproxy_session_env_file
}

write_socks5_session_env_file() {
    resolve_qproxy_session_env_file
    cat > "$QPROXY_SESSION_ENV_FILE" <<EOF
# QProxy temporary session proxy (applied automatically by shell hook)
export HTTP_PROXY="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export http_proxy="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export HTTPS_PROXY="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export https_proxy="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export NO_PROXY="$NO_PROXY_HOSTS"
export no_proxy="$NO_PROXY_HOSTS"
export HTTP_PROXY_CONNECTION_TIMEOUT="$PROXY_TIMEOUT"
export HTTP_PROXY_READ_TIMEOUT="$PROXY_READ_TIMEOUT"
EOF
    chown_qproxy_session_env_file
}

write_unset_session_env_file() {
    resolve_qproxy_session_env_file
    cat > "$QPROXY_SESSION_ENV_FILE" <<'EOF'
# QProxy - remove temporary session proxy (applied automatically by shell hook)
unset HTTP_PROXY http_proxy HTTPS_PROXY https_proxy NO_PROXY no_proxy
unset HTTP_PROXY_CONNECTION_TIMEOUT HTTP_PROXY_READ_TIMEOUT
EOF
    chown_qproxy_session_env_file
}
