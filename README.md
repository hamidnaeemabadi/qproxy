# QProxy - Linux Proxy Management Tool

**Version:** v1.6  
**Author:** Hamid Naeemabadi  
**Purpose:** Manage proxy configurations on Linux systems and services quickly and efficiently.

## 🚀 Features

### Core Proxy Management
- **HTTP Proxy Support**: Configure HTTP proxies for system-wide usage
- **SOCKS5 Proxy Support**: Configure SOCKS5 proxies with full protocol support
- **Multi-Service Configuration**: Set up proxies for multiple services simultaneously
- **Easy Enable/Disable**: Quick toggle between proxy and direct connections

### Service Integration
- **OS Environment Variables**: System-wide proxy configuration via environment variables
- **APT Package Manager**: Optimized proxy settings for package management
- **Docker Service**: Container runtime proxy configuration with performance optimizations
- **Containerd (Kubernetes)**: Container runtime proxy support for K8s environments
- **Proxychains Integration**: Automatic proxychains.conf configuration and management

### Performance Optimizations
- **Connection Timeouts**: Configurable timeout settings for better reliability
- **APT Performance Tuning**: Pipeline depth, retry logic, and caching optimizations
- **Docker Performance**: Concurrent download/upload limits and live-restore support
- **Health Monitoring**: Pre-configuration proxy health checks

### Testing & Monitoring
- **Proxy Health Checks**: Verify proxy connectivity before configuration
- **Performance Benchmarking**: Measure proxy overhead and response times
- **Location Verification**: Check proxy server geographical location
- **Service-Specific Tests**: Test proxy functionality for each configured service
- **Proxychains Testing**: Test proxy chain functionality and connectivity

### Security & Reliability
- **NO_PROXY Configuration**: Smart exclusion of private networks and local domains
- **Safe Service Restarts**: Docker live-restore support to prevent container downtime
- **Configuration Backup**: Automatic backup of existing configurations
- **Error Handling**: Comprehensive error checking and user feedback
- **Proxychains Security**: DNS leak protection and optimized chain configurations

## 📋 Requirements

- **Operating System**: Linux distributions (Debian, Ubuntu, Fedora, RHEL, CentOS, Arch, OpenSUSE)
- **Privileges**: Root access required
- **Dependencies**: 
  - `dialog` - For interactive menus (auto-installed)
  - `jq` - For JSON processing (auto-installed)
  - `curl` - For network testing (auto-installed)
  - `proxychains4` or `proxychains-ng` - For proxy chain functionality (auto-installed if needed)

## 🛠️ Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd qproxy-github
```

2. Make the script executable:
```bash
chmod +x qproxy.sh
```

3. Run as root:
```bash
sudo ./qproxy.sh
```

**Note**: The script automatically detects your Linux distribution and installs dependencies using the appropriate package manager:
- **Debian/Ubuntu**: `apt` (proxychains4)
- **Fedora/RHEL/CentOS**: `dnf`/`yum` (proxychains-ng)
- **Arch/Manjaro**: `pacman` (proxychains-ng)
- **OpenSUSE/SLES**: `zypper` (proxychains-ng)

## ⚙️ Configuration

### Proxy Settings
Edit the following variables in the script:
```bash
# SOCKS5 Proxy
SOCKS5_HOST="10.X.X.X"
SOCKS5_PORT="1080"

# HTTP Proxy
HTTP_HOST="10.X.X.X"
HTTP_PORT="3128"

