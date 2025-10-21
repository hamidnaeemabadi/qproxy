#!/bin/bash
########################################################
# Author: [Hamid Naeemabadi]
# Script Name: QProxy
# Purpose: [Manage the proxy configs on Linux and services quickly.]
########################################################

# Vars
VERSION="v1.6"

SCRIPT_NAME="QProxy for Linux $VERSION by Hamid Naeemabadi"

# SOCKS5 Proxy
SOCKS5_HOST="10.X.X.X"
SOCKS5_PORT="1080"

# HTTP Proxy
HTTP_HOST="10.X.X.X"
HTTP_PORT="3128"

# Exclude the Private IP subnets and local ORG domain
NO_PROXY_HOSTS="127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,example.local,localhost,*.local"

# Performance and timeout settings
PROXY_TIMEOUT=30
PROXY_READ_TIMEOUT=60

USER_PROXY_ENV_PATH="/etc/profile.d/user_proxy_env.sh"
PROXYCHAINS_CONF_PATH="/etc/proxychains4.conf"

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
                        dialog --title "Success" --msgbox "Proxychains4 installed successfully!\n\nYou can now use the proxychains configuration features." 8 50
                        return 0
                    else
                        dialog --title "Error" --msgbox "Failed to install proxychains4.\n\nPlease install it manually:\napt install proxychains4" 8 50
                        return 1
                    fi
                    ;;
                "fedora"|"rhel"|"centos"|"rocky"|"almalinux"|"oracle")
                    if sudo dnf install -y -q proxychains-ng >/dev/null 2>&1 || sudo yum install -y -q proxychains-ng >/dev/null 2>&1; then
                        dialog --title "Success" --msgbox "Proxychains-ng installed successfully!\n\nYou can now use the proxychains configuration features." 8 50
                        return 0
                    else
                        dialog --title "Error" --msgbox "Failed to install proxychains-ng.\n\nPlease install it manually:\ndnf install proxychains-ng\nor\nyum install proxychains-ng" 10 50
                        return 1
                    fi
                    ;;
                "arch"|"manjaro"|"endeavouros")
                    if sudo pacman -S --noconfirm proxychains-ng >/dev/null 2>&1; then
                        dialog --title "Success" --msgbox "Proxychains-ng installed successfully!\n\nYou can now use the proxychains configuration features." 8 50
                        return 0
                    else
                        dialog --title "Error" --msgbox "Failed to install proxychains-ng.\n\nPlease install it manually:\npacman -S proxychains-ng" 8 50
                        return 1
                    fi
                    ;;
                "opensuse"|"sles")
                    if sudo zypper install -y proxychains-ng >/dev/null 2>&1; then
                        dialog --title "Success" --msgbox "Proxychains-ng installed successfully!\n\nYou can now use the proxychains configuration features." 8 50
                        return 0
                    else
                        dialog --title "Error" --msgbox "Failed to install proxychains-ng.\n\nPlease install it manually:\nzypper install proxychains-ng" 8 50
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
            
            dialog --title "Info" --msgbox "Proxychains4 installation cancelled.\n\nYou can install it later with:\n$manual_cmd" 8 50
            return 1
        fi
    else
        return 0
    fi
}

# Function to set os http proxy
set_os_env_http_proxy() {
    # Check proxy health before setting
    if ! check_proxy_health "http://$HTTP_HOST:$HTTP_PORT"; then
        dialog --title "Warning" --msgbox "Proxy health check failed. Proceeding anyway, but you may experience issues." 7 50
    fi
    
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
    source $USER_PROXY_ENV_PATH
    dialog --title "Success" --msgbox "HTTP Proxy enabled on OS ENV successfully, Please logoff and reconnect to the server to unset proxy from your shell." 7 50
}

