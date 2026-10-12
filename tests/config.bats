#!/usr/bin/env bats

load test_helper

setup() {
    qproxy_source_libs
    HTTP_HOST="10.1.2.3"
    HTTP_PORT="3128"
    SOCKS5_HOST="10.4.5.6"
    SOCKS5_PORT="1080"
}

@test "config_http_url builds HTTP proxy URL" {
    [ "$(config_http_url)" = "http://10.1.2.3:3128" ]
}

@test "config_socks5_url builds SOCKS5 proxy URL" {
    [ "$(config_socks5_url)" = "socks5h://10.4.5.6:1080" ]
}

@test "load_qproxy_env_file reads key=value pairs" {
    local env_file
    env_file="$(mktemp)"
    cat > "$env_file" <<EOF
HTTP_HOST="192.168.1.10"
HTTP_PORT="8080"
SOCKS5_HOST="192.168.1.11"
SOCKS5_PORT="1081"
EOF
    load_qproxy_env_file "$env_file"
    [ "$HTTP_HOST" = "192.168.1.10" ]
    [ "$HTTP_PORT" = "8080" ]
    [ "$SOCKS5_HOST" = "192.168.1.11" ]
    [ "$SOCKS5_PORT" = "1081" ]
    rm -f "$env_file"
}

@test "load_qproxy_env_file ignores comments and blank lines" {
    local env_file
    env_file="$(mktemp)"
    cat > "$env_file" <<EOF
# comment
HTTP_HOST=1.2.3.4

HTTP_PORT=9999
EOF
    load_qproxy_env_file "$env_file"
    [ "$HTTP_HOST" = "1.2.3.4" ]
    [ "$HTTP_PORT" = "9999" ]
    rm -f "$env_file"
}

@test "qproxy_resolve_version reads VERSION file" {
    local workdir
    workdir="$(mktemp -d)"
    echo "v2.1.0" > "$workdir/VERSION"
    QPROXY_ROOT="$workdir"
    [ "$(qproxy_resolve_version)" = "v2.1.0" ]
    rm -rf "$workdir"
}

@test "install_template substitutes placeholders" {
    local template out workdir
    workdir="$(mktemp -d)"
    template="$workdir/template.conf"
    out="$workdir/output.conf"
    cat > "$template" <<'EOF'
host=@HTTP_HOST@ port=@HTTP_PORT@
EOF
    install_template "$template" "$out"
    grep -q 'host=10.1.2.3 port=3128' "$out"
    rm -rf "$workdir"
}
