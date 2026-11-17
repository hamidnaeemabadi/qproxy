docker_is_available() {
    command -v docker &>/dev/null
}

docker_darwin_daemon_json() {
    echo "$(get_qproxy_user_home)/.docker/daemon.json"
}

docker_service_restart_linux() {
    if [ -f "/etc/docker/daemon.json" ]; then
        local live_restore docker_info
        live_restore=$(jq -r '.["live-restore"]' /etc/docker/daemon.json)
        if [ "$live_restore" = "true" ]; then
            docker_info=$(docker info 2>/dev/null || true)
            if [[ "$docker_info" == *"Live Restore Enabled: true"* ]]; then
                systemctl daemon-reload
                systemctl restart docker
            else
                systemctl daemon-reload
                echo -e "The Docker service needs to be restarted but Live Restore is not enabled in Docker, please enable Live Recovery otherwise all containers will be restarted and cause the service outages.\nDoc: https://docs.docker.com/config/containers/live-restore/" >&2
            fi
        fi
    fi
}

docker_service_restart_darwin() {
    local qhome
    qhome=$(get_qproxy_user_home)
    if [ -d "/Applications/Docker.app" ] || [ -d "$qhome/Applications/Docker.app" ]; then
        osascript -e 'quit app "Docker"' 2>/dev/null || true
        sleep 2
        if [ "$(id -u)" -eq 0 ]; then
            local quser
            quser=$(get_qproxy_user)
            if [ "$quser" != "root" ]; then
                sudo -u "$quser" open -a Docker 2>/dev/null || open -a Docker 2>/dev/null || true
            else
                open -a Docker 2>/dev/null || true
            fi
        else
            open -a Docker 2>/dev/null || true
        fi
        echo "Docker Desktop restart requested." >&2
    else
        echo "Docker Desktop not found; apply ~/.docker/daemon.json and restart Docker manually." >&2
    fi
}

docker_service_restart() {
    if [ "$(detect_os)" = "darwin" ]; then
        docker_service_restart_darwin
    else
        docker_service_restart_linux
    fi
}

docker_set_proxy_linux() {
    mkdir -p /etc/systemd/system/docker.service.d
    install_template "$QPROXY_TEMPLATES/docker-proxy.conf" /etc/systemd/system/docker.service.d/proxy.conf "$1" || return 1
    mkdir -p /etc/docker
    if [ -f "/etc/docker/daemon.json" ]; then
        cp /etc/docker/daemon.json /etc/docker/daemon.json.backup
        jq '. + {
            "max-concurrent-downloads": 3,
            "max-concurrent-uploads": 5,
            "max-download-attempts": 5,
            "live-restore": true,
            "log-driver": "json-file",
            "log-opts": {
                "max-size": "10m",
                "max-file": "3"
            }
        }' /etc/docker/daemon.json > /tmp/daemon.json && mv /tmp/daemon.json /etc/docker/daemon.json
    else
        install_template "$QPROXY_TEMPLATES/docker-daemon.json" /etc/docker/daemon.json
    fi
    docker_service_restart
}

docker_set_proxy_darwin() {
    local cfg dir tmp http_url
    cfg=$(docker_darwin_daemon_json)
    dir=$(dirname "$cfg")
    mkdir -p "$dir"
    http_url=$(config_http_url)
    tmp=$(mktemp)
    if [ -f "$cfg" ] && [ -s "$cfg" ]; then
        if ! jq -e . "$cfg" >/dev/null 2>&1; then
            echo "docker: invalid JSON in $cfg (backing up)" >&2
            cp "$cfg" "${cfg}.qproxy.bak"
            printf '%s\n' '{}' > "$cfg"
        fi
        jq --arg http "$http_url" --arg https "$http_url" --arg nop "$NO_PROXY_HOSTS" \
            '.proxies = {
                "http-proxy": $http,
                "https-proxy": $https,
                "no-proxy": $nop
            }' "$cfg" > "$tmp"
    else
        jq -n --arg http "$http_url" --arg https "$http_url" --arg nop "$NO_PROXY_HOSTS" \
            '{proxies: {
                "http-proxy": $http,
                "https-proxy": $https,
                "no-proxy": $nop
            }}' > "$tmp"
    fi
    install -m 0644 "$tmp" "$cfg"
    rm -f "$tmp"
    chown_qproxy_user_file "$cfg"
    docker_service_restart
}