# Function to set os socks5 proxy
set_os_env_socks5_proxy() {
    # Check proxy health before setting
    if ! check_proxy_health "socks5h://$SOCKS5_HOST:$SOCKS5_PORT"; then
        dialog --title "Warning" --msgbox "Proxy health check failed. Proceeding anyway, but you may experience issues." 7 50
    fi
    
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
    source $USER_PROXY_ENV_PATH
    dialog --title "Success" --msgbox "SOCKS5 Proxy enabled on OS ENV successfully, Please logoff and reconnect to the server to unset proxy from your shell." 7 50
}

# Function to disable os proxy
disable_os_env_proxy() {
    rm -f $USER_PROXY_ENV_PATH
    unset HTTP_PROXY
    unset http_proxy
    unset HTTPS_PROXY
    unset https_proxy
    unset NO_PROXY
    unset no_proxy
    dialog --title "Success" --msgbox "HTTP/SOCKS5 Proxy disabled on OS ENV successfully, Please logoff and reconnect to the server to unset proxy from your shell." 7 50
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
        dialog --title "Success" --msgbox "HTTP/SOCKS5 Proxy disabled on APT successfully." 7 50
    fi
}

# Function to set APT HTTP proxy
set_apt_http_proxy() {
    # Check if apt is installed
    if ! command -v apt &> /dev/null
    then
        dialog --title "Error" --msgbox "apt could not be found." 6 50
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
    dialog --title "Success" --msgbox "HTTP Proxy enabled on apt package-manager successfully with performance optimizations." 7 50
}

# Function to set APT SOCKS5 proxy
set_apt_socks5_proxy() {
    # Check if apt is installed
    if ! command -v apt &> /dev/null
    then
        dialog --title "Error" --msgbox "apt could not be found." 6 50
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
    dialog --title "Success" --msgbox "SOCKS5 Proxy enabled on apt package-manager successfully with performance optimizations." 7 50
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
        dialog --title "Error" --msgbox "docker could not be found." 6 50
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
    dialog --title "Success" --msgbox "HTTP Proxy enabled on Docker Service successfully with performance optimizations!" 6 50
}

# Function to disable Docker HTTP proxy
disable_docker_proxy() {
    # Check if docker is installed
    if ! command -v docker &> /dev/null
    then
        dialog --title "Error" --msgbox "docker could not be found." 6 50
    fi
    if [ -f "/etc/systemd/system/docker.service.d/proxy.conf" ]; then
        rm -f /etc/systemd/system/docker.service.d/proxy.conf
        # Call the docker_service_restart function
        docker_service_restart
        dialog --title "Success" --msgbox "HTTP/SOCKS5 Proxy disabled on Docker Service successfully!" 6 50
    else
    dialog --title "Info" --msgbox "The proxy was not configured in the Docker service." 6 50
    fi
}

# Function to set containerd (K8s container runtime) HTTP proxy
set_containerd_http_proxy() {
    # Check if containerd is installed
    if ! command -v containerd &> /dev/null
    then
        dialog --title "Error" --msgbox "containerd could not be found." 6 50
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
    dialog --title "Success" --msgbox "HTTP Proxy enabled on containerd (K8s container runtime) Service successfully!" 6 50
}

