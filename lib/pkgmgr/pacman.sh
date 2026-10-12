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

