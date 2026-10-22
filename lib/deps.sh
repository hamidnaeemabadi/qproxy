install_runtime_deps() {
    local distro brew_user
    distro=$(detect_distro)

    case $distro in
        ubuntu|debian|linuxmint|pop|elementary)
            command -v dialog >/dev/null 2>&1 || DEBIAN_FRONTEND=noninteractive apt-get install -y -qq dialog
            command -v jq >/dev/null 2>&1 || DEBIAN_FRONTEND=noninteractive apt-get install -y -qq jq
            command -v curl >/dev/null 2>&1 || DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl
            ;;
        fedora|rhel|centos|rocky|almalinux|oracle)
            command -v dialog >/dev/null 2>&1 || dnf install -y -q dialog 2>/dev/null || yum install -y -q dialog
            command -v jq >/dev/null 2>&1 || dnf install -y -q jq 2>/dev/null || yum install -y -q jq
            command -v curl >/dev/null 2>&1 || dnf install -y -q curl 2>/dev/null || yum install -y -q curl
            ;;
        arch|manjaro|endeavouros)
            command -v dialog >/dev/null 2>&1 || pacman -S --noconfirm dialog
            command -v jq >/dev/null 2>&1 || pacman -S --noconfirm jq
            command -v curl >/dev/null 2>&1 || pacman -S --noconfirm curl
            ;;
        opensuse|sles)
            command -v dialog >/dev/null 2>&1 || zypper install -y dialog
            command -v jq >/dev/null 2>&1 || zypper install -y jq
            command -v curl >/dev/null 2>&1 || zypper install -y curl
            ;;
        macos)
            if ! command -v brew >/dev/null 2>&1 && ! [ -x /opt/homebrew/bin/brew ] && ! [ -x /usr/local/bin/brew ]; then
                echo "Homebrew is required on macOS. Install from https://brew.sh" >&2
                return 1
            fi
            # Homebrew must not run as root
            brew_user=$(get_qproxy_user)
            qproxy_brew_install() {
                local pkg="$1"
                if [ "$(id -u)" -eq 0 ] && [ "$brew_user" != "root" ]; then
                    sudo -u "$brew_user" -H brew install "$pkg"
                else
                    brew install "$pkg"
                fi
            }
            command -v dialog >/dev/null 2>&1 || qproxy_brew_install dialog
            command -v jq >/dev/null 2>&1 || qproxy_brew_install jq
            command -v curl >/dev/null 2>&1 || qproxy_brew_install curl
            ;;
        *)
            echo "Unsupported distribution for automatic dependency install: $distro" >&2
            return 1
            ;;
    esac
}

check_deps() {
    clear
    echo "-------=( $SCRIPT_NAME )=-------"
    if [ "$(detect_os)" = "darwin" ]; then
        echo "To manage the proxy configs on macOS and services quickly ..."
    else
        echo "To manage the proxy configs on Linux and services quickly ..."
    fi
    echo ""
    echo "Checking and install dependencies if wasn't installed ..."

    if [ "$EUID" -ne 0 ]; then
        echo "Error: This app must be run as root"
        exit 1
    fi

    if ! install_runtime_deps; then
        if [ "$(detect_os)" = "darwin" ]; then
            dialog --title "Unsupported Platform" \
            --msgbox "Automatic dependency install failed on macOS.\n\nInstall Homebrew (https://brew.sh), then:\n  brew install dialog jq curl" 12 60
        else
            dialog --title "Unsupported Distribution" \
            --msgbox "Your Linux distribution ($(detect_distro)) is not directly supported.\n\nSupported distributions:\n- Debian/Ubuntu (apt)\n- Fedora/RHEL/CentOS (dnf/yum)\n- Arch/Manjaro (pacman)\n- OpenSUSE/SLES (zypper)\n- macOS (Homebrew)\n\nPlease install dependencies manually:\ndialog, jq, curl" 14 60
        fi
        exit 1
    fi
}