# Function to disable containerd (K8s container runtime) HTTP proxy
disable_containerd_proxy() {
    # Check if containerd is installed
    if ! command -v containerd &> /dev/null
    then
        dialog --title "Error" --msgbox "containerd could not be found." 6 50
    fi    
    if [ -f "etc/systemd/system/containerd.service.d/proxy.conf" ]; then
        rm -f etc/systemd/system/containerd.service.d/proxy.conf
        sudo systemctl daemon-reload
        sudo systemctl restart containerd
            dialog --title "Success" --msgbox "HTTP/SOCKS5 Proxy disabled on containerd (K8s container runtime) Service successfully!" 6 50
    else
            dialog --title "Info" --msgbox "The proxy was not configured in the containerd (K8s container runtime) service." 6 50
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
    
    dialog --title "Success" --msgbox "HTTP Proxy configured in proxychains successfully!\n\nConfiguration:\n- Chain Mode: dynamic_chain\n- Proxy: http://$HTTP_HOST:$HTTP_PORT\n- DNS Protection: Enabled\n- Timeouts: Optimized" 10 60
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
    
    dialog --title "Success" --msgbox "SOCKS5 Proxy configured in proxychains successfully!\n\nConfiguration:\n- Chain Mode: dynamic_chain\n- Proxy: socks5://$SOCKS5_HOST:$SOCKS5_PORT\n- DNS Protection: Enabled\n- Timeouts: Optimized" 10 60
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
    
    dialog --title "Success" --msgbox "Dual Proxy configured in proxychains successfully!\n\nConfiguration:\n- Chain Mode: dynamic_chain\n- Primary: http://$HTTP_HOST:$HTTP_PORT\n- Secondary: socks5://$SOCKS5_HOST:$SOCKS5_PORT\n- DNS Protection: Enabled\n- Timeouts: Optimized" 12 60
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
        dialog --title "Success" --msgbox "Proxychains configuration disabled successfully!\n\nDefault configuration restored." 7 50
    else
        dialog --title "Info" --msgbox "No proxychains configuration found to disable." 6 50
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
        dialog --title "Error" --msgbox "Proxychains configuration file not found at $PROXYCHAINS_CONF_PATH" 7 50
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
        dialog --title "Success" --msgbox "Proxychains configuration is working correctly!\n\nTest successful - proxy chain is functional." 8 50
    else
        echo "❌ Proxychains test failed!"
        echo "Error: $test_result"
        dialog --title "Error" --msgbox "Proxychains test failed!\n\nError: $test_result\n\nPlease check your proxy configuration." 10 60
    fi
}

# Test the OS Proxy and Print the Proxy Server Location
test_os_env_proxy() {
    server_country=""
    if [[ $HTTP_PROXY == "http://$HTTP_HOST:$HTTP_PORT" ]] || [[ $HTTPS_PROXY == "http://$HTTP_HOST:$HTTP_PORT" ]]; then
        check_proxy_server_location $HTTP_PROXY
        if [ "$server_country" != "Iran" ]; then
            dialog --title "Success" --msgbox "The HTTP proxy setting is configured correctly, the proxy server location is $server_country." 7 50
        else
            dialog --title "Error" --msgbox "The HTTP proxy setting is not configured correctly or not working!" 6 50
            fi
    elif [[ $HTTP_PROXY == "socks5h://$SOCKS5_HOST:$SOCKS5_PORT" ]] || [[ $HTTPS_PROXY == "socks5h://$SOCKS5_HOST:$SOCKS5_PORT" ]]; then
        check_proxy_server_location $HTTP_PROXY
        if [ "$server_country" != "Iran" ]; then
            dialog --title "Success" --msgbox "The SOCKS5 proxy setting is configured correctly, the proxy server location is $server_country." 7 50
        else
            dialog --title "Error" --msgbox "The SOCKS5 proxy setting is not configured correctly or not working!" 6 50
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
        dialog --title "Error" --msgbox "apt could not be found. are you Debian-based?" 6 50
    fi    
    apt clean && apt autoclean >/dev/null 2>&1 && apt update -qq >/dev/null 2>&1
    if [ $? == 0 ]; then
        dialog --title "Success" --msgbox "If you enabled the proxy setting on APT, It's working." 7 50
    else
        dialog --title "Error" --msgbox "The proxy setting on APT is not configured correctly or not working!" 6 50
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
        dialog --title "Success" --msgbox "The proxy setting on Docker is configured correctly." 7 50
    else
        dialog --title "Error" --msgbox "The proxy setting on Docker is not configured correctly or not working!" 6 50
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
        dialog --title "Success" --msgbox "The proxy setting on containerd is configured correctly." 7 50
    else
        dialog --title "Error" --msgbox "The proxy setting on containerd is not configured correctly or not working!" 6 50
    fi
}


# Call the check dependencies function
check_deps

