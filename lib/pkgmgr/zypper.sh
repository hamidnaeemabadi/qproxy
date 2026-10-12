remove_old_zypper_proxy() {
    # Remove zypper proxy configurations
    sudo zypper config --unset proxy.http >/dev/null 2>&1
    sudo zypper config --unset proxy.https >/dev/null 2>&1
    
    if [ "$1" != "-q" ]; then
        dialog --title "Success" --msgbox "Zypper proxy disabled successfully!" 6 50
    fi
}

# Function to set APT HTTP proxy

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

