#!/bin/bash
########################################################
# Author: [Hamid Naeemabadi]
# Script Name: QProxy
# Purpose: [Manage the proxy configs on Linux and services quickly.]
########################################################

# Vars
VERSION="v1.9.2"

SCRIPT_NAME="QProxy for Linux $VERSION by Hamid Naeemabadi"

# Default proxy values (seed ~/.qproxy.env when missing)
DEFAULT_SOCKS5_HOST="10.X.X.X"
DEFAULT_SOCKS5_PORT="1080"
DEFAULT_HTTP_HOST="10.X.X.X"
DEFAULT_HTTP_PORT="3128"
DEFAULT_NO_PROXY_HOSTS="127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,example.local,localhost,*.local"
DEFAULT_PROXY_TIMEOUT=30
DEFAULT_PROXY_READ_TIMEOUT=60

# Runtime proxy settings (loaded from ~/.qproxy.env on startup)
SOCKS5_HOST="$DEFAULT_SOCKS5_HOST"
SOCKS5_PORT="$DEFAULT_SOCKS5_PORT"
HTTP_HOST="$DEFAULT_HTTP_HOST"
HTTP_PORT="$DEFAULT_HTTP_PORT"
NO_PROXY_HOSTS="$DEFAULT_NO_PROXY_HOSTS"
PROXY_TIMEOUT="$DEFAULT_PROXY_TIMEOUT"
PROXY_READ_TIMEOUT="$DEFAULT_PROXY_READ_TIMEOUT"

USER_PROXY_ENV_PATH="/etc/profile.d/user_proxy_env.sh"
PROXYCHAINS_CONF_PATH="/etc/proxychains4.conf"
QPROXY_ENV_FILE=""
QPROXY_SESSION_ENV_FILE=""

# Function to install dependencies if wasn't installed
check_deps() {
    clear
    echo "-------=( $SCRIPT_NAME )=-------"
    echo "To manage the proxy configs on Linux and services quickly ..."
    echo ""
    echo "Checking and install dependencies if wasn't installed ..."
    
    # Detect distribution
    distro=$(detect_distro)
    
    # Check if the app is run as root
    if [ "$EUID" -ne 0 ]
    then 
      echo "Error: This app must be run as root"
      exit 1
    fi
    
    # Install dependencies based on distribution
    case $distro in
        "ubuntu"|"debian"|"linuxmint"|"pop"|"elementary")
    which dialog >/dev/null 2>&1 || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq dialog >/dev/null 2>&1
    which jq >/dev/null 2>&1 || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq jq >/dev/null 2>&1
    which curl >/dev/null 2>&1 || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl >/dev/null 2>&1
            ;;
        "fedora"|"rhel"|"centos"|"rocky"|"almalinux"|"oracle")
            which dialog >/dev/null 2>&1 || sudo dnf install -y -q dialog >/dev/null 2>&1 || sudo yum install -y -q dialog >/dev/null 2>&1
            which jq >/dev/null 2>&1 || sudo dnf install -y -q jq >/dev/null 2>&1 || sudo yum install -y -q jq >/dev/null 2>&1
            which curl >/dev/null 2>&1 || sudo dnf install -y -q curl >/dev/null 2>&1 || sudo yum install -y -q curl >/dev/null 2>&1
            ;;
        "arch"|"manjaro"|"endeavouros")
            which dialog >/dev/null 2>&1 || sudo pacman -S --noconfirm dialog >/dev/null 2>&1
            which jq >/dev/null 2>&1 || sudo pacman -S --noconfirm jq >/dev/null 2>&1
            which curl >/dev/null 2>&1 || sudo pacman -S --noconfirm curl >/dev/null 2>&1
            ;;
        "opensuse"|"sles")
            which dialog >/dev/null 2>&1 || sudo zypper install -y dialog >/dev/null 2>&1
            which jq >/dev/null 2>&1 || sudo zypper install -y jq >/dev/null 2>&1
            which curl >/dev/null 2>&1 || sudo zypper install -y curl >/dev/null 2>&1
            ;;
        *)
            dialog --title "Unsupported Distribution" \
            --msgbox "Your Linux distribution ($distro) is not directly supported.\n\nSupported distributions:\n- Debian/Ubuntu (apt)\n- Fedora/RHEL/CentOS (dnf/yum)\n- Arch/Manjaro (pacman)\n- OpenSUSE/SLES (zypper)\n\nPlease install dependencies manually:\ndialog, jq, curl" 12 60
            exit 1
            ;;
    esac
}

# Resolve the invoking user (supports sudo)
get_qproxy_user() {
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        echo "$SUDO_USER"
    else
        echo "${USER:-root}"
    fi
}

get_qproxy_user_home() {
    local quser qhome
    quser=$(get_qproxy_user)
    if [ "$quser" = "root" ]; then
        echo "${HOME:-/root}"
    else
        qhome=$(getent passwd "$quser" 2>/dev/null | cut -d: -f6)
        if [ -n "$qhome" ]; then
            echo "$qhome"
        else
            echo "${HOME:-/root}"
        fi
    fi
}

resolve_qproxy_env_file() {
    QPROXY_ENV_FILE="$(get_qproxy_user_home)/.qproxy.env"
}

resolve_qproxy_session_env_file() {
    QPROXY_SESSION_ENV_FILE="$(get_qproxy_user_home)/.qproxy.session.env"
}

resolve_qproxy_session_pending_file() {
    echo "$(get_qproxy_user_home)/.qproxy.session.pending"
}

QPROXY_HOOK_MARKER_START='# >>> QProxy session auto-apply START >>>'

# Own user-owned dotfiles when running under sudo
chown_qproxy_user_file() {
    local f="$1" quser
    [ -n "$f" ] || return 0
    [ -e "$f" ] || return 0
    quser=$(get_qproxy_user)
    chmod 600 "$f" 2>/dev/null || true
    if [ "$(id -u)" -eq 0 ] && [ "$quser" != "root" ]; then
        chown "$quser:$quser" "$f" 2>/dev/null || true
    fi
}

chown_qproxy_session_env_file() {
    chown_qproxy_user_file "$QPROXY_SESSION_ENV_FILE"
}

# Walk the process tree to find the interactive shell that launched QProxy
find_invoking_shell_pid() {
    local quser pid owner comm
    quser=$(get_qproxy_user)
    pid=$(ps -o ppid= -p $$ 2>/dev/null | tr -d ' ')
    while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
        owner=$(ps -o user= -p "$pid" 2>/dev/null | tr -d ' ')
        comm=$(ps -o comm= -p "$pid" 2>/dev/null | sed 's/^-//')
        case "$comm" in
            bash|zsh|sh|fish|dash)
                if [ "$owner" = "$quser" ]; then
                    echo "$pid"
                    return 0
                fi
                ;;
        esac
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    done
    return 1
}

find_invoking_shell_tty() {
    local pid tty
    pid=$(find_invoking_shell_pid) || return 1
    tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
    case "$tty" in
        ?|??)
            echo "/dev/$tty"
            return 0
            ;;
    esac
    return 1
}

# One-time hook: sources ~/.qproxy.session.env on the next prompt after QProxy updates it
ensure_qproxy_shell_hook_installed() {
    local qhome quser bashrc zshrc
    qhome=$(get_qproxy_user_home)
    quser=$(get_qproxy_user)
    bashrc="$qhome/.bashrc"
    zshrc="$qhome/.zshrc"

    if [ ! -f "$bashrc" ]; then
        touch "$bashrc"
        chown_qproxy_user_file "$bashrc"
    fi
    if ! grep -qF "$QPROXY_HOOK_MARKER_START" "$bashrc" 2>/dev/null; then
        cat >> "$bashrc" <<'EOF'

# >>> QProxy session auto-apply START >>>
__qproxy_session_auto_apply() {
    [ -f "${HOME}/.qproxy.session.pending" ] || return 0
    [ -f "${HOME}/.qproxy.session.env" ] && . "${HOME}/.qproxy.session.env"
    rm -f "${HOME}/.qproxy.session.pending"
}
if [[ $- == *i* ]] && [[ "${PROMPT_COMMAND:-}" != *__qproxy_session_auto_apply* ]]; then
    PROMPT_COMMAND="__qproxy_session_auto_apply${PROMPT_COMMAND:+;${PROMPT_COMMAND}}"
fi
# <<< QProxy session auto-apply END <<<
EOF
        chown_qproxy_user_file "$bashrc"
    fi

    if [ -f "$zshrc" ]; then
        if ! grep -qF "$QPROXY_HOOK_MARKER_START" "$zshrc" 2>/dev/null; then
            cat >> "$zshrc" <<'EOF'

# >>> QProxy session auto-apply START >>>
__qproxy_session_auto_apply() {
    [ -f "${HOME}/.qproxy.session.pending" ] || return 0
    [ -f "${HOME}/.qproxy.session.env" ] && . "${HOME}/.qproxy.session.env"
    rm -f "${HOME}/.qproxy.session.pending"
}
if [[ -o interactive ]] && [[ "${precmd_functions[*]:-}" != *__qproxy_session_auto_apply* ]]; then
    precmd_functions+=(__qproxy_session_auto_apply)
fi
# <<< QProxy session auto-apply END <<<
EOF
            chown_qproxy_user_file "$zshrc"
        fi
    fi
}

