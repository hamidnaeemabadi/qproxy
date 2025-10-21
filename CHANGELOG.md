# Changelog

All notable changes to QProxy will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.8.0] - 2025-10-21

### Added
- **Proxychains Shell Launcher**: New feature to launch a shell with proxychains enabled after health testing
- **Comprehensive Health Testing**: Tests proxy server health before launching proxychains shell
- **Interactive Shell Environment**: Launches bash shell with all network traffic routed through proxy
- **Safety Checks**: Prevents launching shell with unhealthy or non-functional proxies
- **User-Friendly Interface**: Clear status messages and instructions for the proxychains shell

### Enhanced
- **Proxychains Menu**: Added "Launch Proxychains Shell" option to the proxychains configuration menu
- **Health Validation**: Multi-layer health testing (proxy health + proxychains connectivity)
- **Error Handling**: Comprehensive error messages for failed health checks
- **User Experience**: Clear visual feedback and instructions when launching proxychains shell

### Technical Improvements
- **Health Testing Integration**: Uses existing health check functions for proxy validation
- **Configuration Validation**: Checks proxychains configuration file existence before launching
- **Process Management**: Uses `exec` to replace current process with proxychains shell
- **Status Display**: Clear terminal output showing proxy status and usage instructions

## [1.7.0] - 2025-10-21

### Added
- **Current Session Proxy Management**: New functions to apply proxy settings to current user session without requiring logout/login
- **Multi-Shell Support**: Automatically applies proxy settings to all existing user shells (bash, zsh, sh, fish)
- **Session-Only Proxy Application**: New menu option "Apply Proxy to Current Session" for temporary proxy configuration
- **Immediate Proxy Application**: Proxy settings are now applied immediately to current session when enabling/disabling
- **Enhanced User Experience**: No more need to logout/login to apply proxy changes

### Changed
- **Proxy Application Process**: All proxy enable/disable functions now apply changes immediately to current session
- **Success Messages**: Updated to show that proxy is applied immediately without requiring logout
- **Menu Structure**: Added new menu option for current session proxy management
- **User Feedback**: Enhanced success messages to clearly indicate immediate application vs persistent configuration

### Technical Improvements
- **Process Management**: Added functions to detect and manage user shell processes
- **Environment Variable Management**: Enhanced export/unset operations for all user shells
- **Session Persistence**: Clear distinction between temporary session changes and persistent configuration
- **Error Handling**: Improved error handling for shell process management

## [1.6.0] - 2025-10-21

### Added
- **Multi-Distribution Support**
  - New `detect_distro()` function for automatic Linux distribution detection
  - Support for Fedora/RHEL-based systems (dnf/yum package managers)
  - Support for Arch-based systems (pacman package manager)
  - Support for SUSE-based systems (zypper package manager)
  - Comprehensive distribution detection from `/etc/os-release` and fallback methods

- **Enhanced Package Installation**
  - Automatic package manager detection and usage
  - Distribution-specific package names (proxychains4 vs proxychains-ng)
  - Fallback package managers (dnf with yum fallback for RHEL systems)
  - Non-interactive installation flags for all supported package managers

### Enhanced
- **Dependency Management**
  - Updated `check_deps()` function to support all major Linux distributions
  - Automatic installation of core dependencies (dialog, jq, curl) across distributions
  - Distribution-specific installation commands and flags
  - Better error handling for unsupported distributions

- **Proxychains Installation**
  - Fedora/RHEL: `dnf install proxychains-ng` or `yum install proxychains-ng`
  - Arch/Manjaro: `pacman -S proxychains-ng`
  - OpenSUSE/SLES: `zypper install proxychains-ng`
  - Debian/Ubuntu: `apt install proxychains4` (existing)

### Technical Improvements
- **Distribution Detection**
  - Primary detection via `/etc/os-release` file
  - Fallback detection via `/etc/redhat-release` and `/etc/debian_version`
  - Support for major distribution families and variants
  - Graceful handling of unknown distributions

- **Package Manager Support**
  - **APT**: Debian, Ubuntu, Linux Mint, Pop!_OS, Elementary OS
  - **DNF/YUM**: Fedora, RHEL, CentOS, Rocky Linux, AlmaLinux, Oracle Linux
  - **Pacman**: Arch Linux, Manjaro, EndeavourOS
  - **Zypper**: OpenSUSE, SUSE Linux Enterprise Server

## [1.5.0] - 2025-10-21

### Added
- **Automatic Proxychains Installation**
  - New `check_and_install_proxychains()` function for automatic dependency checking
  - Interactive installation prompt when proxychains4 is not found
  - Automatic installation via apt package manager
  - User-friendly installation success/failure messages

- **Enhanced Proxychains Menu Integration**
  - Pre-menu installation check for proxychains4 availability
  - Automatic installation prompt before accessing proxychains configuration
  - Graceful handling of installation cancellation
  - Improved user experience with clear installation guidance

### Enhanced
- **Dependency Management**
  - All proxychains functions now check for installation before proceeding
  - Unified installation checking across all proxychains features
  - Better error handling and user guidance
  - Seamless integration with existing dependency management

### Technical Improvements
- **Installation Process**
  - Non-interactive installation with progress feedback
  - Automatic return to menu after successful installation
  - Clear error messages for installation failures
  - Manual installation instructions as fallback

## [1.4.0] - 2025-10-21