# Excluded hosts (private networks)
NO_PROXY_HOSTS="127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,example.local,localhost,*.local"
```

### Performance Settings
```bash
# Timeout configurations
PROXY_TIMEOUT=30
PROXY_READ_TIMEOUT=60
```

### Proxy Configuration Notes
- **Unified Configuration**: The same proxy variables (`HTTP_HOST`, `HTTP_PORT`, `SOCKS5_HOST`, `SOCKS5_PORT`) are used for all services including proxychains
- **Generalized Format**: All IP addresses use placeholder format (e.g., `10.X.X.X`) for easy customization
- **Centralized Management**: Change proxy settings in one place, affects all configurations (OS, APT, Docker, Containerd, and Proxychains)

## 🎯 Usage

### Main Menu Options

1. **Enable Proxy**
   - Enable HTTP/SOCKS5 Proxy on OS Environment
   - Enable HTTP/SOCKS5 Proxy on APT Package Manager
   - Enable HTTP Proxy on Docker Service
   - Enable HTTP Proxy on Containerd (Kubernetes) Service

2. **Disable Proxy**
   - Disable proxies from individual services
   - Complete proxy removal from all services

3. **Test Proxies**
   - Test OS Environment proxy configuration
   - Test Docker proxy functionality
   - Test APT proxy settings
   - **NEW**: Performance benchmarking
   - **NEW**: Health check monitoring

4. **Configure Proxychains** ⭐ **NEW**
   - Configure HTTP Proxy in Proxychains
   - Configure SOCKS5 Proxy in Proxychains
   - Configure Dual Proxy (HTTP + SOCKS5)
   - Disable Proxychains Configuration
   - Test Proxychains Configuration
   - **Auto-installation**: Automatically installs proxychains4 if not present

5. **Exit**

### Performance Testing

The script includes comprehensive performance testing:
- **Response Time Measurement**: Compare proxy vs direct connection speeds
- **Overhead Calculation**: Measure proxy performance impact
- **Health Verification**: Ensure proxy connectivity before configuration
- **Performance Rating**: Automatic performance assessment (Excellent/Good/Fair/Poor)

## 🔧 Advanced Features

### APT Optimizations
- Connection timeouts and retry logic
- Pipeline depth optimization (5 concurrent connections)
- Cache management for better performance
- Automatic dependency installation

### Docker Optimizations
- Concurrent download/upload limits
- Live-restore support for zero-downtime restarts
- Log rotation and size management
- Registry mirror support (configurable)

### Health Monitoring
- Pre-configuration proxy validation
- Real-time connectivity testing
- Automatic fallback recommendations
- Performance impact assessment

## 📊 Performance Metrics

The script provides detailed performance metrics:
- **Excellent**: < 100ms overhead
- **Good**: < 300ms overhead  
- **Fair**: < 500ms overhead
- **Poor**: > 500ms overhead

## 🔒 Security Features

- **Private Network Exclusion**: Automatic exclusion of RFC 1918 networks
- **Local Domain Support**: Exclude local domains and localhost
- **Secure Configuration**: Environment variable-based configuration
- **Service Isolation**: Individual service proxy management

## 🐛 Troubleshooting

### Common Issues

1. **Proxy Health Check Failed**
   - Verify proxy server connectivity
   - Check firewall settings
   - Confirm proxy credentials (if required)

2. **Docker Service Restart Issues**
   - Ensure live-restore is enabled
   - Check Docker daemon configuration
   - Verify systemd service status

3. **APT Proxy Configuration**
   - Clear APT cache: `apt clean && apt autoclean`
   - Verify proxy configuration files
   - Check network connectivity

### Log Locations
- **APT Proxy**: `/etc/apt/apt.conf.d/apt_proxy_*`
- **Docker Proxy**: `/etc/systemd/system/docker.service.d/proxy.conf`
- **OS Environment**: `/etc/profile.d/user_proxy_env.sh`

## 📈 Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history and updates.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👨‍💻 Author

**Hamid Naeemabadi**  
DevOps Engineer & System Administrator

## 🙏 Acknowledgments

- Linux community for proxy configuration best practices
- Docker team for container runtime optimizations
- Debian/Ubuntu maintainers for APT package management

---

**Note**: This tool is designed for Debian-based Linux distributions. For other distributions, modifications may be required.