mark_session_apply_pending() {
    local pending
    pending=$(resolve_qproxy_session_pending_file)
    : > "$pending"
    chown_qproxy_user_file "$pending"
}

# Inject "source ..." into the user's shell stdin (works when the shell is at a prompt)
inject_source_into_invoking_shell() {
    local shell_pid session_file quser cmd pending
    resolve_qproxy_session_env_file
    pending=$(resolve_qproxy_session_pending_file)
    [ -f "$pending" ] || return 1
    session_file="$QPROXY_SESSION_ENV_FILE"
    [ -f "$session_file" ] || return 1
    shell_pid=$(find_invoking_shell_pid) || return 1
    quser=$(get_qproxy_user)
    cmd="source $(printf '%q' "$session_file")"

    if [ ! -r "/proc/$shell_pid/fd/0" ]; then
        return 1
    fi

    if [ "$(id -u)" -eq 0 ] && [ "$quser" != "root" ]; then
        if echo "$cmd" | sudo -u "$quser" tee "/proc/$shell_pid/fd/0" >/dev/null 2>&1; then
            rm -f "$pending"
            return 0
        fi
    elif echo "$cmd" > "/proc/$shell_pid/fd/0" 2>/dev/null; then
        rm -f "$pending"
        return 0
    fi
    return 1
}

# Queue auto-apply for the user's interactive shell (hook + stdin injection)
apply_session_to_user_shell() {
    ensure_qproxy_shell_hook_installed
    mark_session_apply_pending
    inject_source_into_invoking_shell || true
}

# Retry stdin injection when QProxy exits and the shell regains the prompt
finalize_qproxy_session_apply() {
    local pending
    pending=$(resolve_qproxy_session_pending_file)
    [ -f "$pending" ] || return 0
    inject_source_into_invoking_shell || true
}

session_auto_apply_msg() {
    echo "Proxy settings will be applied automatically in your shell when you return to the prompt (usually right after you exit QProxy)."
}

write_http_session_env_file() {
    resolve_qproxy_session_env_file
    cat > "$QPROXY_SESSION_ENV_FILE" <<EOF
# QProxy temporary session proxy (applied automatically by shell hook)
export HTTP_PROXY="http://$HTTP_HOST:$HTTP_PORT"
export http_proxy="http://$HTTP_HOST:$HTTP_PORT"
export HTTPS_PROXY="http://$HTTP_HOST:$HTTP_PORT"
export https_proxy="http://$HTTP_HOST:$HTTP_PORT"
export NO_PROXY="$NO_PROXY_HOSTS"
export no_proxy="$NO_PROXY_HOSTS"
export HTTP_PROXY_CONNECTION_TIMEOUT="$PROXY_TIMEOUT"
export HTTP_PROXY_READ_TIMEOUT="$PROXY_READ_TIMEOUT"
EOF
    chown_qproxy_session_env_file
}

write_socks5_session_env_file() {
    resolve_qproxy_session_env_file
    cat > "$QPROXY_SESSION_ENV_FILE" <<EOF
# QProxy temporary session proxy (applied automatically by shell hook)
export HTTP_PROXY="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export http_proxy="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export HTTPS_PROXY="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export https_proxy="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export NO_PROXY="$NO_PROXY_HOSTS"
export no_proxy="$NO_PROXY_HOSTS"
export HTTP_PROXY_CONNECTION_TIMEOUT="$PROXY_TIMEOUT"
export HTTP_PROXY_READ_TIMEOUT="$PROXY_READ_TIMEOUT"
EOF
    chown_qproxy_session_env_file
}

write_unset_session_env_file() {
    resolve_qproxy_session_env_file
    cat > "$QPROXY_SESSION_ENV_FILE" <<'EOF'
# QProxy - remove temporary session proxy (applied automatically by shell hook)
unset HTTP_PROXY http_proxy HTTPS_PROXY https_proxy NO_PROXY no_proxy
unset HTTP_PROXY_CONNECTION_TIMEOUT HTTP_PROXY_READ_TIMEOUT
EOF
    chown_qproxy_session_env_file
}

