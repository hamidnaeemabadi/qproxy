#!/bin/bash
########################################################
# Author: [Hamid Naeemabadi]
# Script Name: QProxy
# Purpose: [Manage the proxy configs on Linux and services quickly.]
########################################################

# Vars
VERSION="v1.2"

SCRIPT_NAME="QProxy for Linux $VERSION by Hamid Naeemabadi"

# SOCKS5 Proxy
SOCKS5_HOST="10.X.X.X"
SOCKS5_PORT="1080"

# HTTP Proxy
HTTP_HOST="10.X.X.X"
HTTP_PORT="3128"

# Exclude the Private IP subnets and local ORG domain
NO_PROXY_HOSTS="127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,example.local"

USER_PROXY_ENV_PATH="/etc/profile.d/user_proxy_env.sh"

# Function to install dependencies if wasn't installed
check_deps() {
    clear
    echo "-------=( $SCRIPT_NAME )=-------"
    echo "To manage the proxy configs on Linux and services quickly ..."
    echo ""
    echo "Checking and install dependencies if wasn't installed ..."
    # Check if apt is installed
    if ! command -v apt &> /dev/null
    then
        dialog --title "Error" --msgbox "Only Debian-Based Linux supported." 6 50
    fi
    which dialog >/dev/null 2>&1 || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq dialog >/dev/null 2>&1
    which jq >/dev/null 2>&1 || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq jq >/dev/null 2>&1
    which curl >/dev/null 2>&1 || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl >/dev/null 2>&1

    # Check if the app is run as root
    if [ "$EUID" -ne 0 ]
    then 
      echo "Error: This app must be run as root"
      exit 1
    fi
}

# Function to set os http proxy
set_os_env_http_proxy() {
    cat << EOP > $USER_PROXY_ENV_PATH
export HTTP_PROXY="http://$HTTP_HOST:$HTTP_PORT"
export http_proxy="http://$HTTP_HOST:$HTTP_PORT"
export HTTPS_PROXY="http://$HTTP_HOST:$HTTP_PORT"
export https_proxy="http://$HTTP_HOST:$HTTP_PORT"
export NO_PROXY="$NO_PROXY_HOSTS"
export no_proxy="$NO_PROXY_HOSTS"
EOP
    source $USER_PROXY_ENV_PATH
    dialog --title "Success" --msgbox "HTTP Proxy enabled on OS ENV successfully, Please logoff and reconnect to the server to unset proxy from your shell." 7 50
}

# Function to set os socks5 proxy
set_os_env_socks5_proxy() {
    sudo cat << EOP > $USER_PROXY_ENV_PATH
export HTTP_PROXY="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export http_proxy="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export HTTPS_PROXY="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export https_proxy="socks5h://$SOCKS5_HOST:$SOCKS5_PORT"
export NO_PROXY="$NO_PROXY_HOSTS"
export no_proxy="$NO_PROXY_HOSTS"
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
EOP
    dialog --title "Success" --msgbox "HTTP Proxy enabled on apt package-manager successfully." 7 50
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
EOP
    dialog --title "Success" --msgbox "SOCKS5 Proxy enabled on apt package-manager successfully." 7 50
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

    # Call the docker_service_restart function
    docker_service_restart
    dialog --title "Success" --msgbox "HTTP Proxy enabled on Docker Service successfully!" 6 50
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
    --menu "Choose the action you want to perform (with space or mouse click):" 14 70 7 \
    1 "Enable Proxy" \
    2 "Disable Proxy" \
    3 "Test Proxies" \
    4 "Exit" 2>tempfile

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
            --menu "Choose the action you want to test:" 14 70 7 \
            1 "Test OS Proxy" \
            2 "Test Docker Proxy" \
            3 "Test APT Proxy (Enable the proxy first)" 2>tempfile

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
            esac
            ;;
        4)
            echo "Exiting..."
            break
            ;;
    esac
done


# Clear the screen
clear

# Remove the tempfile
rm -f tempfile
