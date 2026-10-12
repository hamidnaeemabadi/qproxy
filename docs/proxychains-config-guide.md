# Proxychains Configuration Guide

> **QProxy integration**
>
> | Item | Location |
> |------|----------|
> | Live config on the system | `/etc/proxychains4.conf` |
> | Bundled reference config | `share/proxychains/proxychains4.conf` |
> | QProxy-generated templates | `templates/proxychains-{http,socks5,dual,default}.conf` |
> | Proxy host/port settings | `~/.qproxy.env` |
>
> **Configure with QProxy**
> ```bash
> sudo qproxy                          # TUI → Configure Proxychains
> sudo qproxy enable proxychains http  # CLI
> sudo qproxy test proxychains
> ```
>
> **Seed `/etc/proxychains4.conf` on install**
> ```bash
> sudo ./qproxy.sh install --proxychains-conf
> ```

## Optimized configuration summary

QProxy applies these defaults when you configure proxychains through the menu or CLI:

### Key optimizations applied
1. **Chain mode**: `dynamic_chain` for better reliability
2. **Timeouts**: 10s read, 5s connect
3. **DNS protection**: `proxy_dns` enabled
4. **Proxy order**: HTTP first, then SOCKS5 (dual mode)

---

## Configuration recommendations by use case

### 1. High performance setup (recommended)
```ini
# Best for: Web browsing, downloads, general use
dynamic_chain
proxy_dns
tcp_read_time_out 8000
tcp_connect_time_out 4000

[ProxyList]
http 192.168.1.14 2081
socks5 192.168.1.14 2080
```

### 2. Maximum anonymity setup
```ini
# Best for: Privacy-critical applications
strict_chain
proxy_dns
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
socks5 proxy1.example.com 1080
socks5 proxy2.example.com 1080
socks5 proxy3.example.com 1080
```

### 3. Load balancing setup
```ini
# Best for: High-traffic applications
random_chain
chain_len = 2
proxy_dns
tcp_read_time_out 10000
tcp_connect_time_out 5000

[ProxyList]
http proxy1.example.com 8080
http proxy2.example.com 8080
http proxy3.example.com 8080
socks5 proxy4.example.com 1080
socks5 proxy5.example.com 1080
```

### 4. Development/testing setup
```ini
# Best for: Testing, development
dynamic_chain
#quiet_mode  # Uncomment for cleaner output
proxy_dns
tcp_read_time_out 5000
tcp_connect_time_out 3000

[ProxyList]
http 127.0.0.1 8080
```

---

## Performance optimization tips

### Timeout settings
- **Fast networks**: `tcp_connect_time_out 3000`, `tcp_read_time_out 5000`
- **Slow networks**: `tcp_connect_time_out 8000`, `tcp_read_time_out 15000`
- **Mobile/unstable**: `tcp_connect_time_out 10000`, `tcp_read_time_out 20000`

### Chain mode selection
| Mode | Performance | Reliability | Anonymity | Use case |
|------|-------------|-------------|-----------|----------|
| `dynamic_chain` | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | **Recommended** |
| `strict_chain` | ⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | High anonymity |
| `random_chain` | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | Load balancing |

### Proxy order optimization
1. **Fastest proxies first** (HTTP for web traffic)
2. **Most reliable proxies first**
3. **Geographic diversity** for anonymity
4. **Protocol variety** (HTTP + SOCKS5)

---

## Security best practices

### DNS leak prevention
```ini
proxy_dns
```

### Authentication support
```ini
[ProxyList]
http proxy.example.com 8080 username password
socks5 proxy.example.com 1080 username password
```

### Proxy quality checklist
- [ ] Test proxy connectivity before adding
- [ ] Use HTTPS-capable proxies when possible
- [ ] Avoid free/public proxies for sensitive data
- [ ] Monitor proxy performance regularly
- [ ] Rotate proxies periodically

---

## Testing your configuration

### 1. Test proxy chain
```bash
proxychains4 curl -s http://httpbin.org/ip
proxychains4 wget -qO- http://httpbin.org/ip
```

### 2. Check for DNS leaks
```bash
proxychains4 nslookup google.com
```

### 3. Performance testing
```bash
time proxychains4 curl -s http://httpbin.org/bytes/1024
sudo qproxy test health http
```

---

## Troubleshooting common issues

### Connection timeouts
- Increase timeout values
- Check proxy availability with `sudo qproxy test health http`

### DNS resolution issues
- Ensure `proxy_dns` is enabled
- Test DNS with `proxychains4 nslookup`

### Slow performance
- Use `dynamic_chain` instead of `strict_chain`
- Reduce timeout values
- Optimize proxy order

### Authentication failures
- Verify credentials format in `[ProxyList]`
- Test with `curl -x` first

---

## Quick reference

### Essential settings
```ini
dynamic_chain
proxy_dns
tcp_read_time_out 10000
tcp_connect_time_out 5000
```

### Proxy format
```ini
[ProxyList]
http 192.168.1.14 2081 username password
socks5 192.168.1.14 2080 username password
socks4 192.168.1.14 1080
```

See also: [CHANGELOG.md](../CHANGELOG.md) for QProxy proxychains feature history.