docker_set_proxy() {
    local proxy_url
    proxy_url=$(config_proxy_url "${1:-http}") || return 1
    if ! docker_is_available; then
        echo "docker: not found" >&2
        return 1
    fi
    if [ "$(detect_os)" = "darwin" ]; then
        if [ "${1:-http}" != "http" ]; then
            echo "docker: configure SOCKS5 in Docker Desktop Settings > Resources > Proxies; daemon.json proxies are ignored by Desktop." >&2
            return 1
        fi
        docker_set_proxy_darwin
    else
        docker_set_proxy_linux "$proxy_url"
    fi
}

docker_disable_proxy_darwin() {
    local cfg tmp
    cfg=$(docker_darwin_daemon_json)
    if [ ! -f "$cfg" ]; then
        return 2
    fi
    if ! jq -e 'has("proxies")' "$cfg" >/dev/null 2>&1; then
        return 2
    fi
    tmp=$(mktemp)
    jq 'del(.proxies)' "$cfg" > "$tmp"
    install -m 0644 "$tmp" "$cfg"
    rm -f "$tmp"
    chown_qproxy_user_file "$cfg"
    docker_service_restart
    return 0
}

docker_disable_proxy() {
    if ! docker_is_available; then
        echo "docker: not found" >&2
        return 1
    fi
    if [ "$(detect_os)" = "darwin" ]; then
        docker_disable_proxy_darwin
        return $?
    fi
    if [ -f "/etc/systemd/system/docker.service.d/proxy.conf" ]; then
        rm -f /etc/systemd/system/docker.service.d/proxy.conf
        docker_service_restart
        return 0
    fi
    return 2
}

docker_test_proxy() {
    if ! docker_is_available; then
        echo "docker: not found" >&2
        return 1
    fi
    if [ "$(detect_os)" = "darwin" ]; then
        local cfg
        cfg=$(docker_darwin_daemon_json)
        if ! jq -e '.proxies["http-proxy"] | type == "string" and length > 0' "$cfg" >/dev/null 2>&1; then
            echo "docker: daemon.json proxies missing or invalid ($cfg)" >&2
            return 1
        fi
    elif ! grep -q -E 'http://|socks5h://' /etc/systemd/system/docker.service.d/proxy.conf 2>/dev/null; then
        echo "docker: proxy.conf missing or invalid" >&2
        return 1
    fi
    docker search nginx >/dev/null 2>&1
}

# Docker CLI client proxies (~/.docker/config.json)

docker_cli_iter_homes() {
    local name _uid home
    if [ "$(detect_os)" = "darwin" ]; then
        home=$(get_qproxy_user_home)
        [ -n "$home" ] && [ -d "$home" ] && echo "$home"
        return 0
    fi
    echo "/root"
    [ -d /etc/skel ] && echo "/etc/skel"
    getent passwd | while IFS=: read -r name _ _uid _ _ home _; do
        case "$_uid" in
            ''|*[!0-9]*) continue ;;
        esac
        if [ "$_uid" -ge 1000 ] && [ -n "$home" ] && [ -d "$home" ] && [ "$home" != "/root" ]; then
            echo "$home"
        fi
    done
}

docker_cli_owner_for_home() {
    local home="$1" name
    if [ "$(detect_os)" = "darwin" ]; then
        get_qproxy_user
        return
    fi
    if [ "$home" = "/etc/skel" ]; then
        echo "root"
        return
    fi
    name=$(getent passwd | awk -F: -v h="$home" '$6 == h { print $1; exit }')
    if [ -n "$name" ]; then
        echo "$name"
    else
        echo "root"
    fi
}

