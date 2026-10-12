#!/usr/bin/env bats

load test_helper

setup() {
    qproxy_source_libs
}

@test "qproxy_install_validate_source accepts complete tree" {
    run qproxy_install_validate_source "$(qproxy_test_root)"
    [ "$status" -eq 0 ]
}

@test "qproxy_install_validate_source rejects incomplete tree" {
    local bad
    bad="$(mktemp -d)"
    run qproxy_install_validate_source "$bad"
    [ "$status" -eq 1 ]
    rm -rf "$bad"
}

@test "bundled proxychains reference config exists" {
    [ -f "$(qproxy_test_root)/share/proxychains/proxychains4.conf" ]
}

@test "proxychains documentation exists" {
    [ -f "$(qproxy_test_root)/docs/proxychains-config-guide.md" ]
}

@test "qproxy_install_status reports version" {
    run qproxy_install_status
    [ "$status" -eq 0 ]
    [[ "$output" == *"$VERSION"* ]]
}
