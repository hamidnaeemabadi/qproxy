#!/usr/bin/env bash
# Shared helpers for QProxy bats tests

qproxy_test_root() {
    cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd
}

qproxy_source_libs() {
    local root
    root="$(qproxy_test_root)"
    # shellcheck source=/dev/null
    source "$root/qproxy.sh"
}
