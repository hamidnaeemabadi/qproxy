menu_configure_proxy() {
    dialog --title "Proxy Configuration" \
    --menu "Choose configuration option:" 10 50 4 \
    1 "Configure Proxy Settings" \
    2 "Show Current Configuration" \
    3 "Test Current Configuration" \
    4 "Back to Main Menu" 2>tempfile

    local config_selection
    config_selection=$(<tempfile)

    case $config_selection in
        1) configure_proxy_settings ;;
        2) init_qproxy_config; show_current_configuration ;;
        3) test_current_proxy_config ;;
        4) return 0 ;;
    esac
}

menu_enable_proxy() {
    if [ "$(detect_os)" = "darwin" ]; then
        dialog --title "Enable Proxy" \
        --checklist "Where you want to set the HTTP/SOCKS5 Proxy:" 14 74 7 \
        1 "Enable HTTP Proxy on OS ENV" off \
        2 "Enable SOCKS5 Proxy on OS ENV" off \
        3 "Enable HTTP Proxy on Homebrew" off \
        4 "Enable HTTP Proxy on Docker Desktop (daemon.json)" off \
        5 "Enable HTTP Proxy on Docker CLI" off \
        6 "Enable SOCKS5H Proxy on Docker Desktop (manual setup)" off \
        7 "Enable SOCKS5H Proxy on Docker CLI" off 2>tempfile
    else
        dialog --title "Enable Proxy" \
        --checklist "Where you want to set the HTTP/SOCKS5 Proxy:" 18 74 10 \
        1 "Enable HTTP Proxy on OS ENV" off \
        2 "Enable SOCKS5 Proxy on OS ENV" off \
        3 "Enable HTTP Proxy on Package Manager (Auto-detect)" off \
        4 "Enable SOCKS5 Proxy on APT (Debian/Ubuntu only)" off \
        5 "Enable HTTP Proxy on Docker Service" off \
        6 "Enable HTTP Proxy on Docker CLI (all users)" off \
        7 "Enable HTTP Proxy on Containerd (K8s) Service" off \
        8 "Enable SOCKS5H Proxy on Docker Service" off \
        9 "Enable SOCKS5H Proxy on Docker CLI (all users)" off \
        10 "Enable SOCKS5H Proxy on Containerd (K8s) Service" off 2>tempfile
    fi

    local selections selection
    selections=$(<tempfile)

    for selection in $selections; do
        if [ "$(detect_os)" = "darwin" ]; then
            case $selection in
                1) set_os_env_http_proxy ;;
                2) set_os_env_socks5_proxy ;;
                3) set_auto_package_manager_proxy ;;
                4) set_docker_proxy ;;
                5) set_docker_cli_proxy ;;
                6) set_docker_proxy socks5h ;;
                7) set_docker_cli_proxy socks5h ;;
            esac
        else
            case $selection in
                1) set_os_env_http_proxy ;;
                2) set_os_env_socks5_proxy ;;
                3) set_auto_package_manager_proxy ;;
                4) set_apt_socks5_proxy ;;
                5) set_docker_proxy ;;
                6) set_docker_cli_proxy ;;
                7) set_containerd_proxy ;;
                8) set_docker_proxy socks5h ;;
                9) set_docker_cli_proxy socks5h ;;
                10) set_containerd_proxy socks5h ;;
            esac
        fi
    done
}