### Added
- **Proxychains Integration**
  - New `set_proxychains_http_proxy()` function for HTTP proxy configuration
  - New `set_proxychains_socks5_proxy()` function for SOCKS5 proxy configuration
  - New `set_proxychains_dual_proxy()` function for dual proxy setup (HTTP + SOCKS5)
  - New `disable_proxychains_config()` function to disable proxychains configuration
  - New `test_proxychains_config()` function for testing proxy chain functionality
  - New `backup_proxychains_config()` function for automatic configuration backup

- **Proxychains Menu Integration**
  - New "Configure Proxychains" option in main menu
  - Submenu with 5 configuration options:
    - Configure HTTP Proxy in Proxychains
    - Configure SOCKS5 Proxy in Proxychains
    - Configure Dual Proxy (HTTP + SOCKS5)
    - Disable Proxychains Configuration
    - Test Proxychains Configuration

- **Automatic Configuration Management**
  - Automatic backup of existing proxychains.conf before changes
  - Timestamped backup files for configuration history
  - Optimized proxychains.conf generation with performance settings
  - Variable-based proxy server configuration (uses script variables)

### Enhanced
- **Configuration Variables**
  - Added `PROXYCHAINS_CONF_PATH="/etc/proxychains4.conf"` variable
  - Unified proxy configuration - proxychains uses the same variables as other services
  - Removed duplicate proxy variables for cleaner configuration management
  - Generalized IP address format (10.X.X.X) for easy customization

- **Performance Optimizations**
  - Optimized proxychains.conf with dynamic_chain mode
  - Reduced timeout settings for better performance
  - DNS leak protection enabled by default
  - Comprehensive configuration comments and documentation

### Technical Improvements
- **Error Handling**
  - Proxychains installation detection and user guidance
  - Configuration file existence validation
  - Comprehensive error messages and troubleshooting guidance

- **Testing and Validation**
  - Real-time proxychains connectivity testing
  - HTTP response validation for proxy chain functionality
  - Detailed success/failure reporting with error details

## [1.3.0] - 2024-12-19

### Added
- **Performance Monitoring System**
  - New `test_proxy_performance()` function for benchmarking proxy overhead
  - Response time measurement comparing proxy vs direct connections
  - Performance rating system (Excellent/Good/Fair/Poor)
  - Detailed performance metrics display

- **Proxy Health Checking**
  - New `check_proxy_health()` function for pre-configuration validation
  - Automatic health checks before setting proxy configurations
  - HTTP status code validation for proxy connectivity
  - Warning messages for failed health checks

- **Enhanced APT Optimizations**
  - Connection timeout settings (`Acquire::http::Timeout`, `Acquire::https::Timeout`)
  - Pipeline depth optimization (`Acquire::http::Pipeline-Depth: 5`)
  - Retry logic configuration (`Acquire::Retries: 3`)
  - Cache management (`Acquire::http::No-Cache: true`)

- **Docker Performance Optimizations**
  - Concurrent download/upload limits (`max-concurrent-downloads: 3`, `max-concurrent-uploads: 5`)
  - Download retry attempts (`max-download-attempts: 5`)
  - Live-restore support for zero-downtime restarts
  - Log rotation and size management
  - Automatic daemon.json backup and merge functionality

- **Connection Timeout Configuration**
  - Global timeout variables (`PROXY_TIMEOUT=30`, `PROXY_READ_TIMEOUT=60`)
  - Timeout settings applied to all proxy configurations
  - Environment variable timeout settings for OS proxy

- **Enhanced NO_PROXY Configuration**
  - Added `localhost` and `*.local` to excluded hosts
  - Improved private network exclusion coverage

- **New Testing Menu Options**
  - "Test Proxy Performance" option with HTTP/SOCKS5 selection
  - "Test Proxy Health" option with individual proxy testing
  - Interactive performance and health testing interfaces

### Changed
- Updated version from v1.2 to v1.3
- Enhanced success messages to indicate performance optimizations
- Improved proxy configuration with timeout settings
- Updated menu structure to accommodate new testing options

### Technical Improvements
- Added comprehensive error handling for health checks
- Implemented automatic configuration backup for Docker daemon.json
- Enhanced JSON processing with jq for Docker configuration merging
- Improved user feedback with detailed performance metrics

## [1.2.0] - Previous Version

### Features
- Basic HTTP and SOCKS5 proxy support
- OS environment variable configuration
- APT package manager proxy settings
- Docker service proxy configuration
- Containerd (Kubernetes) proxy support
- Basic proxy testing functionality
- Service-specific proxy management

### Core Functionality
- Interactive menu system with dialog
- Proxy enable/disable functionality
- Basic connectivity testing
- Service restart management
- Configuration file management

## [1.1.0] - Initial Release

### Features
- Basic proxy management functionality
- HTTP proxy support
- Simple configuration interface
- Basic testing capabilities

## [1.0.0] - Initial Release

### Features
- Initial QProxy implementation
- Basic proxy configuration management
- Core functionality foundation

---

## Version Numbering

- **Major Version (X.0.0)**: Breaking changes or major feature additions
- **Minor Version (0.X.0)**: New features, enhancements, or significant improvements
- **Patch Version (0.0.X)**: Bug fixes, minor improvements, or documentation updates

---

## Contributing

When contributing to QProxy, please update this changelog with your changes following the established format:

1. Add your changes under the appropriate section (Added, Changed, Deprecated, Removed, Fixed, Security)
2. Use clear, descriptive language
3. Reference any related issues or pull requests
4. Update the version number according to semantic versioning principles

## Support

For questions, issues, or feature requests, please:
1. Check the [README.md](README.md) for documentation
2. Review existing issues in the repository
3. Create a new issue with detailed information
4. Contact the maintainer for urgent issues