# Load proxy host/port settings from the user env file
load_qproxy_env_file() {
    local env_file="$1"
    local line key value
    [ -f "$env_file" ] || return 1
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="${line%"${line##*[![:space:]]}"}"
        line="${line#"${line%%[![:space:]]*}"}"
        [ -z "$line" ] && continue
        [[ "$line" != *=* ]] && continue
        key="${line%%=*}"
        value="${line#*=}"
        key="${key%"${key##*[![:space:]]}"}"
        key="${key#"${key%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        case "$key" in
            HTTP_HOST|HTTP_PORT|SOCKS5_HOST|SOCKS5_PORT|NO_PROXY_HOSTS|PROXY_TIMEOUT|PROXY_READ_TIMEOUT)
                eval "$key=\"\$value\""
                ;;
        esac
    done < "$env_file"
    return 0
}

save_qproxy_env_file() {
    local env_file="${1:-$QPROXY_ENV_FILE}"
    local qhome quser
    [ -n "$env_file" ] || return 1
    qhome=$(dirname "$env_file")
    quser=$(get_qproxy_user)
    mkdir -p "$qhome" 2>/dev/null || true
    cat > "$env_file" <<EOF
# QProxy user configuration - managed by qproxy.sh
# Edit HTTP/SOCKS5 host and port here; changes apply on the next script run.
HTTP_HOST="$HTTP_HOST"
HTTP_PORT="$HTTP_PORT"
SOCKS5_HOST="$SOCKS5_HOST"
SOCKS5_PORT="$SOCKS5_PORT"
NO_PROXY_HOSTS="$NO_PROXY_HOSTS"
PROXY_TIMEOUT="$PROXY_TIMEOUT"
PROXY_READ_TIMEOUT="$PROXY_READ_TIMEOUT"
EOF
    chmod 600 "$env_file" 2>/dev/null || true
    if [ "$(id -u)" -eq 0 ] && [ "$quser" != "root" ]; then
        chown "$quser:$quser" "$env_file" 2>/dev/null || true
    fi
}

# Read ~/.qproxy.env on startup; create it from defaults if missing
init_qproxy_config() {
    resolve_qproxy_env_file
    ensure_qproxy_shell_hook_installed
    if [ -f "$QPROXY_ENV_FILE" ]; then
        load_qproxy_env_file "$QPROXY_ENV_FILE"
    else
        save_qproxy_env_file "$QPROXY_ENV_FILE"
    fi
}

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $ID
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
apply_proxy_to_current_session() {
    # Exports apply only inside this script; the user's shell must source the session file
    export HTTP_PROXY="http://$HTTP_HOST:$HTTP_PORT"
    export http_proxy="http://$HTTP_HOST:$HTTP_PORT"
    export HTTPS_PROXY="http://$HTTP_HOST:$HTTP_PORT"
    export https_proxy="http://$HTTP_HOST:$HTTP_PORT"
    export NO_PROXY="$NO_PROXY_HOSTS"
    export no_proxy="$NO_PROXY_HOSTS"
    export HTTP_PROXY_CONNECTION_TIMEOUT="$PROXY_TIMEOUT"
    export HTTP_PROXY_READ_TIMEOUT="$PROXY_READ_TIMEOUT"

    write_http_session_env_file
    apply_session_to_user_shell
}

# Function to set os http proxy
set_os_env_http_proxy() {
    # Check proxy health before setting
    if ! check_proxy_health "http://$HTTP_HOST:$HTTP_PORT"; then
        dialog --title "Warning" --msgbox "Proxy health check failed. Proceeding anyway, but you may experience issues." 7 50
    fi
    
    # Create the persistent configuration file
    cat << EOP > $USER_PROXY_ENV_PATH
export HTTP_PROXY="http://$HTTP_HOST:$HTTP_PORT"
export http_proxy="http://$HTTP_HOST:$HTTP_PORT"
export HTTPS_PROXY="http://$HTTP_HOST:$HTTP_PORT"
export https_proxy="http://$HTTP_HOST:$HTTP_PORT"
export NO_PROXY="$NO_PROXY_HOSTS"
export no_proxy="$NO_PROXY_HOSTS"
export HTTP_PROXY_CONNECTION_TIMEOUT="$PROXY_TIMEOUT"
export HTTP_PROXY_READ_TIMEOUT="$PROXY_READ_TIMEOUT"
EOP
    
    # Apply to current session immediately
    apply_proxy_to_current_session
    
    dialog --title "Success" --msgbox "HTTP Proxy enabled (persistent).\n\nNew shells: /etc/profile.d\nThis terminal: $(session_auto_apply_msg)\n\nPersists after reboot." 11 58
}

# Function to apply SOCKS5 proxy to current session
apply_socks5_proxy_to_current_session() {
    export HTTP_PROXY="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
    export http_proxy="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
    export HTTPS_PROXY="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
    export https_proxy="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
    export NO_PROXY="$NO_PROXY_HOSTS"
    export no_proxy="$NO_PROXY_HOSTS"
    export HTTP_PROXY_CONNECTION_TIMEOUT="$PROXY_TIMEOUT"
    export HTTP_PROXY_READ_TIMEOUT="$PROXY_READ_TIMEOUT"

    write_socks5_session_env_file
    apply_session_to_user_shell
}

# Function to set os socks5 proxy
set_os_env_socks5_proxy() {
    # Check proxy health before setting
    if ! check_proxy_health "socks5h://$SOCKS5_HOST:$SOCKS5_PORT"; then
        dialog --title "Warning" --msgbox "Proxy health check failed. Proceeding anyway, but you may experience issues." 7 50
    fi
    
    # Create the persistent configuration file
    sudo cat << EOP > $USER_PROXY_ENV_PATH
export HTTP_PROXY="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export http_proxy="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export HTTPS_PROXY="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export https_proxy="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export NO_PROXY="$NO_PROXY_HOSTS"
export no_proxy="$NO_PROXY_HOSTS"
export HTTP_PROXY_CONNECTION_TIMEOUT="$PROXY_TIMEOUT"
export HTTP_PROXY_READ_TIMEOUT="$PROXY_READ_TIMEOUT"
EOP
    
    # Apply to current session immediately
    apply_socks5_proxy_to_current_session
    
    dialog --title "Success" --msgbox "SOCKS5 Proxy enabled (persistent).\n\nNew shells: /etc/profile.d\nThis terminal: $(session_auto_apply_msg)\n\nPersists after reboot." 11 58
}

# Function to remove proxy from current session
remove_proxy_from_current_session() {
    unset HTTP_PROXY
    unset http_proxy
    unset HTTPS_PROXY
    unset https_proxy
    unset NO_PROXY
    unset no_proxy
    unset HTTP_PROXY_CONNECTION_TIMEOUT
    unset HTTP_PROXY_READ_TIMEOUT

    write_unset_session_env_file
    apply_session_to_user_shell
}

# Function to disable os proxy
disable_os_env_proxy() {
    # Remove the persistent configuration file
    rm -f $USER_PROXY_ENV_PATH
    
    # Remove from current session immediately
    remove_proxy_from_current_session
    
    dialog --title "Success" --msgbox "Persistent proxy disabled.\n\n$(session_auto_apply_msg)" 9 58
}

# Function to remove apt proxy
remove_old_apt_proxy() {
    files=$(grep -irl "proxy" /etc/apt/)
    if [ -n "$files" ]; then
        echo "$files" | xargs rm
    fi
    sudo apt clean
    sudo apt autoclean >/dev/null 2>&1
    if [ "$1" != "-q" ]; then
        dialog --title "Success" --msgbox "APT proxy disabled successfully!" 6 50
    fi
}

# Function to remove DNF/YUM proxy
remove_old_dnf_proxy() {
    # Remove DNF proxy configurations
    if [ -f /etc/dnf/dnf.conf ]; then
        sudo sed -i '/^proxy=/d' /etc/dnf/dnf.conf
        sudo sed -i '/^proxy_username=/d' /etc/dnf/dnf.conf
        sudo sed -i '/^proxy_password=/d' /etc/dnf/dnf.conf
    fi
    
    # Remove YUM proxy configurations
    if [ -f /etc/yum.conf ]; then
        sudo sed -i '/^proxy=/d' /etc/yum.conf
        sudo sed -i '/^proxy_username=/d' /etc/yum.conf
        sudo sed -i '/^proxy_password=/d' /etc/yum.conf
    fi
    
    if [ "$1" != "-q" ]; then
        dialog --title "Success" --msgbox "DNF/YUM proxy disabled successfully!" 6 50
    fi
}

# Function to remove Pacman proxy
remove_old_pacman_proxy() {
    # Remove pacman proxy configurations
    if [ -f /etc/pacman.conf ]; then
        sudo sed -i '/^XferCommand/d' /etc/pacman.conf
    fi
    
    if [ "$1" != "-q" ]; then
        dialog --title "Success" --msgbox "Pacman proxy disabled successfully!" 6 50
    fi
}

# Function to remove Zypper proxy
remove_old_zypper_proxy() {
    # Remove zypper proxy configurations
    sudo zypper config --unset proxy.http >/dev/null 2>&1
    sudo zypper config --unset proxy.https >/dev/null 2>&1
    
    if [ "$1" != "-q" ]; then
        dialog --title "Success" --msgbox "Zypper proxy disabled successfully!" 6 50
    fi
}

# Function to set APT HTTP proxy
set_apt_http_proxy() {
    # Check if apt is installed
    if ! command -v apt &> /dev/null
    then
        dialog --title "Error" --msgbox "APT package manager not found!" 6 50
    fi
    # remove old configs
    remove_old_apt_proxy -q
    
    cat << EOP >>/etc/apt/apt.conf.d/apt_proxy_http
Acquire::http::proxy "http://$HTTP_HOST:$HTTP_PORT";
Acquire::https::proxy "http://$HTTP_HOST:$HTTP_PORT";
Acquire::http::Timeout "$PROXY_TIMEOUT";
Acquire::https::Timeout "$PROXY_TIMEOUT";
Acquire::http::Pipeline-Depth "5";
Acquire::https::Pipeline-Depth "5";
Acquire::Retries "3";
Acquire::http::No-Cache "true";
Acquire::https::No-Cache "true";
EOP
    dialog --title "Success" --msgbox "APT HTTP Proxy configured successfully!" 6 50
}

# Function to set DNF/YUM HTTP proxy
set_dnf_http_proxy() {
    # Check if dnf or yum is installed
    if ! command -v dnf &> /dev/null && ! command -v yum &> /dev/null
    then
        dialog --title "Error" --msgbox "DNF/YUM package manager not found!" 6 50
        return 1
    fi
    
    # Remove old proxy configurations
    if [ -f /etc/dnf/dnf.conf ]; then
        sudo sed -i '/^proxy=/d' /etc/dnf/dnf.conf
        sudo sed -i '/^proxy_username=/d' /etc/dnf/dnf.conf
        sudo sed -i '/^proxy_password=/d' /etc/dnf/dnf.conf
    fi
    if [ -f /etc/yum.conf ]; then
        sudo sed -i '/^proxy=/d' /etc/yum.conf
        sudo sed -i '/^proxy_username=/d' /etc/yum.conf
        sudo sed -i '/^proxy_password=/d' /etc/yum.conf
    fi
    
    # Configure DNF proxy
    if [ -f /etc/dnf/dnf.conf ]; then
        echo "proxy=http://$HTTP_HOST:$HTTP_PORT" | sudo tee -a /etc/dnf/dnf.conf > /dev/null
        echo "proxy_username=" | sudo tee -a /etc/dnf/dnf.conf > /dev/null
        echo "proxy_password=" | sudo tee -a /etc/dnf/dnf.conf > /dev/null
    fi
    
    # Configure YUM proxy (fallback)
    if [ -f /etc/yum.conf ]; then
        echo "proxy=http://$HTTP_HOST:$HTTP_PORT" | sudo tee -a /etc/yum.conf > /dev/null
        echo "proxy_username=" | sudo tee -a /etc/yum.conf > /dev/null
        echo "proxy_password=" | sudo tee -a /etc/yum.conf > /dev/null
    fi
    
    dialog --title "Success" --msgbox "DNF/YUM HTTP Proxy configured successfully!" 6 50
}

# Function to set Pacman HTTP proxy
set_pacman_http_proxy() {
    # Check if pacman is installed
    if ! command -v pacman &> /dev/null
    then
        dialog --title "Error" --msgbox "Pacman package manager not found!" 6 50
        return 1
    fi
    
    # Remove old proxy configurations
    if [ -f /etc/pacman.conf ]; then
        sudo sed -i '/^XferCommand/d' /etc/pacman.conf
    fi
    
    # Configure pacman proxy using XferCommand
    if [ -f /etc/pacman.conf ]; then
        # Backup original pacman.conf
        sudo cp /etc/pacman.conf /etc/pacman.conf.backup
        
        # Add proxy configuration
        sudo sed -i '/^\[options\]/a XferCommand = /usr/bin/curl -x http://$HTTP_HOST:$HTTP_PORT -C - -f %u > %o' /etc/pacman.conf
    fi
    
    dialog --title "Success" --msgbox "Pacman HTTP Proxy configured successfully!" 6 50
}

# Function to set Zypper HTTP proxy
set_zypper_http_proxy() {
    # Check if zypper is installed
    if ! command -v zypper &> /dev/null
    then
        dialog --title "Error" --msgbox "Zypper package manager not found!" 6 50
        return 1
    fi
    
    # Configure zypper proxy
    sudo zypper config --set proxy.http "http://$HTTP_HOST:$HTTP_PORT" > /dev/null 2>&1
    sudo zypper config --set proxy.https "http://$HTTP_HOST:$HTTP_PORT" > /dev/null 2>&1
    
    dialog --title "Success" --msgbox "Zypper HTTP Proxy configured successfully!" 6 50
}

# Function to automatically set HTTP proxy for the detected package manager
set_auto_package_manager_proxy() {
    distro=$(detect_distro)
    
    case $distro in
        "ubuntu"|"debian"|"linuxmint"|"pop"|"elementary")
            set_apt_http_proxy
            ;;
        "fedora"|"rhel"|"centos"|"rocky"|"almalinux"|"oracle")
            set_dnf_http_proxy
            ;;
        "arch"|"manjaro"|"endeavouros")
            set_pacman_http_proxy
            ;;
        "opensuse"|"sles")
            set_zypper_http_proxy
            ;;
        *)
            dialog --title "Unsupported Distribution" \
            --msgbox "Your Linux distribution ($distro) is not supported for automatic package manager proxy configuration.\n\nPlease configure your package manager proxy manually." 8 50
            return 1
            ;;
    esac
}