menu_disable_proxy() {
    if [ "$(detect_os)" = "darwin" ]; then
        dialog --title "Disable Proxy" \
        --checklist "Choose the action you want to perform (with space or mouse click):" 14 74 6 \
        1 "Disable HTTP/SOCKS5 Proxy on OS ENV" off \
        2 "Disable HTTP Proxy on Homebrew" off \
        3 "Disable QProxy Docker Desktop config (manual proxy: Settings)" off \
        4 "Disable HTTP/SOCKS5H Proxy on Docker CLI" off \
        5 "Disable HTTP/SOCKS5 Completely" off 2>tempfile
    else
        dialog --title "Disable Proxy" \
        --checklist "Choose the action you want to perform (with space or mouse click):" 15 74 8 \
        1 "Disable HTTP/SOCKS5 Proxy on OS ENV" off \
        2 "Disable HTTP Proxy on Package Manager (Auto-detect)" off \
        3 "Disable HTTP/SOCKS5 Proxy on APT" off \
        4 "Disable HTTP/SOCKS5H Proxy on Docker Service" off \
        5 "Disable HTTP/SOCKS5H Proxy on Docker CLI (all users)" off \
        6 "Disable HTTP/SOCKS5H Proxy on Containerd (K8s) Service" off \
        7 "Disable HTTP/SOCKS5 Completely" off 2>tempfile
    fi

    local selections selection
    selections=$(<tempfile)

    for selection in $selections; do
        if [ "$(detect_os)" = "darwin" ]; then
            case $selection in
                1) disable_os_env_proxy ;;
                2) remove_auto_package_manager_proxy ;;
                3) disable_docker_proxy ;;
                4) disable_docker_cli_proxy ;;
                5)
                    disable_os_env_proxy
                    remove_auto_package_manager_proxy
                    disable_docker_proxy
                    disable_docker_cli_proxy
                    ;;
            esac
        else
            case $selection in
                1) disable_os_env_proxy ;;
                2) remove_auto_package_manager_proxy ;;
                3) remove_old_apt_proxy ;;
                4) disable_docker_proxy ;;
                5) disable_docker_cli_proxy ;;
                6) disable_containerd_proxy ;;
                7)
                    disable_os_env_proxy
                    remove_auto_package_manager_proxy
                    disable_docker_proxy
                    disable_docker_cli_proxy
                    disable_containerd_proxy
                    ;;
            esac
        fi
    done
}

menu_test_proxy_performance() {
    dialog --title "Proxy Performance Test" \
    --menu "Choose proxy to test:" 10 50 3 \
    1 "HTTP Proxy Performance" \
    2 "SOCKS5 Proxy Performance" 2>tempfile

    local perf_selection
    perf_selection=$(<tempfile)
    case $perf_selection in
        1) test_proxy_performance "http://$HTTP_HOST:$HTTP_PORT" | dialog --title "HTTP Proxy Performance" --programbox 20 80 ;;
        2) test_proxy_performance "socks5h://$SOCKS5_HOST:$SOCKS5_PORT" | dialog --title "SOCKS5 Proxy Performance" --programbox 20 80 ;;
    esac
}

menu_test_proxy_health() {
    dialog --title "Proxy Health Test" \
    --menu "Choose proxy to test:" 10 50 3 \
    1 "HTTP Proxy Health" \
    2 "SOCKS5 Proxy Health" 2>tempfile

    local health_selection
    health_selection=$(<tempfile)
    case $health_selection in
        1)
            if check_proxy_health "http://$HTTP_HOST:$HTTP_PORT"; then
                dialog --title "Success" --msgbox "HTTP Proxy health check passed!" 6 50
            else
                dialog --title "Error" --msgbox "HTTP Proxy health check failed!" 6 50
            fi
            ;;
        2)
            if check_proxy_health "socks5h://$SOCKS5_HOST:$SOCKS5_PORT"; then
                dialog --title "Success" --msgbox "SOCKS5 Proxy health check passed!" 6 50
            else
                dialog --title "Error" --msgbox "SOCKS5 Proxy health check failed!" 6 50
            fi
            ;;
    esac
}

menu_test_proxies() {
    if [ "$(detect_os)" = "darwin" ]; then
        dialog --title "Test Proxies" \
        --menu "Choose the action you want to test:" 14 70 8 \
        1 "Test OS Proxy" \
        2 "Test Docker Desktop Proxy" \
        3 "Test Docker CLI Proxy" \
        4 "Test Homebrew Proxy" \
        5 "Test Proxy Performance" \
        6 "Test Proxy Health" 2>tempfile
    else
        dialog --title "Test Proxies" \
        --menu "Choose the action you want to test:" 15 70 10 \
        1 "Test OS Proxy" \
        2 "Test Docker Service Proxy" \
        3 "Test Docker CLI Proxy" \
        4 "Test Package Manager Proxy (Auto-detect)" \
        5 "Test APT Proxy (Debian/Ubuntu only)" \
        6 "Test Proxy Performance" \
        7 "Test Proxy Health" 2>tempfile
    fi

    local test_selection
    test_selection=$(<tempfile)

    if [ "$(detect_os)" = "darwin" ]; then
        case $test_selection in
            1) test_os_env_proxy ;;
            2) test_docker_proxy ;;
            3) test_docker_cli_proxy ;;
            4) test_auto_package_manager_proxy ;;
            5) menu_test_proxy_performance ;;
            6) menu_test_proxy_health ;;
        esac
    else
        case $test_selection in
            1) test_os_env_proxy ;;
            2) test_docker_proxy ;;
            3) test_docker_cli_proxy ;;
            4) test_auto_package_manager_proxy ;;
            5) test_apt_proxy ;;
            6) menu_test_proxy_performance ;;
            7) menu_test_proxy_health ;;
        esac
    fi
}

