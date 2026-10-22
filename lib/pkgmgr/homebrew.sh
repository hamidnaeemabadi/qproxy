homebrew_is_available() {
    command -v brew >/dev/null 2>&1 || [ -x /opt/homebrew/bin/brew ] || [ -x /usr/local/bin/brew ]
}

homebrew_proxy_env_path() {
    local prefix
    prefix=$(qproxy_brew_prefix) || return 1
    echo "${prefix}/etc/qproxy-homebrew-proxy.env.sh"
}

ensure_homebrew_profile_hooks() {
    local dest env_file fragment
    env_file=$(homebrew_proxy_env_path) || return 1
    fragment=$(cat <<EOF

$QPROXY_BREW_ENV_MARKER_START
[ -f "$env_file" ] && . "$env_file"
$QPROXY_BREW_ENV_MARKER_END
EOF
)
    for dest in /etc/zprofile /etc/profile; do
        if [ ! -f "$dest" ]; then
            touch "$dest" 2>/dev/null || true
        fi
        if [ -f "$dest" ] && ! grep -qF "$QPROXY_BREW_ENV_MARKER_START" "$dest" 2>/dev/null; then
            printf '%s\n' "$fragment" >> "$dest"
        fi
    done
}

remove_homebrew_profile_hooks() {
    local dest tmp
    for dest in /etc/zprofile /etc/profile; do
        [ -f "$dest" ] || continue
        grep -qF "$QPROXY_BREW_ENV_MARKER_START" "$dest" 2>/dev/null || continue
        tmp=$(mktemp)
        awk -v start="$QPROXY_BREW_ENV_MARKER_START" -v end="$QPROXY_BREW_ENV_MARKER_END" '
            $0 == start { skip=1; next }
            $0 == end { skip=0; next }
            !skip { print }
        ' "$dest" > "$tmp" && cat "$tmp" > "$dest"
        rm -f "$tmp"
    done
}

homebrew_write_proxy_env() {
    local env_file dir http_url
    env_file=$(homebrew_proxy_env_path) || {
        echo "homebrew: brew prefix not found" >&2
        return 1
    }
    dir=$(dirname "$env_file")
    mkdir -p "$dir"
    http_url=$(config_http_url)
    cat > "$env_file" <<EOF
# QProxy Homebrew proxy — managed by qproxy
export HTTP_PROXY="$http_url"
export http_proxy="$http_url"
export HTTPS_PROXY="$http_url"
export https_proxy="$http_url"
export ALL_PROXY="$http_url"
export all_proxy="$http_url"
export NO_PROXY="$NO_PROXY_HOSTS"
export no_proxy="$NO_PROXY_HOSTS"
EOF
    chmod 644 "$env_file" 2>/dev/null || true
    ensure_homebrew_profile_hooks
}

homebrew_set_http_proxy() {
    if ! homebrew_is_available; then
        echo "homebrew: brew not found" >&2
        return 1
    fi
    if ! check_proxy_health "$(config_http_url)" 2>/dev/null; then
        true
    fi
    homebrew_write_proxy_env
}

set_homebrew_http_proxy() {
    if ! homebrew_set_http_proxy; then
        ui_error "Error" "Failed to configure Homebrew proxy.\n\nIs Homebrew installed?"
        return 1
    fi
    ui_info "Success" "Homebrew HTTP proxy enabled.\n\nEnv file: $(homebrew_proxy_env_path)\nNew shells pick this up via /etc/zprofile and /etc/profile."
}

homebrew_remove_http_proxy() {
    local env_file
    env_file=$(homebrew_proxy_env_path 2>/dev/null) || true
    if [ -n "$env_file" ] && [ -f "$env_file" ]; then
        rm -f "$env_file"
        remove_homebrew_profile_hooks
        return 0
    fi
    remove_homebrew_profile_hooks
    return 2
}

remove_old_homebrew_proxy() {
    local quiet="${1:-}"
    if homebrew_remove_http_proxy; then
        [ "$quiet" = "-q" ] || ui_info "Success" "Homebrew proxy configuration removed."
        return 0
    fi
    [ "$quiet" = "-q" ] || ui_info "Info" "No Homebrew proxy configuration found."
    return 0
}

homebrew_test_http_proxy() {
    local env_file http_url
    env_file=$(homebrew_proxy_env_path) || {
        echo "homebrew: brew prefix not found" >&2
        return 1
    }
    if [ ! -f "$env_file" ]; then
        echo "homebrew: proxy env file missing ($env_file)" >&2
        return 1
    fi
    # shellcheck source=/dev/null
    . "$env_file"
    http_url=$(config_http_url)
    if curl -x "$http_url" -s --connect-timeout "${PROXY_TIMEOUT:-30}" --max-time "${PROXY_READ_TIMEOUT:-60}" \
        -o /dev/null -w "%{http_code}" http://httpbin.org/status/200 | grep -q 200; then
        echo "homebrew: proxy OK via $http_url"
        return 0
    fi
    echo "homebrew: proxy test failed" >&2
    return 1
}

test_homebrew_proxy() {
    local result
    if result=$(homebrew_test_http_proxy 2>&1); then
        ui_info "Success" "Homebrew proxy test passed.\n\n$result"
        return 0
    fi
    ui_error "Error" "Homebrew proxy test failed.\n\n$result"
    return 1
}
