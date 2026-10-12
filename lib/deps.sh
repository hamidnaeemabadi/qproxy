install_runtime_deps() {
    local distro
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
        *)
            echo "Unsupported distribution for automatic dependency install: $distro" >&2
            return 1
            ;;
    esac
}

check_deps() {
    clear
    echo "-------=( $SCRIPT_NAME )=-------"
    echo "To manage the proxy configs on Linux and services quickly ..."
    echo ""
    echo "Checking and install dependencies if wasn't installed ..."

    if [ "$EUID" -ne 0 ]; then
        echo "Error: This app must be run as root"
        exit 1
    fi

    if ! install_runtime_deps; then
        dialog --title "Unsupported Distribution" \
        --msgbox "Your Linux distribution ($(detect_distro)) is not directly supported.\n\nSupported distributions:\n- Debian/Ubuntu (apt)\n- Fedora/RHEL/CentOS (dnf/yum)\n- Arch/Manjaro (pacman)\n- OpenSUSE/SLES (zypper)\n\nPlease install dependencies manually:\ndialog, jq, curl" 12 60
        exit 1
    fi
}

# Resolve the invoking user (supports sudo)

detect_distro() {
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

# Function to check and install proxychains4

check_and_install_proxychains() {
    if ! command -v proxychains4 &> /dev/null
    then
        dialog --title "Proxychains4 Not Found" \
        --yesno "Proxychains4 is not installed on your system.\n\nProxychains4 is required for proxy chain functionality.\n\nWould you like to install it now?" 10 60
        
        if [ $? -eq 0 ]; then
            echo "Installing proxychains4..."
            
            # Detect distribution and install accordingly
            distro=$(detect_distro)
            case $distro in
                "ubuntu"|"debian"|"linuxmint"|"pop"|"elementary")
                    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq proxychains4 >/dev/null 2>&1; then
                        dialog --title "Success" --msgbox "Proxychains4 installed successfully!" 6 50
                        return 0
                    else
                        dialog --title "Error" --msgbox "Failed to install proxychains4.\n\nPlease install manually: apt install proxychains4" 7 50
                        return 1
                    fi
                    ;;
                "fedora"|"rhel"|"centos"|"rocky"|"almalinux"|"oracle")
                    if sudo dnf install -y -q proxychains-ng >/dev/null 2>&1 || sudo yum install -y -q proxychains-ng >/dev/null 2>&1; then
                        dialog --title "Success" --msgbox "Proxychains-ng installed successfully!" 6 50
                        return 0
                    else
                        dialog --title "Error" --msgbox "Failed to install proxychains-ng.\n\nPlease install manually:\ndnf install proxychains-ng" 7 50
                        return 1
                    fi
                    ;;
                "arch"|"manjaro"|"endeavouros")
                    if sudo pacman -S --noconfirm proxychains-ng >/dev/null 2>&1; then
                        dialog --title "Success" --msgbox "Proxychains-ng installed successfully!" 6 50
                        return 0
                    else
                        dialog --title "Error" --msgbox "Failed to install proxychains-ng.\n\nPlease install manually: pacman -S proxychains-ng" 7 50
                        return 1
                    fi
                    ;;
                "opensuse"|"sles")
                    if sudo zypper install -y proxychains-ng >/dev/null 2>&1; then
                        dialog --title "Success" --msgbox "Proxychains-ng installed successfully!" 6 50
                        return 0
                    else
                        dialog --title "Error" --msgbox "Failed to install proxychains-ng.\n\nPlease install manually: zypper install proxychains-ng" 7 50
                        return 1
                    fi
                    ;;
                *)
                    dialog --title "Unsupported Distribution" \
                    --msgbox "Your Linux distribution ($distro) is not directly supported.\n\nPlease install proxychains manually:\n\nDebian/Ubuntu: apt install proxychains4\nFedora/RHEL: dnf install proxychains-ng\nArch: pacman -S proxychains-ng\nOpenSUSE: zypper install proxychains-ng" 12 60
                    return 1
                    ;;
            esac
        else
            # Show appropriate manual installation command based on distribution
            distro=$(detect_distro)
            case $distro in
                "ubuntu"|"debian"|"linuxmint"|"pop"|"elementary")
                    manual_cmd="apt install proxychains4"
                    ;;
                "fedora"|"rhel"|"centos"|"rocky"|"almalinux"|"oracle")
                    manual_cmd="dnf install proxychains-ng"
                    ;;
                "arch"|"manjaro"|"endeavouros")
                    manual_cmd="pacman -S proxychains-ng"
                    ;;
                "opensuse"|"sles")
                    manual_cmd="zypper install proxychains-ng"
                    ;;
                *)
                    manual_cmd="Check your package manager for proxychains"
                    ;;
            esac
            
                        dialog --title "Info" --msgbox "Proxychains installation cancelled.\n\nYou can install it later with:\n$manual_cmd" 7 50
            return 1
        fi
    else
        return 0
    fi
}

# Function to apply proxy to current session