menu_proxychains() {
    if ! proxychains_is_available; then
        dialog --title "Proxychains Not Available" \
        --yesno "Proxychains is not installed on your system.\n\nProxychains is required for proxy chain functionality.\n\nWould you like to install it now?" 10 60

        if [ $? -eq 0 ]; then
            if ! check_and_install_proxychains; then
                return 0
            fi
        else
            local tip="apt install proxychains4"
            [ "$(detect_os)" = "darwin" ] && tip="brew install proxychains-ng"
            dialog --title "Info" --msgbox "Proxychains installation cancelled.\n\nYou can install it later with:\n$tip" 8 50
            return 0
        fi
    fi

    dialog --title "Configure Proxychains" \
    --menu "Choose the proxychains configuration:" 14 70 7 \
    1 "Configure HTTP Proxy in Proxychains" \
    2 "Configure SOCKS5 Proxy in Proxychains" \
    3 "Configure Dual Proxy (HTTP + SOCKS5)" \
    4 "Disable Proxychains Configuration" \
    5 "Test Proxychains Configuration" \
    6 "Launch Proxychains Shell" 2>tempfile

    local proxychains_selection
    proxychains_selection=$(<tempfile)

    case $proxychains_selection in
        1) set_proxychains_http_proxy ;;
        2) set_proxychains_socks5_proxy ;;
        3) set_proxychains_dual_proxy ;;
        4) disable_proxychains_config ;;
        5) test_proxychains_config ;;
        6) launch_proxychains_shell ;;
    esac
}

menu_session_apply() {
    dialog --title "Apply Proxy to Current Session" \
    --menu "Choose proxy type to apply to current session:" 10 50 3 \
    1 "Apply HTTP Proxy to Current Session" \
    2 "Apply SOCKS5 Proxy to Current Session" \
    3 "Remove Proxy from Current Session" 2>tempfile

    local session_selection
    session_selection=$(<tempfile)

    case $session_selection in
        1)
            apply_proxy_to_current_session
            finalize_qproxy_session_apply
            dialog --title "Success" --msgbox "HTTP Proxy applied.\n\n$(session_auto_apply_msg)\n\nTemporary until you close this shell." 10 58
            ;;
        2)
            apply_socks5_proxy_to_current_session
            finalize_qproxy_session_apply
            dialog --title "Success" --msgbox "SOCKS5 Proxy applied.\n\n$(session_auto_apply_msg)\n\nTemporary until you close this shell." 10 58
            ;;
        3)
            remove_proxy_from_current_session
            finalize_qproxy_session_apply
            dialog --title "Success" --msgbox "Proxy removed from session.\n\n$(session_auto_apply_msg)" 9 58
            ;;
    esac
}

main_loop() {
    local title_os="Linux"
    [ "$(detect_os)" = "darwin" ] && title_os="macOS"
    while true; do
        dialog --title "Manage the proxy configs on $title_os and services quickly" \
        --backtitle "$SCRIPT_NAME" \
        --menu "Choose the action you want to perform (with space or mouse click):" 14 70 10 \
        1 "Configure Proxy Settings" \
        2 "Enable Proxy" \
        3 "Disable Proxy" \
        4 "Test Proxies" \
        5 "Configure Proxychains" \
        6 "Apply Proxy to Current Session" \
        7 "Exit" 2>tempfile

        local selection
        selection=$(<tempfile)

        case $selection in
            1) menu_configure_proxy ;;
            2) menu_enable_proxy ;;
            3) menu_disable_proxy ;;
            4) menu_test_proxies ;;
            5) menu_proxychains ;;
            6) menu_session_apply ;;
            7) echo "Exiting..."; break ;;
        esac
    done
}

main() {
    init_qproxy_config
    check_deps
    main_loop
    finalize_qproxy_session_apply
    clear
    rm -f tempfile
}