# Function to automatically remove HTTP proxy for the detected package manager
remove_auto_package_manager_proxy() {
    distro=$(detect_distro)
    
    case $distro in
        "ubuntu"|"debian"|"linuxmint"|"pop"|"elementary")
            remove_old_apt_proxy
            ;;
        "fedora"|"rhel"|"centos"|"rocky"|"almalinux"|"oracle")
            remove_old_dnf_proxy
            ;;
        "arch"|"manjaro"|"endeavouros")
            remove_old_pacman_proxy
            ;;
        "opensuse"|"sles")
            remove_old_zypper_proxy
            ;;
        *)
            dialog --title "Unsupported Distribution" \
            --msgbox "Your Linux distribution ($distro) is not supported for automatic package manager proxy removal.\n\nPlease remove your package manager proxy configuration manually." 8 50
            return 1
            ;;
    esac
}

# Function to automatically test HTTP proxy for the detected package manager
test_auto_package_manager_proxy() {
    distro=$(detect_distro)
    
    case $distro in
        "ubuntu"|"debian"|"linuxmint"|"pop"|"elementary")
            test_apt_proxy
            ;;
        "fedora"|"rhel"|"centos"|"rocky"|"almalinux"|"oracle")
            test_dnf_proxy
            ;;
        "arch"|"manjaro"|"endeavouros")
            test_pacman_proxy
            ;;
        "opensuse"|"sles")
            test_zypper_proxy
            ;;
        *)
            dialog --title "Unsupported Distribution" \
            --msgbox "Your Linux distribution ($distro) is not supported for automatic package manager proxy testing.\n\nPlease test your package manager proxy manually." 8 50
            return 1
            ;;
    esac
}

# Function to set APT SOCKS5 proxy
set_apt_socks5_proxy() {
    # Check if apt is installed
    if ! command -v apt &> /dev/null
    then
        dialog --title "Error" --msgbox "APT package manager not found!" 6 50
    fi
    # remove old configs
    remove_old_apt_proxy -q
    
    cat << EOP >>/etc/apt/apt.conf.d/apt_proxy_socks5
Acquire::http::proxy "socks5h://$SOCKS5_HOST:$SOCKS5_PORT";
Acquire::https::proxy "socks5h://$SOCKS5_HOST:$SOCKS5_PORT";
Acquire::http::Timeout "$PROXY_TIMEOUT";
Acquire::https::Timeout "$PROXY_TIMEOUT";
Acquire::http::Pipeline-Depth "5";
Acquire::https::Pipeline-Depth "5";
Acquire::Retries "3";
Acquire::http::No-Cache "true";
Acquire::https::No-Cache "true";
EOP
    dialog --title "Success" --msgbox "APT SOCKS5 Proxy configured successfully!" 6 50
}

# Function to restart Docker service carefully
docker_service_restart() {
    # Check if /etc/docker/daemon.json exists
    if [ -f "/etc/docker/daemon.json" ]; then
        # Extract the value of "live-restore" from daemon.json
        live_restore=$(jq -r '.["live-restore"]' /etc/docker/daemon.json)
        # Verify if "live-restore" is set to true
        if [ "$live_restore" = "true" ]; then
            # Run the "docker info" command
            docker_info=$(docker info)
            # Check if "Live Restore Enabled" is true
            if [[ "$docker_info" == *"Live Restore Enabled: true"* ]]; then
                sudo systemctl daemon-reload
                sudo systemctl restart docker
            else
                sudo systemctl daemon-reload
                echo -e "The Docker service needs to be restarted but Live Restore is not enabled in Docker, please enable Live Recovery otherwise all containers will be restarted and cause the service outages.\nDoc: https://docs.docker.com/config/containers/live-restore/"
            fi
        fi
    fi
}

# Function to set Docker HTTP proxy
set_docker_http_proxy() {
    # Check if docker is installed
    if ! command -v docker &> /dev/null
    then
        dialog --title "Error" --msgbox "Docker not found!" 6 50
    fi
    sudo mkdir -p /etc/systemd/system/docker.service.d
    sudo cat << EOS > /etc/systemd/system/docker.service.d/proxy.conf
[Service]
Environment="HTTP_PROXY=http://$HTTP_HOST:$HTTP_PORT" "HTTPS_PROXY=http://$HTTP_HOST:$HTTP_PORT" "NO_PROXY="$NO_PROXY_HOSTS""
EOS

    # Create or update Docker daemon.json with performance optimizations
    sudo mkdir -p /etc/docker
    if [ -f "/etc/docker/daemon.json" ]; then
        # Backup existing daemon.json
        sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup
        # Merge with existing configuration
        sudo jq '. + {
            "max-concurrent-downloads": 3,
            "max-concurrent-uploads": 5,
            "max-download-attempts": 5,
            "live-restore": true,
            "log-driver": "json-file",
            "log-opts": {
                "max-size": "10m",
                "max-file": "3"
            }
        }' /etc/docker/daemon.json > /tmp/daemon.json && sudo mv /tmp/daemon.json /etc/docker/daemon.json
    else
        # Create new daemon.json with optimizations
        sudo cat << EOD > /etc/docker/daemon.json
{
    "max-concurrent-downloads": 3,
    "max-concurrent-uploads": 5,
    "max-download-attempts": 5,
    "live-restore": true,
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOD
    fi

    # Call the docker_service_restart function
    docker_service_restart
    dialog --title "Success" --msgbox "Docker HTTP Proxy configured successfully!" 6 50
}

