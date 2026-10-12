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

