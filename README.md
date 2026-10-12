# QProxy

Linux proxy management for system environment, package managers, Docker, containerd, and proxychains. Interactive TUI or CLI.

**Version:** git tag / `VERSION` file / `v2.1.0` default — see [Versioning](#versioning)  
**Author:** Hamid Naeemabadi

## Quick start

```bash
git clone https://github.com/hamidnaeemabadi/qproxy.git
cd qproxy
chmod +x qproxy.sh

sudo ./qproxy.sh install              # install to /usr/local, install deps
sudo ./qproxy.sh install --proxychains-conf   # also seed /etc/proxychains4.conf

sudo qproxy                           # interactive menu
qproxy config show                    # show current settings
```

## Requirements

- Linux (Debian, Ubuntu, Fedora, RHEL, Arch, OpenSUSE, …)
- Root for enable/disable/install
- Auto-installed: `dialog`, `jq`, `curl`; `proxychains4` / `proxychains-ng` when needed

```bash
sudo ./qproxy.sh install --no-deps   # skip dialog/jq/curl package install
qproxy install status              # check install location
```

## Versioning

Version is resolved in this order:

1. **`$QPROXY_ROOT/VERSION`** — written on `sudo qproxy install` (used on installed systems)
2. **Git tag** — `git describe --tags` when running from a git checkout
3. **Fallback** — `v2.1.0` in `lib/config.sh` (`QPROXY_DEFAULT_VERSION`)

**Release v2.1.0:**

```bash
git tag -a v2.1.0 -m "Release v2.1.0"
git push origin v2.1.0

# Re-install so /usr/local/lib/qproxy/VERSION is updated
sudo ./qproxy.sh install
qproxy install status   # → QProxy v2.1.0
```

**Already installed without re-installing:** update the version file only:

```bash
echo v2.1.0 | sudo tee /usr/local/lib/qproxy/VERSION
qproxy install status
```

**Note**: The script automatically detects your Linux distribution and installs dependencies using the appropriate package manager:

- **Debian/Ubuntu**: `apt` (proxychains4)
- **Fedora/RHEL/CentOS**: `dnf`/`yum` (proxychains-ng)
- **Arch/Manjaro**: `pacman` (proxychains-ng)
- **OpenSUSE/SLES**: `zypper` (proxychains-ng)

## Configuration

Proxy settings live in **`~/.qproxy.env`** (created on first run). Edit directly or use the TUI **Configure Proxy Settings** menu.

```bash
# ~/.qproxy.env
HTTP_HOST="10.X.X.X"
HTTP_PORT="3128"
SOCKS5_HOST="10.X.X.X"
SOCKS5_PORT="1080"
NO_PROXY_HOSTS="127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,localhost,*.local"
PROXY_TIMEOUT=30
PROXY_READ_TIMEOUT=60
```

`qproxy config show` prints the active values and config path.

## CLI

Most commands need root (`sudo qproxy …`). `config show` and `install status` do not.

| Command | Description |
|---------|-------------|
| `qproxy` | Interactive TUI (default) |
| `qproxy -h` | Show CLI help |
| `qproxy install [options]` | Install under `/usr/local` (or `--prefix`) |
| `qproxy install status` | Show install path and version |
| `qproxy uninstall` | Remove system install (keeps `~/.qproxy.env`) |
| `qproxy config show` | Show HTTP/SOCKS5 hosts, NO_PROXY, timeouts |
| `qproxy enable <target> [type]` | Enable proxy on a service |
| `qproxy disable <target>` | Disable proxy on a service |
| `qproxy test <check> [type]` | Run connectivity / health tests |

### Install options

| Option | Description |
|--------|-------------|
| `--no-deps` | Skip installing `dialog`, `jq`, `curl` |
| `--proxychains-conf` | Install bundled `proxychains4.conf` if `/etc` file is missing |
| `--force-proxychains-conf` | Replace existing `/etc/proxychains4.conf` |
| `--prefix PATH` | Install under `PATH` instead of `/usr/local` |

### Targets (`enable` / `disable`)

| Target | Description |
|--------|-------------|
| `os-env` | System-wide env via `/etc/profile.d/user_proxy_env.sh` |
| `apt` | APT (Debian/Ubuntu) — `http` or `socks5` |
| `pkgmgr` | Auto-detect distro package manager (HTTP) |
| `docker` | Docker systemd drop-in |
| `containerd` | Containerd systemd drop-in |
| `proxychains` | Proxychains — `http`, `socks5`, or `dual` |

### Tests (`test`)

| Check | Type | Description |
|-------|------|-------------|
| `health` | `http` \| `socks5` | Proxy reachability before applying config |
| `apt` | — | APT proxy test |
| `pkgmgr` | — | Package manager proxy test |
| `docker` | — | Docker proxy test |
| `containerd` | — | Containerd proxy test |
| `proxychains` | — | Proxychains chain test |

### Examples

```bash
# Install
sudo ./qproxy.sh install
sudo qproxy install --no-deps --prefix /opt
qproxy install status

# View config
qproxy config show

# Enable proxies (sudo)
sudo qproxy enable os-env http
sudo qproxy enable apt socks5
sudo qproxy enable pkgmgr
sudo qproxy enable docker
sudo qproxy enable proxychains dual

# Disable
sudo qproxy disable docker
sudo qproxy disable os-env

# Tests
qproxy test health http
sudo qproxy test docker
sudo qproxy test proxychains

# Remove install
sudo qproxy uninstall
```

## Proxychains

Proxy hosts/ports come from `~/.qproxy.env`. QProxy writes `/etc/proxychains4.conf` from templates when you enable a mode.

```bash
# 1. Set proxy endpoints (edit file or use TUI)
qproxy config show

# 2. Configure proxychains (pick one)
sudo qproxy enable proxychains http
sudo qproxy enable proxychains socks5
sudo qproxy enable proxychains dual      # HTTP + SOCKS5 chain

# 3. Verify the chain works
sudo qproxy test proxychains

# 4. Run a single command through the proxy
proxychains4 curl -s http://httpbin.org/ip
proxychains4 wget -qO- https://example.com
proxychains4 git clone https://github.com/example/repo.git

# 5. Interactive shell with all traffic proxied (TUI only)
sudo qproxy    # → Configure Proxychains → Launch Proxychains Shell

# 6. Disable / reset
sudo qproxy disable proxychains
```

**Install bundled base config** (optional, on first install):

```bash
sudo qproxy install --proxychains-conf
```

More detail: [docs/proxychains-config-guide.md](docs/proxychains-config-guide.md)

## Interactive menu

Run `sudo qproxy` with no arguments:

1. Configure proxy settings  
2. Enable / disable proxy (OS, pkgmgr, APT, Docker, containerd)  
3. Test proxies (health, performance, per-service)  
4. Configure proxychains (HTTP, SOCKS5, dual, shell launcher)  
5. Apply proxy to current session (no logout)

Proxychains details: [docs/proxychains-config-guide.md](docs/proxychains-config-guide.md)

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| Health check fails | Host/port in `~/.qproxy.env`, firewall, proxy auth |
| APT still slow | `sudo qproxy disable apt` then re-enable; `apt clean` |
| Docker restart | Live-restore in daemon config; check `docker.service.d/proxy.conf` |

Config paths:

- **APT Proxy**: `/etc/apt/apt.conf.d/apt_proxy_*`
- **Docker Service Proxy**: `/etc/systemd/system/docker.service.d/proxy.conf`
- **Docker CLI Proxy**: `~/.docker/config.json` (all users + `/etc/skel/.docker/config.json`)
- **OS Environment**: `/etc/profile.d/user_proxy_env.sh`

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT — see [LICENSE](LICENSE).