# Function to disable Docker HTTP proxy
disable_docker_proxy() {
    # Check if docker is installed
    if ! command -v docker &> /dev/null
    then
        dialog --title "Error" --msgbox "Docker not found!" 6 50
    fi
    if [ -f "/etc/systemd/system/docker.service.d/proxy.conf" ]; then
        rm -f /etc/systemd/system/docker.service.d/proxy.conf
        # Call the docker_service_restart function
        docker_service_restart
        dialog --title "Success" --msgbox "Docker proxy disabled successfully!" 6 50
    else
    dialog --title "Info" --msgbox "No Docker proxy configuration found." 6 50
    fi
}

# Function to set containerd (K8s container runtime) HTTP proxy
set_containerd_http_proxy() {
    # Check if containerd is installed
    if ! command -v containerd &> /dev/null
    then
        dialog --title "Error" --msgbox "Containerd not found!" 6 50
    fi
    sudo mkdir -p /etc/systemd/system/containerd.service.d
    if [ -f "etc/systemd/system/containerd.service.d/proxy.conf" ]; then
        rm -f etc/systemd/system/containerd.service.d/proxy.conf
    fi
    sudo cat << EOS > /etc/systemd/system/containerd.service.d/proxy.conf
[Service]
Environment="HTTP_PROXY=http://$HTTP_HOST:$HTTP_PORT" "HTTPS_PROXY=http://$HTTP_HOST:$HTTP_PORT" "NO_PROXY="$NO_PROXY_HOSTS""
EOS


    sudo systemctl daemon-reload
    sudo systemctl restart containerd
    dialog --title "Success" --msgbox "Containerd HTTP Proxy configured successfully!" 6 50
}

# Function to disable containerd (K8s container runtime) HTTP proxy
disable_containerd_proxy() {
    # Check if containerd is installed
    if ! command -v containerd &> /dev/null
    then
        dialog --title "Error" --msgbox "Containerd not found!" 6 50
    fi    
    if [ -f "etc/systemd/system/containerd.service.d/proxy.conf" ]; then
        rm -f etc/systemd/system/containerd.service.d/proxy.conf
        sudo systemctl daemon-reload
        sudo systemctl restart containerd
            dialog --title "Success" --msgbox "Containerd proxy disabled successfully!" 6 50
    else
            dialog --title "Info" --msgbox "No containerd proxy configuration found." 6 50
    fi
}

