get_qproxy_user() {
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        echo "$SUDO_USER"
    else
        echo "${USER:-root}"
    fi
}

get_qproxy_user_home() {
    local quser qhome
    quser=$(get_qproxy_user)
    if [ "$quser" = "root" ]; then
        if [ "$(detect_os 2>/dev/null || uname -s)" = "darwin" ] || [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
            echo "${HOME:-/var/root}"
        else
            echo "${HOME:-/root}"
        fi
        return 0
    fi
    qhome=$(getent passwd "$quser" 2>/dev/null | cut -d: -f6)
    if [ -z "$qhome" ] && command -v dscl >/dev/null 2>&1; then
        qhome=$(dscl . -read "/Users/$quser" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
    fi
    if [ -z "$qhome" ]; then
        qhome=$(eval echo "~$quser" 2>/dev/null)
    fi
    if [ -n "$qhome" ] && [ -d "$qhome" ]; then
        echo "$qhome"
    else
        echo "${HOME:-/root}"
    fi
}

resolve_qproxy_env_file() {
    QPROXY_ENV_FILE="$(get_qproxy_user_home)/.qproxy.env"
}

resolve_qproxy_session_env_file() {
    QPROXY_SESSION_ENV_FILE="$(get_qproxy_user_home)/.qproxy.session.env"
}

resolve_qproxy_session_pending_file() {
    echo "$(get_qproxy_user_home)/.qproxy.session.pending"
}

QPROXY_HOOK_MARKER_START='# >>> QProxy session auto-apply START >>>'

# Own user-owned dotfiles when running under sudo

chown_qproxy_user_file() {
    local f="$1" quser
    [ -n "$f" ] || return 0
    [ -e "$f" ] || return 0
    quser=$(get_qproxy_user)
    chmod 600 "$f" 2>/dev/null || true
    if [ "$(id -u)" -eq 0 ] && [ "$quser" != "root" ]; then
        chown "$quser:$quser" "$f" 2>/dev/null || true
    fi
}

chown_qproxy_session_env_file() {
    chown_qproxy_user_file "$QPROXY_SESSION_ENV_FILE"
}

# Walk the process tree to find the interactive shell that launched QProxy

