#!/usr/bin/env bats

load test_helper

setup() {
    qproxy_source_libs
    HTTP_HOST="10.1.2.3"
    HTTP_PORT="3128"
    SOCKS5_HOST="10.4.5.6"
    SOCKS5_PORT="1080"
    NO_PROXY_HOSTS="localhost,127.0.0.1"
    docker_cli_iter_homes() { echo "$BATS_TEST_TMPDIR"; }
    docker_cli_owner_for_home() { echo root; }
    docker_is_available() { return 0; }
    containerd_is_available() { return 0; }
}

@test "Docker CLI switches HTTP to SOCKS5H and disables without losing other settings" {
    mkdir -p "$BATS_TEST_TMPDIR/.docker"
    local cfg="$BATS_TEST_TMPDIR/.docker/config.json"
    echo '{"credsStore":"test","proxies":{"tcp://other":{"noProxy":"example.com"}}}' > "$cfg"
    cli_enable docker-cli
    jq -e '.proxies.default.httpProxy == "http://10.1.2.3:3128"' "$cfg"
    cli_enable docker-cli socks5h
    jq -e '.credsStore == "test" and
        .proxies["tcp://other"].noProxy == "example.com" and
        .proxies.default.httpProxy == "socks5h://10.4.5.6:1080" and
        .proxies.default.httpsProxy == "socks5h://10.4.5.6:1080" and
        .proxies.default.noProxy == "localhost,127.0.0.1"' "$cfg"
    cli_disable docker-cli
    jq -e '.credsStore == "test" and (has("proxies") | not)' "$cfg"
}

@test "service templates render selected SOCKS5H URL with HTTP as the default" {
    local template proxy_url out="$BATS_TEST_TMPDIR/proxy.conf"
    for template in docker-proxy.conf containerd-proxy.conf; do
        proxy_url=$(config_proxy_url socks5h)
        install_template "$QPROXY_TEMPLATES/$template" "$out" "$proxy_url"
        grep -Fq 'HTTP_PROXY=socks5h://10.4.5.6:1080' "$out"
        grep -Fq 'HTTPS_PROXY=socks5h://10.4.5.6:1080' "$out"
        grep -Fq 'NO_PROXY=localhost,127.0.0.1' "$out"
        install_template "$QPROXY_TEMPLATES/$template" "$out"
        grep -Fq 'HTTP_PROXY=http://10.1.2.3:3128' "$out"
    done
}

@test "Docker Linux dispatch supplies selected URL without restarting a real service" {
    detect_os() { echo linux; }
    docker_set_proxy_linux() { printf '%s' "$1" > "$BATS_TEST_TMPDIR/url"; }
    cli_enable docker socks5h
    [ "$(cat "$BATS_TEST_TMPDIR/url")" = "socks5h://10.4.5.6:1080" ]
    cli_enable docker
    [ "$(cat "$BATS_TEST_TMPDIR/url")" = "http://10.1.2.3:3128" ]
}

@test "containerd writes tests and disables SOCKS5H with system calls stubbed" {
    detect_os() { echo linux; }
    mkdir() { :; }
    systemctl() { echo "$*" >> "$BATS_TEST_TMPDIR/systemctl"; }
    ctr() { echo "$*" > "$BATS_TEST_TMPDIR/ctr"; }
    CONTAINERD_PROXY_CONF="$BATS_TEST_TMPDIR/proxy.conf"
    cli_enable containerd socks5h
    grep -Fq 'HTTP_PROXY=socks5h://10.4.5.6:1080' "$CONTAINERD_PROXY_CONF"
    containerd_test_proxy
    grep -Fq 'images pull docker.io/library/alpine:latest' "$BATS_TEST_TMPDIR/ctr"
    cli_disable containerd
    [ ! -e "$CONTAINERD_PROXY_CONF" ]
    [ "$(grep -c 'restart containerd' "$BATS_TEST_TMPDIR/systemctl")" -eq 2 ]
}

@test "unknown types fail before writing configuration" {
    local target
    for target in docker docker-cli containerd; do
        run cli_enable "$target" invalid
        [ "$status" -ne 0 ]
        [[ "$output" == *"Unknown type"* ]]
    done
    [ ! -e "$BATS_TEST_TMPDIR/.docker/config.json" ]
}

@test "SOCKS5 alias resolves to SOCKS5H" {
    [ "$(config_proxy_url socks5)" = "socks5h://10.4.5.6:1080" ]
}

@test "Docker Desktop SOCKS5H refuses ignored daemon configuration" {
    detect_os() { echo darwin; }
    docker_set_proxy_darwin() { touch "$BATS_TEST_TMPDIR/written"; }
    run cli_enable docker socks5h
    [ "$status" -ne 0 ]
    [[ "$output" == *"Docker Desktop Settings"* ]]
    [ ! -e "$BATS_TEST_TMPDIR/written" ]
}

@test "TUI routes Linux SOCKS5H enable options to all three targets" {
    cd "$BATS_TEST_TMPDIR"
    detect_os() { echo linux; }
    dialog() { echo '8 9 10' >&2; }
    set_docker_proxy() { echo "docker $1" >> calls; }
    set_docker_cli_proxy() { echo "docker-cli $1" >> calls; }
    set_containerd_proxy() { echo "containerd $1" >> calls; }
    menu_enable_proxy
    [ "$(cat calls)" = "$(printf 'docker socks5h\ndocker-cli socks5h\ncontainerd socks5h')" ]
}

@test "TUI routes macOS SOCKS5H options and shared disable actions" {
    cd "$BATS_TEST_TMPDIR"
    detect_os() { echo darwin; }
    dialog() { echo '6 7' >&2; }
    set_docker_proxy() { echo "docker $1" >> calls; }
    set_docker_cli_proxy() { echo "docker-cli $1" >> calls; }
    menu_enable_proxy
    [ "$(cat calls)" = "$(printf 'docker socks5h\ndocker-cli socks5h')" ]
    dialog() { echo '3 4' >&2; }
    disable_docker_proxy() { echo docker >> disabled; }
    disable_docker_cli_proxy() { echo docker-cli >> disabled; }
    menu_disable_proxy
    [ "$(cat disabled)" = "$(printf 'docker\ndocker-cli')" ]
}