# Function to check proxy server location
check_proxy_server_location() {
    server_country=$(curl -s -x $1 http://ip-api.com/line/"$(curl -s -x $1 icanhazip.com)" | sed -n '2p')
}

# Function to test proxy performance
test_proxy_performance() {
    local proxy_url=$1
    local test_url="http://httpbin.org/bytes/1024"
    
    echo "Testing proxy performance..."
    echo "Proxy: $proxy_url"
    echo "Test URL: $test_url"
    echo ""
    
    # Test with proxy
    echo "With proxy:"
    time_start=$(date +%s%N)
    curl -x "$proxy_url" -o /dev/null -s --connect-timeout $PROXY_TIMEOUT --max-time $PROXY_READ_TIMEOUT "$test_url"
    time_end=$(date +%s%N)
    proxy_time=$(( (time_end - time_start) / 1000000 ))
    echo "Proxy response time: ${proxy_time}ms"
    echo ""
    
    # Test without proxy
    echo "Without proxy:"
    time_start=$(date +%s%N)
    curl -o /dev/null -s --connect-timeout $PROXY_TIMEOUT --max-time $PROXY_READ_TIMEOUT "$test_url"
    time_end=$(date +%s%N)
    direct_time=$(( (time_end - time_start) / 1000000 ))
    echo "Direct response time: ${direct_time}ms"
    echo ""
    
    # Calculate overhead
    overhead=$(( proxy_time - direct_time ))
    echo "Proxy overhead: ${overhead}ms"
    
    if [ $overhead -lt 100 ]; then
        echo "Performance: Excellent (< 100ms overhead)"
    elif [ $overhead -lt 300 ]; then
        echo "Performance: Good (< 300ms overhead)"
    elif [ $overhead -lt 500 ]; then
        echo "Performance: Fair (< 500ms overhead)"
    else
        echo "Performance: Poor (> 500ms overhead)"
    fi
}

# Function to check proxy health
check_proxy_health() {
    local proxy_url=$1
    local health_url="http://httpbin.org/status/200"
    
    echo "Checking proxy health..."
    response=$(curl -x "$proxy_url" -o /dev/null -s -w "%{http_code}" --connect-timeout $PROXY_TIMEOUT --max-time $PROXY_READ_TIMEOUT "$health_url")
    
    if [ "$response" = "200" ]; then
        echo "Proxy health: OK"
        return 0
    else
        echo "Proxy health: FAILED (HTTP $response)"
        return 1
    fi
}

# Function to backup existing proxychains configuration
backup_proxychains_config() {
    if [ -f "$PROXYCHAINS_CONF_PATH" ]; then
        sudo cp "$PROXYCHAINS_CONF_PATH" "${PROXYCHAINS_CONF_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "Backed up existing proxychains configuration"
    fi
}

# Function to set proxychains HTTP proxy configuration
set_proxychains_http_proxy() {
    # Check if proxychains is installed and offer to install if not
    if ! check_and_install_proxychains; then
        return 1
    fi
    
    # Backup existing configuration
    backup_proxychains_config
    
    # Create optimized proxychains configuration
    sudo cat << EOP > $PROXYCHAINS_CONF_PATH
# proxychains.conf  VER 3.1
#
#        HTTP, SOCKS4, SOCKS5 tunneling proxifier with DNS.
#	Configured by QProxy v$VERSION

# Dynamic chain mode for better reliability
dynamic_chain
#
# Dynamic - Each connection will be done via chained proxies
# all proxies chained in the order as they appear in the list
# at least one proxy must be online to play in chain
# (dead proxies are skipped)
# otherwise EINTR is returned to the app
# RECOMMENDED: Better reliability and performance

# Quiet mode (no output from library)
#quiet_mode
# RECOMMENDED: Keep enabled for cleaner output in production

# Proxy DNS requests - no leak for DNS data
proxy_dns 
# CRITICAL: Prevents DNS leaks, always keep enabled

# Some timeouts in milliseconds (optimized for performance)
tcp_read_time_out 10000
tcp_connect_time_out 5000
# OPTIMIZED: Reduced timeouts for better performance
# - Read timeout: 10s - faster failure detection
# - Connect timeout: 5s - quicker connection attempts

# ProxyList format
#       type  host  port [user pass]
#       (values separated by 'tab' or 'blank')

[ProxyList]
# HTTP Proxy configured by QProxy
http 	$HTTP_HOST $HTTP_PORT

EOP
    
    dialog --title "Success" --msgbox "Proxychains HTTP Proxy configured successfully!" 6 50
}

# Function to set proxychains SOCKS5 proxy configuration
set_proxychains_socks5_proxy() {
    # Check if proxychains is installed and offer to install if not
    if ! check_and_install_proxychains; then
        return 1
    fi
    
    # Backup existing configuration
    backup_proxychains_config
    
    # Create optimized proxychains configuration
    sudo cat << EOP > $PROXYCHAINS_CONF_PATH
# proxychains.conf  VER 3.1
#
#        HTTP, SOCKS4, SOCKS5 tunneling proxifier with DNS.
#	Configured by QProxy v$VERSION

# Dynamic chain mode for better reliability
dynamic_chain
#
# Dynamic - Each connection will be done via chained proxies
# all proxies chained in the order as they appear in the list
# at least one proxy must be online to play in chain
# (dead proxies are skipped)
# otherwise EINTR is returned to the app
# RECOMMENDED: Better reliability and performance

# Quiet mode (no output from library)
#quiet_mode
# RECOMMENDED: Keep enabled for cleaner output in production

# Proxy DNS requests - no leak for DNS data
proxy_dns 
# CRITICAL: Prevents DNS leaks, always keep enabled

# Some timeouts in milliseconds (optimized for performance)
tcp_read_time_out 10000
tcp_connect_time_out 5000
# OPTIMIZED: Reduced timeouts for better performance
# - Read timeout: 10s - faster failure detection
# - Connect timeout: 5s - quicker connection attempts

# ProxyList format
#       type  host  port [user pass]
#       (values separated by 'tab' or 'blank')

[ProxyList]
# SOCKS5 Proxy configured by QProxy
socks5 	$SOCKS5_HOST $SOCKS5_PORT

EOP
    
    dialog --title "Success" --msgbox "Proxychains SOCKS5 Proxy configured successfully!" 6 50
}

# Function to set proxychains with both HTTP and SOCKS5 proxies
set_proxychains_dual_proxy() {
    # Check if proxychains is installed and offer to install if not
    if ! check_and_install_proxychains; then
        return 1
    fi
    
    # Backup existing configuration
    backup_proxychains_config
    
    # Create optimized proxychains configuration with both proxies
    sudo cat << EOP > $PROXYCHAINS_CONF_PATH
# proxychains.conf  VER 3.1
#
#        HTTP, SOCKS4, SOCKS5 tunneling proxifier with DNS.
#	Configured by QProxy v$VERSION

# Dynamic chain mode for better reliability
dynamic_chain
#
# Dynamic - Each connection will be done via chained proxies
# all proxies chained in the order as they appear in the list
# at least one proxy must be online to play in chain
# (dead proxies are skipped)
# otherwise EINTR is returned to the app
# RECOMMENDED: Better reliability and performance

# Quiet mode (no output from library)
#quiet_mode
# RECOMMENDED: Keep enabled for cleaner output in production

# Proxy DNS requests - no leak for DNS data
proxy_dns 
# CRITICAL: Prevents DNS leaks, always keep enabled

# Some timeouts in milliseconds (optimized for performance)
tcp_read_time_out 10000
tcp_connect_time_out 5000
# OPTIMIZED: Reduced timeouts for better performance
# - Read timeout: 10s - faster failure detection
# - Connect timeout: 5s - quicker connection attempts

# ProxyList format
#       type  host  port [user pass]
#       (values separated by 'tab' or 'blank')

[ProxyList]
# HTTP Proxy (primary - faster for web traffic)
http 	$HTTP_HOST $HTTP_PORT

# SOCKS5 Proxy (secondary - better protocol support)
socks5 	$SOCKS5_HOST $SOCKS5_PORT

EOP
    
    dialog --title "Success" --msgbox "Proxychains Dual Proxy configured successfully!" 6 50
}

# Function to disable proxychains configuration
disable_proxychains_config() {
    if [ -f "$PROXYCHAINS_CONF_PATH" ]; then
        # Backup before disabling
        backup_proxychains_config
        
        # Restore default configuration
        sudo cat << EOP > $PROXYCHAINS_CONF_PATH
# proxychains.conf  VER 3.1
#
#        HTTP, SOCKS4, SOCKS5 tunneling proxifier with DNS.

# Dynamic chain mode
dynamic_chain

# Proxy DNS requests - no leak for DNS data
proxy_dns 

# Some timeouts in milliseconds
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
# Default to tor (commented out)
# socks4 	127.0.0.1 9050

EOP
        dialog --title "Success" --msgbox "Proxychains configuration disabled successfully!" 6 50
    else
        dialog --title "Info" --msgbox "No proxychains configuration found." 6 50
    fi
}

# Function to test proxychains configuration
test_proxychains_config() {
    # Check if proxychains is installed and offer to install if not
    if ! check_and_install_proxychains; then
        return 1
    fi
    
    # Check if configuration file exists
    if [ ! -f "$PROXYCHAINS_CONF_PATH" ]; then
        dialog --title "Error" --msgbox "Proxychains configuration file not found!" 6 50
        return 1
    fi
    
    # Test proxychains connectivity
    echo "Testing proxychains configuration..."
    echo "Configuration file: $PROXYCHAINS_CONF_PATH"
    echo ""
    
    # Test with a simple HTTP request
    test_result=$(proxychains4 curl -s --connect-timeout 10 --max-time 15 http://httpbin.org/ip 2>&1)
    
    if [ $? -eq 0 ] && [[ "$test_result" == *"origin"* ]]; then
        echo "✅ Proxychains test successful!"
        echo "Response: $test_result"
        dialog --title "Success" --msgbox "Proxychains test successful!" 6 50
    else
        echo "❌ Proxychains test failed!"
        echo "Error: $test_result"
        dialog --title "Error" --msgbox "Proxychains test failed!\n\nPlease check your proxy configuration." 7 50
    fi
}

# Function to configure proxy settings interactively
configure_proxy_settings() {
    init_qproxy_config
    dialog --title "Proxy Configuration Setup" \
    --msgbox "Welcome to QProxy Configuration!\n\nThis will help you set up your proxy settings easily.\n\nYou can configure:\n- HTTP Proxy\n- SOCKS5 Proxy\n- Both (for redundancy)\n\nLet's start!" 10 50
    
    # Ask for HTTP Proxy
    dialog --title "HTTP Proxy Configuration" \
    --yesno "Do you want to configure an HTTP Proxy?\n\nHTTP proxies are good for web browsing and most applications." 8 50
    
    if [ $? -eq 0 ]; then
        # Get HTTP Proxy details
        dialog --title "HTTP Proxy Settings" \
        --form "Enter your HTTP Proxy details:" 12 50 0 \
        "HTTP Proxy Host/IP:" 1 1 "$HTTP_HOST" 1 25 20 0 \
        "HTTP Proxy Port:" 2 1 "$HTTP_PORT" 2 25 10 0 2>tempfile
        
        if [ $? -eq 0 ]; then
            read -r new_http_host new_http_port < tempfile
            if [ -n "$new_http_host" ] && [ -n "$new_http_port" ]; then
                HTTP_HOST="$new_http_host"
                HTTP_PORT="$new_http_port"
                save_qproxy_env_file
                dialog --title "Success" --msgbox "HTTP Proxy configured and saved:\nHost: $HTTP_HOST\nPort: $HTTP_PORT\n\nConfig file:\n$QPROXY_ENV_FILE" 9 60
            fi
        fi
    fi
    
    # Ask for SOCKS5 Proxy
    dialog --title "SOCKS5 Proxy Configuration" \
    --yesno "Do you want to configure a SOCKS5 Proxy?\n\nSOCKS5 proxies support more protocols and are more versatile." 8 50
    
    if [ $? -eq 0 ]; then
        # Get SOCKS5 Proxy details
        dialog --title "SOCKS5 Proxy Settings" \
        --form "Enter your SOCKS5 Proxy details:" 12 50 0 \
        "SOCKS5 Proxy Host/IP:" 1 1 "$SOCKS5_HOST" 1 25 20 0 \
        "SOCKS5 Proxy Port:" 2 1 "$SOCKS5_PORT" 2 25 10 0 2>tempfile
        
        if [ $? -eq 0 ]; then
            read -r new_socks5_host new_socks5_port < tempfile
            if [ -n "$new_socks5_host" ] && [ -n "$new_socks5_port" ]; then
                SOCKS5_HOST="$new_socks5_host"
                SOCKS5_PORT="$new_socks5_port"
                save_qproxy_env_file
                dialog --title "Success" --msgbox "SOCKS5 Proxy configured and saved:\nHost: $SOCKS5_HOST\nPort: $SOCKS5_PORT\n\nConfig file:\n$QPROXY_ENV_FILE" 9 60
            fi
        fi
    fi
    
    # Show current configuration
    show_current_configuration
}

# Function to save proxy configuration to the user env file
save_proxy_configuration() {
    save_qproxy_env_file
    dialog --title "Success" --msgbox "Proxy configuration saved to:\n$QPROXY_ENV_FILE\n\nAll proxy actions will use these values." 8 60
}

# Function to show current configuration
show_current_configuration() {
    resolve_qproxy_env_file
    dialog --title "Current Proxy Configuration" \
    --msgbox "Current Proxy Settings:\n\nHTTP Proxy:\n  Host: $HTTP_HOST\n  Port: $HTTP_PORT\n\nSOCKS5 Proxy:\n  Host: $SOCKS5_HOST\n  Port: $SOCKS5_PORT\n\nNO_PROXY Hosts:\n  $NO_PROXY_HOSTS\n\nConfig file:\n  $QPROXY_ENV_FILE" 14 60
}

# Function to test current proxy configuration
test_current_proxy_config() {
    dialog --title "Testing Proxy Configuration" --infobox "Testing your current proxy settings..." 4 50
    
    local test_results=""
    local has_working_proxy=false
    
    # Test HTTP Proxy if configured
    if [ "$HTTP_HOST" != "$DEFAULT_HTTP_HOST" ] || [ "$HTTP_PORT" != "$DEFAULT_HTTP_PORT" ]; then
        if check_proxy_health "http://$HTTP_HOST:$HTTP_PORT"; then
            test_results="$test_results\n✅ HTTP Proxy: WORKING"
            has_working_proxy=true
        else
            test_results="$test_results\n❌ HTTP Proxy: FAILED"
        fi
    else
        test_results="$test_results\n⚪ HTTP Proxy: Not configured"
    fi
    
    # Test SOCKS5 Proxy if configured
    if [ "$SOCKS5_HOST" != "$DEFAULT_SOCKS5_HOST" ] || [ "$SOCKS5_PORT" != "$DEFAULT_SOCKS5_PORT" ]; then
        if check_proxy_health "socks5h://$SOCKS5_HOST:$SOCKS5_PORT"; then
            test_results="$test_results\n✅ SOCKS5 Proxy: WORKING"
            has_working_proxy=true
        else
            test_results="$test_results\n❌ SOCKS5 Proxy: FAILED"
        fi
    else
        test_results="$test_results\n⚪ SOCKS5 Proxy: Not configured"
    fi
    
    if [ "$has_working_proxy" = true ]; then
        dialog --title "Proxy Test Results" --msgbox "Proxy Test Results:$test_results\n\n🎉 You have working proxy servers!" 10 50
    else
        dialog --title "Proxy Test Results" --msgbox "Proxy Test Results:$test_results\n\n⚠️ No working proxies found.\nPlease check your configuration." 10 50
    fi
}

# Function to launch proxychains shell with health testing
launch_proxychains_shell() {
    # Check if proxychains is installed and offer to install if not
    if ! check_and_install_proxychains; then
        return 1
    fi
    
    # Check if configuration file exists
    if [ ! -f "$PROXYCHAINS_CONF_PATH" ]; then
        dialog --title "Error" --msgbox "Proxychains configuration file not found!\n\nPlease configure proxychains first." 7 50
        return 1
    fi
    
    # Test proxy health first
    dialog --title "Testing Proxy Health" --infobox "Testing proxy server health before launching shell..." 4 50
    
    # Test HTTP proxy if configured
    if grep -q "http.*$HTTP_HOST.*$HTTP_PORT" "$PROXYCHAINS_CONF_PATH" 2>/dev/null; then
        if ! check_proxy_health "http://$HTTP_HOST:$HTTP_PORT"; then
            dialog --title "Error" --msgbox "HTTP Proxy health check failed!\n\nCannot launch proxychains shell with unhealthy proxy." 7 50
            return 1
        fi
    fi
    
    # Test SOCKS5 proxy if configured
    if grep -q "socks5.*$SOCKS5_HOST.*$SOCKS5_PORT" "$PROXYCHAINS_CONF_PATH" 2>/dev/null; then
        if ! check_proxy_health "socks5h://$SOCKS5_HOST:$SOCKS5_PORT"; then
            dialog --title "Error" --msgbox "SOCKS5 Proxy health check failed!\n\nCannot launch proxychains shell with unhealthy proxy." 7 50
            return 1
        fi
    fi
    
    # Test proxychains connectivity
    dialog --title "Testing Proxychains" --infobox "Testing proxychains connectivity..." 4 50
    test_result=$(proxychains4 curl -s --connect-timeout 10 --max-time 15 http://httpbin.org/ip 2>&1)
    
    if [ $? -eq 0 ] && [[ "$test_result" == *"origin"* ]]; then
        dialog --title "Success" --msgbox "Proxy health check passed!\n\nLaunching proxychains shell..." 6 50
        
        # Clear screen and show info
        clear
        echo "=========================================="
        echo "  🚀 Proxychains Shell Launched"
        echo "=========================================="
        echo "✅ Proxy health check: PASSED"
        echo "✅ Proxychains test: PASSED"
        echo "🌐 All network traffic will go through proxy"
        echo "💡 Type 'exit' to return to QProxy"
        echo "=========================================="
        echo ""
        
        # Launch proxychains shell
        exec proxychains4 bash
    else
        dialog --title "Error" --msgbox "Proxychains test failed!\n\nCannot launch shell with non-functional proxy." 7 50
        return 1
    fi
}

# Test the OS Proxy and Print the Proxy Server Location
test_os_env_proxy() {
    server_country=""
    if [[ $HTTP_PROXY == "http://$HTTP_HOST:$HTTP_PORT" ]] || [[ $HTTPS_PROXY == "http://$HTTP_HOST:$HTTP_PORT" ]]; then
        check_proxy_server_location $HTTP_PROXY
        if [ "$server_country" != "Iran" ]; then
            dialog --title "Success" --msgbox "HTTP Proxy test successful!\n\nServer location: $server_country" 7 50
        else
            dialog --title "Error" --msgbox "HTTP Proxy test failed!" 6 50
            fi
    elif [[ $HTTP_PROXY == "socks5h://$SOCKS5_HOST:$SOCKS5_PORT" ]] || [[ $HTTPS_PROXY == "socks5h://$SOCKS5_HOST:$SOCKS5_PORT" ]]; then
        check_proxy_server_location $HTTP_PROXY
        if [ "$server_country" != "Iran" ]; then
            dialog --title "Success" --msgbox "SOCKS5 Proxy test successful!\n\nServer location: $server_country" 7 50
        else
            dialog --title "Error" --msgbox "SOCKS5 Proxy test failed!" 6 50
            fi
    else
        dialog --title "Info" --msgbox "No matching proxy configuration found." 6 50
    fi
}

# Function to test the APT Proxy setting
test_apt_proxy() {
    # Check if apt is installed
    if ! command -v apt &> /dev/null
    then
        dialog --title "Error" --msgbox "APT package manager not found!" 6 50
    fi    
    apt clean && apt autoclean >/dev/null 2>&1 && apt update -qq >/dev/null 2>&1
    if [ $? == 0 ]; then
        dialog --title "Success" --msgbox "APT Proxy test successful!" 6 50
    else
        dialog --title "Error" --msgbox "APT Proxy test failed!" 6 50
    fi
}

# Function to test the DNF/YUM Proxy setting
test_dnf_proxy() {
    # Check if dnf or yum is installed
    if ! command -v dnf &> /dev/null && ! command -v yum &> /dev/null
    then
        dialog --title "Error" --msgbox "DNF/YUM package manager not found!" 6 50
        return 1
    fi
    
    # Test with dnf if available, otherwise yum
    if command -v dnf &> /dev/null; then
        dnf clean all >/dev/null 2>&1 && dnf check-update >/dev/null 2>&1
    else
        yum clean all >/dev/null 2>&1 && yum check-update >/dev/null 2>&1
    fi
    
    if [ $? == 0 ]; then
        dialog --title "Success" --msgbox "DNF/YUM Proxy test successful!" 6 50
    else
        dialog --title "Error" --msgbox "DNF/YUM Proxy test failed!" 6 50
    fi
}

# Function to test the Pacman Proxy setting
test_pacman_proxy() {
    # Check if pacman is installed
    if ! command -v pacman &> /dev/null
    then
        dialog --title "Error" --msgbox "Pacman package manager not found!" 6 50
        return 1
    fi
    
    # Test pacman with proxy
    pacman -Sy >/dev/null 2>&1
    if [ $? == 0 ]; then
        dialog --title "Success" --msgbox "Pacman Proxy test successful!" 6 50
    else
        dialog --title "Error" --msgbox "Pacman Proxy test failed!" 6 50
    fi
}

# Function to test the Zypper Proxy setting
test_zypper_proxy() {
    # Check if zypper is installed
    if ! command -v zypper &> /dev/null
    then
        dialog --title "Error" --msgbox "Zypper package manager not found!" 6 50
        return 1
    fi
    
    # Test zypper with proxy
    zypper refresh >/dev/null 2>&1
    if [ $? == 0 ]; then
        dialog --title "Success" --msgbox "Zypper Proxy test successful!" 6 50
    else
        dialog --title "Error" --msgbox "Zypper Proxy test failed!" 6 50
    fi
}

# Function to test the Docker Proxy setting
test_docker_proxy() {
    # Check if Docker is installed
    if ! command -v docker &> /dev/null
    then
        dialog --title "Error" --msgbox "Docker could not be found. Please install Docker first." 6 50
    fi

    # Check if the proxy.conf file contains "http://" or "socks5h://"
    if ! grep -q -E 'http://|socks5h://' /etc/systemd/system/docker.service.d/proxy.conf
    then
        dialog --title "Error" --msgbox "The proxy.conf file does not contain 'http://' or 'socks5h://'. Please check the proxy settings." 6 50
    fi

    # If both checks pass, run the Docker command
    docker search nginx >/dev/null 2>&1
    if [ $? == 0 ]; then
        dialog --title "Success" --msgbox "Docker Proxy test successful!" 6 50
    else
        dialog --title "Error" --msgbox "Docker Proxy test failed!" 6 50
    fi
}


# Function to test the containerd Proxy setting
test_containerd_proxy() {
    # Check if containerd is installed
    if ! command -v containerd &> /dev/null
    then
        dialog --title "Error" --msgbox "Containerd could not be found. Please install containerd first." 6 50
    fi

    # Check if the proxy.conf file contains "http://"
    if ! grep -q 'http://' /etc/systemd/system/containerd.service.d/proxy.conf
    then
        dialog --title "Error" --msgbox "The proxy.conf file does not contain 'http://'. Please check the proxy settings." 6 50
    fi

    # If both checks pass, run the containerd command
    ctr images pull docker.io/library/alpine:latest >/dev/null 2>&1
    if [ $? == 0 ]; then
        dialog --title "Success" --msgbox "Containerd Proxy test successful!" 6 50
    else
        dialog --title "Error" --msgbox "Containerd Proxy test failed!" 6 50
    fi
}


# Main function - only run when script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
init_qproxy_config
# Call the check dependencies function
check_deps
while true; do
    dialog --title "Manage the proxy configs on Linux and services quickly" \
    --backtitle "$SCRIPT_NAME" \
    --menu "Choose the action you want to perform (with space or mouse click):" 14 70 10 \
    1 "Configure Proxy Settings" \
    2 "Enable Proxy" \
    3 "Disable Proxy" \
    4 "Test Proxies" \
    5 "Configure Proxychains" \
    6 "Apply Proxy to Current Session" \
    7 "Exit" 2>tempfile

    # Read the selection
    selection=$(<tempfile)

    # Check the user's selection
    case $selection in
        1)
            dialog --title "Proxy Configuration" \
            --menu "Choose configuration option:" 10 50 4 \
            1 "Configure Proxy Settings" \
            2 "Show Current Configuration" \
            3 "Test Current Configuration" \
            4 "Back to Main Menu" 2>tempfile

            # Read the selection
            config_selection=$(<tempfile)

            # Check the user's selection
            case $config_selection in
                1)
                    configure_proxy_settings
                    ;;
                2)
                    init_qproxy_config
                    show_current_configuration
                    ;;
                3)
                    test_current_proxy_config
                    ;;
                4)
                    continue
                    ;;
            esac
            ;;
        2)
            dialog --title "Enable Proxy" \
            --checklist "Where you want to set the HTTP/SOCKS5 Proxy:" 14 70 8 \
            1 "Enable HTTP Proxy on OS ENV" off \
            2 "Enable SOCKS5 Proxy on OS ENV" off \
            3 "Enable HTTP Proxy on Package Manager (Auto-detect)" off \
            4 "Enable SOCKS5 Proxy on APT (Debian/Ubuntu only)" off \
            5 "Enable HTTP Proxy on Docker Service" off \
            6 "Enable HTTP Proxy on Containerd (K8s) Service" off 2>tempfile

            # Read the selections
            selections=$(<tempfile)

            # Check the user's selections
            for selection in $selections
            do
                case $selection in
                    1)
                        set_os_env_http_proxy
                        ;;
                    2)
                        set_os_env_socks5_proxy
                        ;;
                    3)
                        set_auto_package_manager_proxy
                        ;;
                    4)
                        set_apt_socks5_proxy
                        ;;
                    5)
                        set_docker_http_proxy
                        ;;
                    6)
                        set_containerd_http_proxy
                        ;;
                esac
            done
            ;;
        3)
            dialog --title "Disable Proxy" \
            --checklist "Choose the action you want to perform (with space or mouse click):" 14 70 6 \
            1 "Disable HTTP/SOCKS5 Proxy on OS ENV" off \
            2 "Disable HTTP Proxy on Package Manager (Auto-detect)" off \
            3 "Disable HTTP/SOCKS5 Proxy on APT" off \
            4 "Disable HTTP/SOCKS5 Proxy on Docker Service" off \
            5 "Disable HTTP/SOCKS5 Proxy on Containerd (K8s) Service" off \
            6 "Disable HTTP/SOCKS5 Completely" off 2>tempfile

            # Read the selections
            selections=$(<tempfile)

            # Check the user's selections
            for selection in $selections
            do
                case $selection in
                    1)
                        disable_os_env_proxy
                        ;;
                    2)
                        remove_auto_package_manager_proxy
                        ;;  
                    3)
                        remove_old_apt_proxy
                        ;;
                    4)
                        disable_docker_proxy
                        ;;
                    5)
                        disable_containerd_proxy
                        ;;
                    6)
                        disable_os_env_proxy
                        remove_auto_package_manager_proxy
                        disable_docker_proxy
                        disable_containerd_proxy
                        ;;
                esac
            done
            ;;
        4)
            dialog --title "Test Proxies" \
            --menu "Choose the action you want to test:" 14 70 9 \
            1 "Test OS Proxy" \
            2 "Test Docker Proxy" \
            3 "Test Package Manager Proxy (Auto-detect)" \
            4 "Test APT Proxy (Debian/Ubuntu only)" \
            5 "Test Proxy Performance" \
            6 "Test Proxy Health" 2>tempfile

            # Read the selection
            test_selection=$(<tempfile)

            # Check the user's selection
            case $test_selection in
                1)
                    test_os_env_proxy
                    ;;
                2)
                    test_docker_proxy
                    ;;
                3)
                    test_auto_package_manager_proxy
                    ;;
                4)
                    test_apt_proxy
                    ;;
                5)
                    dialog --title "Proxy Performance Test" \
                    --menu "Choose proxy to test:" 10 50 3 \
                    1 "HTTP Proxy Performance" \
                    2 "SOCKS5 Proxy Performance" 2>tempfile
                    perf_selection=$(<tempfile)
                    case $perf_selection in
                        1)
                            test_proxy_performance "http://$HTTP_HOST:$HTTP_PORT" | dialog --title "HTTP Proxy Performance" --programbox 20 80
                            ;;
                        2)
                            test_proxy_performance "socks5h://$SOCKS5_HOST:$SOCKS5_PORT" | dialog --title "SOCKS5 Proxy Performance" --programbox 20 80
                    ;;
            esac
            ;;
                6)
                    dialog --title "Proxy Health Test" \
                    --menu "Choose proxy to test:" 10 50 3 \
                    1 "HTTP Proxy Health" \
                    2 "SOCKS5 Proxy Health" 2>tempfile
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
                    ;;
            esac
            ;;
        5)
            # Check if proxychains is available before showing menu
            if ! command -v proxychains4 &> /dev/null; then
                dialog --title "Proxychains4 Not Available" \
                --yesno "Proxychains4 is not installed on your system.\n\nProxychains4 is required for proxy chain functionality.\n\nWould you like to install it now?" 10 60
                
                if [ $? -eq 0 ]; then
                    if ! check_and_install_proxychains; then
                        continue
                    fi
                else
                    dialog --title "Info" --msgbox "Proxychains4 installation cancelled.\n\nYou can install it later with:\napt install proxychains4" 8 50
                    continue
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

            # Read the selection
            proxychains_selection=$(<tempfile)

            # Check the user's selection
            case $proxychains_selection in
                1)
                    set_proxychains_http_proxy
                    ;;
                2)
                    set_proxychains_socks5_proxy
                    ;;
                3)
                    set_proxychains_dual_proxy
                    ;;
                4)
                    disable_proxychains_config
                    ;;
                5)
                    test_proxychains_config
                    ;;
                6)
                    launch_proxychains_shell
                    ;;
            esac
            ;;
        6)
            dialog --title "Apply Proxy to Current Session" \
            --menu "Choose proxy type to apply to current session:" 10 50 3 \
            1 "Apply HTTP Proxy to Current Session" \
            2 "Apply SOCKS5 Proxy to Current Session" \
            3 "Remove Proxy from Current Session" 2>tempfile

            # Read the selection
            session_selection=$(<tempfile)

            # Check the user's selection
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
            ;;
        7)
            echo "Exiting..."
            break
            ;;
    esac
done


# Apply pending session env when returning to the user's shell
finalize_qproxy_session_apply

# Clear the screen
clear

# Remove the tempfile
rm -f tempfile
fi