docker_cli_write_config() {
    local home="$1" http_url="$2" no_proxy="$3"
    local dir="$home/.docker" cfg="$home/.docker/config.json" tmp owner

    mkdir -p "$dir"
    tmp=$(mktemp)
    if [ -f "$cfg" ] && [ -s "$cfg" ]; then
        if ! jq -e . "$cfg" >/dev/null 2>&1; then
            echo "docker-cli: invalid JSON in $cfg (backing up)" >&2
            cp "$cfg" "${cfg}.qproxy.bak"
            printf '%s\n' '{}' > "$cfg"
        fi
        jq --arg http "$http_url" --arg https "$http_url" --arg nop "$no_proxy" \
            '.proxies.default = {
                httpProxy: $http,
                httpsProxy: $https,
                noProxy: $nop
            }' "$cfg" > "$tmp"
    else
        jq -n --arg http "$http_url" --arg https "$http_url" --arg nop "$no_proxy" \
            '{proxies: {default: {
                httpProxy: $http,
                httpsProxy: $https,
                noProxy: $nop
            }}}' > "$tmp"
    fi
    install -m 0644 "$tmp" "$cfg"
    rm -f "$tmp"

    owner=$(docker_cli_owner_for_home "$home")
    if [ "$(id -u)" -eq 0 ] && [ "$owner" != "root" ]; then
        chown -R "$owner:$owner" "$dir" 2>/dev/null || true
    elif [ "$(id -u)" -eq 0 ] && [ "$home" = "/root" ]; then
        chown -R root:root "$dir" 2>/dev/null || true
    fi
}

docker_cli_set_proxy() {
    local http_url home count=0
    http_url=$(config_proxy_url "${1:-http}") || return 1

    while IFS= read -r home; do
        [ -n "$home" ] || continue
        docker_cli_write_config "$home" "$http_url" "$NO_PROXY_HOSTS" || return 1
        count=$((count + 1))
    done < <(docker_cli_iter_homes)

    if [ "$count" -eq 0 ]; then
        echo "docker-cli: no home directories found" >&2
        return 1
    fi
    return 0
}

docker_cli_remove_proxies_from_file() {
    local cfg="$1" tmp
    [ -f "$cfg" ] || return 2
    if ! jq -e 'has("proxies")' "$cfg" >/dev/null 2>&1; then
        return 2
    fi
    tmp=$(mktemp)
    jq 'del(.proxies)' "$cfg" > "$tmp"
    install -m 0644 "$tmp" "$cfg"
    rm -f "$tmp"
    return 0
}

docker_cli_disable_proxy() {
    local home cfg rc=2 removed=0 owner
    while IFS= read -r home; do
        [ -n "$home" ] || continue
        cfg="$home/.docker/config.json"
        docker_cli_remove_proxies_from_file "$cfg"
        rc=$?
        if [ "$rc" -eq 0 ]; then
            removed=$((removed + 1))
            owner=$(docker_cli_owner_for_home "$home")
            if [ "$(id -u)" -eq 0 ] && [ "$owner" != "root" ]; then
                chown "$owner:$owner" "$cfg" 2>/dev/null || true
            fi
        fi
    done < <(docker_cli_iter_homes)

    if [ "$removed" -gt 0 ]; then
        return 0
    fi
    return 2
}

docker_cli_test_proxy() {
    local home cfg found=0
    while IFS= read -r home; do
        [ -n "$home" ] || continue
        cfg="$home/.docker/config.json"
        if [ -f "$cfg" ] && jq -e '.proxies.default.httpProxy | type == "string" and length > 0' "$cfg" >/dev/null 2>&1; then
            found=$((found + 1))
        fi
    done < <(docker_cli_iter_homes)

    if [ "$found" -eq 0 ]; then
        echo "docker-cli: no proxies.default.httpProxy found in user Docker configs" >&2
        return 1
    fi
    echo "docker-cli: found proxies in $found config(s)" >&2
    return 0
}