# Main function
while true; do
    dialog --title "Manage the proxy configs on Linux and services quickly" \
    --backtitle "$SCRIPT_NAME" \
    --menu "Choose the action you want to perform (with space or mouse click):" 14 70 8 \
    1 "Enable Proxy" \
    2 "Disable Proxy" \
    3 "Test Proxies" \
    4 "Configure Proxychains" \
    5 "Exit" 2>tempfile

    # Read the selection
    selection=$(<tempfile)

    # Check the user's selection
    case $selection in
        1)
            dialog --title "Enable Proxy" \
            --checklist "Where you want to set the HTTP/SOCKS5 Proxy:" 14 70 7 \
            1 "Enable HTTP Proxy on OS ENV" off \
            2 "Enable SOCKS5 Proxy on OS ENV" off \
            3 "Enable HTTP Proxy on APT (recommended)" off \
            4 "Enable SOCKS5 Proxy on APT" off \
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
                        set_apt_http_proxy
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
        2)
            dialog --title "Disable Proxy" \
            --checklist "Choose the action you want to perform (with space or mouse click):" 14 70 5 \
            1 "Disable HTTP/SOCKS5 Proxy on OS ENV" off \
            2 "Disable HTTP/SOCKS5 Proxy on APT" off \
            3 "Disable HTTP/SOCKS5 Proxy on Docker Service" off \
            4 "Disable HTTP/SOCKS5 Proxy on Containerd (K8s) Service" off \
            5 "Disable HTTP/SOCKS5 Completely" off 2>tempfile

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
                        remove_old_apt_proxy
                        ;;  
                    3)
                        disable_docker_proxy
                        ;;
                    4)
                        disable_containerd_proxy
                        ;;
                    5)
                        disable_os_env_proxy
                        remove_old_apt_proxy
                        disable_docker_proxy
                        disable_containerd_proxy
                        ;;
                esac
            done
            ;;
        3)
            dialog --title "Test Proxies" \
            --menu "Choose the action you want to test:" 14 70 8 \
            1 "Test OS Proxy" \
            2 "Test Docker Proxy" \
            3 "Test APT Proxy (Enable the proxy first)" \
            4 "Test Proxy Performance" \
            5 "Test Proxy Health" 2>tempfile

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
                    test_apt_proxy
                    ;;
                4)
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
                5)
                    dialog --title "Proxy Health Test" \
                    --menu "Choose proxy to test:" 10 50 3 \
                    1 "HTTP Proxy Health" \
                    2 "SOCKS5 Proxy Health" 2>tempfile
                    health_selection=$(<tempfile)
                    case $health_selection in
                        1)
                            if check_proxy_health "http://$HTTP_HOST:$HTTP_PORT"; then
                                dialog --title "Success" --msgbox "HTTP Proxy is healthy and responding correctly." 6 50
                            else
                                dialog --title "Error" --msgbox "HTTP Proxy health check failed. Check your proxy configuration." 6 50
                            fi
                            ;;
                        2)
                            if check_proxy_health "socks5h://$SOCKS5_HOST:$SOCKS5_PORT"; then
                                dialog --title "Success" --msgbox "SOCKS5 Proxy is healthy and responding correctly." 6 50
                            else
                                dialog --title "Error" --msgbox "SOCKS5 Proxy health check failed. Check your proxy configuration." 6 50
                            fi
                            ;;
                    esac
                    ;;
            esac
            ;;
        4)
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
            --menu "Choose the proxychains configuration:" 14 70 6 \
            1 "Configure HTTP Proxy in Proxychains" \
            2 "Configure SOCKS5 Proxy in Proxychains" \
            3 "Configure Dual Proxy (HTTP + SOCKS5)" \
            4 "Disable Proxychains Configuration" \
            5 "Test Proxychains Configuration" 2>tempfile

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
            esac
            ;;
        5)
            echo "Exiting..."
            break
            ;;
    esac
done


# Clear the screen
clear

# Remove the tempfile
rm -f tempfile
