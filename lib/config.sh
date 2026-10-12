# QProxy configuration constants and state
QPROXY_DEFAULT_VERSION="v2.1.0"

# Version: installed VERSION file → git tag → QPROXY_DEFAULT_VERSION
qproxy_resolve_version() {
    local root="${QPROXY_ROOT:-}" ver
    if [ -n "$root" ] && [ -f "$root/VERSION" ]; then
        ver=$(tr -d '[:space:]' < "$root/VERSION")
        [ -n "$ver" ] && { echo "$ver"; return 0; }
    fi
    if [ -n "$root" ] && [ -d "$root/.git" ] && command -v git >/dev/null 2>&1; then
        ver=$(git -C "$root" describe --tags --dirty --always 2>/dev/null)
        [ -n "$ver" ] && { echo "$ver"; return 0; }
    fi
    echo "$QPROXY_DEFAULT_VERSION"
}

VERSION="$(qproxy_resolve_version)"
SCRIPT_NAME="QProxy for Linux $VERSION by Hamid Naeemabadi"

DEFAULT_SOCKS5_HOST="10.X.X.X"
DEFAULT_SOCKS5_PORT="1080"
DEFAULT_HTTP_HOST="10.X.X.X"
DEFAULT_HTTP_PORT="1080"
DEFAULT_NO_PROXY_HOSTS="127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,localhost,*.local"
DEFAULT_PROXY_TIMEOUT=30
DEFAULT_PROXY_READ_TIMEOUT=60

SOCKS5_HOST="$DEFAULT_SOCKS5_HOST"
SOCKS5_PORT="$DEFAULT_SOCKS5_PORT"
HTTP_HOST="$DEFAULT_HTTP_HOST"
HTTP_PORT="$DEFAULT_HTTP_PORT"
NO_PROXY_HOSTS="$DEFAULT_NO_PROXY_HOSTS"
PROXY_TIMEOUT="$DEFAULT_PROXY_TIMEOUT"
PROXY_READ_TIMEOUT="$DEFAULT_PROXY_READ_TIMEOUT"

USER_PROXY_ENV_PATH="/etc/profile.d/user_proxy_env.sh"
PROXYCHAINS_CONF_PATH="/etc/proxychains4.conf"
QPROXY_ENV_FILE=""
QPROXY_SESSION_ENV_FILE=""

config_http_url() { echo "http://${HTTP_HOST}:${HTTP_PORT}"; }
config_socks5_url() { echo "socks5h://${SOCKS5_HOST}:${SOCKS5_PORT}"; }

install_template() {
    local template="$1" dest="$2"
    local tmp content version_tag dest_dir
    tmp=$(mktemp)
    version_tag="${VERSION#v}"
    content=$(<"$template")
    content="${content//@HTTP_HOST@/$HTTP_HOST}"
    content="${content//@HTTP_PORT@/$HTTP_PORT}"
    content="${content//@SOCKS5_HOST@/$SOCKS5_HOST}"
    content="${content//@SOCKS5_PORT@/$SOCKS5_PORT}"
    content="${content//@NO_PROXY_HOSTS@/$NO_PROXY_HOSTS}"
    content="${content//@PROXY_TIMEOUT@/$PROXY_TIMEOUT}"
    content="${content//@PROXY_READ_TIMEOUT@/$PROXY_READ_TIMEOUT}"
    content="${content//@VERSION@/$version_tag}"
    printf '%s' "$content" > "$tmp"
    dest_dir=$(dirname "$dest")
    if [ "$(id -u)" -eq 0 ]; then
        install -m 0644 "$tmp" "$dest"
    elif [ -d "$dest_dir" ] && [ -w "$dest_dir" ] && { [ ! -e "$dest" ] || [ -w "$dest" ]; }; then
        install -m 0644 "$tmp" "$dest"
    else
        sudo install -m 0644 "$tmp" "$dest"
    fi
    rm -f "$tmp"
}

load_qproxy_env_file() {
    local env_file="$1"
    local line key value
    [ -f "$env_file" ] || return 1
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="${line%"${line##*[![:space:]]}"}"
        line="${line#"${line%%[![:space:]]*}"}"
        [ -z "$line" ] && continue
        [[ "$line" != *=* ]] && continue
        key="${line%%=*}"
        value="${line#*=}"
        key="${key%"${key##*[![:space:]]}"}"
        key="${key#"${key%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        case "$key" in
            HTTP_HOST|HTTP_PORT|SOCKS5_HOST|SOCKS5_PORT|NO_PROXY_HOSTS|PROXY_TIMEOUT|PROXY_READ_TIMEOUT)
                eval "$key=\"\$value\""
                ;;
        esac
    done < "$env_file"
    return 0
}

save_qproxy_env_file() {
    local env_file="${1:-$QPROXY_ENV_FILE}"
    local qhome quser
    [ -n "$env_file" ] || return 1
    qhome=$(dirname "$env_file")
    quser=$(get_qproxy_user)
    mkdir -p "$qhome" 2>/dev/null || true
    cat > "$env_file" <<EOF
# QProxy user configuration - managed by qproxy.sh
# Edit HTTP/SOCKS5 host and port here; changes apply on the next script run.
HTTP_HOST="$HTTP_HOST"
HTTP_PORT="$HTTP_PORT"
SOCKS5_HOST="$SOCKS5_HOST"
SOCKS5_PORT="$SOCKS5_PORT"
NO_PROXY_HOSTS="$NO_PROXY_HOSTS"
PROXY_TIMEOUT="$PROXY_TIMEOUT"
PROXY_READ_TIMEOUT="$PROXY_READ_TIMEOUT"
EOF
    chmod 600 "$env_file" 2>/dev/null || true
    if [ "$(id -u)" -eq 0 ] && [ "$quser" != "root" ]; then
        chown "$quser:$quser" "$env_file" 2>/dev/null || true
    fi
}

# Read ~/.qproxy.env on startup; create it from defaults if missing

init_qproxy_config() {
    resolve_qproxy_env_file
    ensure_qproxy_shell_hook_installed
    if [ -f "$QPROXY_ENV_FILE" ]; then
        load_qproxy_env_file "$QPROXY_ENV_FILE"
    else
        save_qproxy_env_file "$QPROXY_ENV_FILE"
    fi
}

# Function to detect Linux distribution

