pkgmgr_set_http_proxy() {
    case "$(detect_distro)" in
        ubuntu|debian|linuxmint|pop|elementary) apt_set_http_proxy ;;
        fedora|rhel|centos|rocky|almalinux|oracle) set_dnf_http_proxy ;;
        arch|manjaro|endeavouros) set_pacman_http_proxy ;;
        opensuse|sles) set_zypper_http_proxy ;;
        *)
            echo "Unsupported distribution: $(detect_distro)" >&2
            return 1
            ;;
    esac
}

pkgmgr_remove_http_proxy() {
    case "$(detect_distro)" in
        ubuntu|debian|linuxmint|pop|elementary) apt_remove_proxy ;;
        fedora|rhel|centos|rocky|almalinux|oracle) remove_old_dnf_proxy -q ;;
        arch|manjaro|endeavouros) remove_old_pacman_proxy -q ;;
        opensuse|sles) remove_old_zypper_proxy -q ;;
        *)
            echo "Unsupported distribution: $(detect_distro)" >&2
            return 1
            ;;
    esac
}

pkgmgr_test_http_proxy() {
    case "$(detect_distro)" in
        ubuntu|debian|linuxmint|pop|elementary) apt_test_proxy ;;
        fedora|rhel|centos|rocky|almalinux|oracle) test_dnf_proxy ;;
        arch|manjaro|endeavouros) test_pacman_proxy ;;
        opensuse|sles) test_zypper_proxy ;;
        *)
            echo "Unsupported distribution: $(detect_distro)" >&2
            return 1
            ;;
    esac
}

set_auto_package_manager_proxy() {
    case "$(detect_distro)" in
        ubuntu|debian|linuxmint|pop|elementary) enable_apt_http_proxy ;;
        fedora|rhel|centos|rocky|almalinux|oracle) set_dnf_http_proxy ;;
        arch|manjaro|endeavouros) set_pacman_http_proxy ;;
        opensuse|sles) set_zypper_http_proxy ;;
        *)
            ui_error "Unsupported Distribution" "Your Linux distribution ($(detect_distro)) is not supported for automatic package manager proxy configuration.\n\nPlease configure your package manager proxy manually."
            return 1
            ;;
    esac
}

remove_auto_package_manager_proxy() {
    case "$(detect_distro)" in
        ubuntu|debian|linuxmint|pop|elementary) remove_old_apt_proxy ;;
        fedora|rhel|centos|rocky|almalinux|oracle) remove_old_dnf_proxy ;;
        arch|manjaro|endeavouros) remove_old_pacman_proxy ;;
        opensuse|sles) remove_old_zypper_proxy ;;
        *)
            ui_error "Unsupported Distribution" "Your Linux distribution ($(detect_distro)) is not supported for automatic package manager proxy removal.\n\nPlease remove your package manager proxy configuration manually."
            return 1
            ;;
    esac
}

test_auto_package_manager_proxy() {
    case "$(detect_distro)" in
        ubuntu|debian|linuxmint|pop|elementary) test_apt_proxy ;;
        fedora|rhel|centos|rocky|almalinux|oracle) test_dnf_proxy ;;
        arch|manjaro|endeavouros) test_pacman_proxy ;;
        opensuse|sles) test_zypper_proxy ;;
        *)
            ui_error "Unsupported Distribution" "Your Linux distribution ($(detect_distro)) is not supported for automatic package manager proxy testing.\n\nPlease test your package manager proxy manually."
            return 1
            ;;
    esac
}
