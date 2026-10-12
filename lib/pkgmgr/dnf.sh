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

