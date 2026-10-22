#!/usr/bin/env bats

load test_helper

setup() {
    qproxy_source_libs
}

@test "qproxy_brew_prefix returns a path when brew exists" {
    if ! command -v brew >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/brew ] && [ ! -x /usr/local/bin/brew ]; then
        skip "Homebrew not installed"
    fi
    run qproxy_brew_prefix
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [ -d "$output" ]
}

@test "homebrew_proxy_env_path is under brew prefix" {
    if [ "$(detect_os)" != "darwin" ]; then
        skip "Darwin-only"
    fi
    if ! qproxy_brew_prefix >/dev/null 2>&1; then
        skip "Homebrew not installed"
    fi
    run homebrew_proxy_env_path
    [ "$status" -eq 0 ]
    [[ "$output" == *"/etc/qproxy-homebrew-proxy.env.sh" ]]
}

@test "pkgmgr facade routes macos to homebrew helpers" {
    if [ "$(detect_os)" != "darwin" ]; then
        skip "Darwin-only"
    fi
    # Smoke: functions exist and are callable (may fail without writable brew etc — that is OK for existence)
    type homebrew_set_http_proxy >/dev/null
    type homebrew_remove_http_proxy >/dev/null
    type homebrew_test_http_proxy >/dev/null
}

@test "containerd refuses on darwin" {
    if [ "$(detect_os)" != "darwin" ]; then
        skip "Darwin-only"
    fi
    run containerd_set_http_proxy
    [ "$status" -ne 0 ]
    [[ "$output" == *"not supported on macOS"* ]] || [[ "$stderr" == *"not supported on macOS"* ]]
}

@test "qproxy_now_ms returns a number" {
    run qproxy_now_ms
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
}

@test "proxychains_bin succeeds or fails cleanly" {
    if proxychains_bin >/dev/null 2>&1; then
        run proxychains_bin
        [ "$status" -eq 0 ]
        [[ "$output" == "proxychains4" || "$output" == "proxychains" ]]
    else
        run proxychains_bin
        [ "$status" -ne 0 ]
    fi
}