detect_distro() {
    if [ "$(detect_os)" = "darwin" ]; then
        echo "macos"
        return 0
    fi
    local os_release="${QPROXY_OS_RELEASE_FILE:-/etc/os-release}"
    if [ -f "$os_release" ]; then
        # shellcheck source=/dev/null
        . "$os_release"
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

proxychains_bin() {
    if command -v proxychains4 >/dev/null 2>&1; then
        echo proxychains4
        return 0
    fi
    if command -v proxychains >/dev/null 2>&1; then
        echo proxychains
        return 0
    fi
    return 1
}

# Function to check and install proxychains4

check_and_install_proxychains() {
    if proxychains_bin >/dev/null 2>&1; then
        return 0
    fi

    dialog --title "Proxychains Not Found" \
    --yesno "Proxychains is not installed on your system.\n\nProxychains is required for proxy chain functionality.\n\nWould you like to install it now?" 10 60

    if [ $? -ne 0 ]; then
        local distro manual_cmd
        distro=$(detect_distro)
        case $distro in
            ubuntu|debian|linuxmint|pop|elementary) manual_cmd="apt install proxychains4" ;;
            fedora|rhel|centos|rocky|almalinux|oracle) manual_cmd="dnf install proxychains-ng" ;;
            arch|manjaro|endeavouros) manual_cmd="pacman -S proxychains-ng" ;;
            opensuse|sles) manual_cmd="zypper install proxychains-ng" ;;
            macos) manual_cmd="brew install proxychains-ng" ;;
            *) manual_cmd="Check your package manager for proxychains" ;;
        esac
        dialog --title "Info" --msgbox "Proxychains installation cancelled.\n\nYou can install it later with:\n$manual_cmd" 7 50
        return 1
    fi

    echo "Installing proxychains..."
    local distro brew_user
    distro=$(detect_distro)
    case $distro in
        ubuntu|debian|linuxmint|pop|elementary)
            if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq proxychains4 >/dev/null 2>&1; then
                dialog --title "Success" --msgbox "Proxychains4 installed successfully!" 6 50
                return 0
            fi
            dialog --title "Error" --msgbox "Failed to install proxychains4.\n\nPlease install manually: apt install proxychains4" 7 50
            return 1
            ;;
        fedora|rhel|centos|rocky|almalinux|oracle)
            if sudo dnf install -y -q proxychains-ng >/dev/null 2>&1 || sudo yum install -y -q proxychains-ng >/dev/null 2>&1; then
                dialog --title "Success" --msgbox "Proxychains-ng installed successfully!" 6 50
                return 0
            fi
            dialog --title "Error" --msgbox "Failed to install proxychains-ng.\n\nPlease install manually:\ndnf install proxychains-ng" 7 50
            return 1
            ;;
        arch|manjaro|endeavouros)
            if sudo pacman -S --noconfirm proxychains-ng >/dev/null 2>&1; then
                dialog --title "Success" --msgbox "Proxychains-ng installed successfully!" 6 50
                return 0
            fi
            dialog --title "Error" --msgbox "Failed to install proxychains-ng.\n\nPlease install manually: pacman -S proxychains-ng" 7 50
            return 1
            ;;
        opensuse|sles)
            if sudo zypper install -y proxychains-ng >/dev/null 2>&1; then
                dialog --title "Success" --msgbox "Proxychains-ng installed successfully!" 6 50
                return 0
            fi
            dialog --title "Error" --msgbox "Failed to install proxychains-ng.\n\nPlease install manually: zypper install proxychains-ng" 7 50
            return 1
            ;;
        macos)
            if ! command -v brew >/dev/null 2>&1 && ! [ -x /opt/homebrew/bin/brew ] && ! [ -x /usr/local/bin/brew ]; then
                dialog --title "Error" --msgbox "Homebrew is required.\n\nInstall from https://brew.sh then:\nbrew install proxychains-ng" 8 50
                return 1
            fi
            brew_user=$(get_qproxy_user)
            if [ "$(id -u)" -eq 0 ] && [ "$brew_user" != "root" ]; then
                if sudo -u "$brew_user" -H brew install proxychains-ng; then
                    qproxy_init_platform_paths
                    dialog --title "Success" --msgbox "Proxychains-ng installed successfully!" 6 50
                    return 0
                fi
            elif brew install proxychains-ng; then
                qproxy_init_platform_paths
                dialog --title "Success" --msgbox "Proxychains-ng installed successfully!" 6 50
                return 0
            fi
            dialog --title "Error" --msgbox "Failed to install proxychains-ng.\n\nPlease install manually:\nbrew install proxychains-ng" 7 50
            return 1
            ;;
        *)
            dialog --title "Unsupported Distribution" \
            --msgbox "Your system ($distro) is not directly supported.\n\nPlease install proxychains manually:\n\nDebian/Ubuntu: apt install proxychains4\nFedora/RHEL: dnf install proxychains-ng\nArch: pacman -S proxychains-ng\nOpenSUSE: zypper install proxychains-ng\nmacOS: brew install proxychains-ng" 14 60
            return 1
            ;;
    esac
}
