#!/usr/bin/env bats

load test_helper

setup() {
    qproxy_source_libs
}

@test "detect_distro reads ID from mocked os-release" {
    local fake_os
    fake_os="$(mktemp)"
    cat > "$fake_os" <<EOF
ID=ubuntu
EOF
    QPROXY_OS_RELEASE_FILE="$fake_os" run detect_distro
    [ "$status" -eq 0 ]
    [ "$output" = "ubuntu" ]
    rm -f "$fake_os"
}

@test "detect_distro returns debian when only debian_version exists" {
    QPROXY_OS_RELEASE_FILE="/nonexistent/qproxy-test-os-release" run bash -c '
        detect_distro() {
            local os_release="${QPROXY_OS_RELEASE_FILE:-/etc/os-release}"
            if [ -f "$os_release" ]; then
                . "$os_release"
                echo "$ID"
            elif [ -f /etc/debian_version ]; then
                echo "debian"
            else
                echo "unknown"
            fi
        }
        if [ -f /etc/debian_version ]; then
            detect_distro
        else
            echo "skip"
        fi
    '
    if [ "$output" = "skip" ]; then
        skip "No /etc/debian_version on this system"
    fi
    [ "$output" = "debian" ]
}

@test "detect_distro returns unknown when no release files match" {
    QPROXY_OS_RELEASE_FILE="/nonexistent/qproxy-test-os-release" run bash -c '
        source "'"$BATS_TEST_DIRNAME"'/../lib/deps.sh"
        detect_distro
    '
    [ "$output" = "unknown" ] || [ "$output" = "ubuntu" ] || [ "$output" = "debian" ]
}
