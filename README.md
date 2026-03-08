# Mihomo Manager

Interactive shell script to install, configure and manage [Mihomo (Clash Meta)](https://github.com/MetaCubeX/mihomo) proxy on Linux servers.

## Features

- **Interactive TUI menu** via `whiptail` — no need to remember commands
- **One-step install** — downloads latest Mihomo binary + GeoIP databases automatically
- **TUN mode** — transparent proxy for all programs system-wide (curl, apt, docker, pip, etc.)
- **Tailscale coexistence** — toggle compatibility mode to prevent routing conflicts
- **Full service management** — start / stop / restart / enable autostart
- **Config management** — import config, view current settings, directory guide
- **Network test** — verify Google, YouTube, GitHub connectivity via TUN and HTTP proxy
- **Log viewer** — recent logs or real-time follow

## Requirements

- Linux (Debian / Ubuntu / any systemd distro)
- `root` or `sudo`
- `curl`, `whiptail` (pre-installed on most Debian/Ubuntu systems)

## Install

Copy the script to your server:

```bash
scp mihomo-manager 服务器:/usr/local/bin/mihomo-manager
ssh 服务器 "chmod +x /usr/local/bin/mihomo-manager"
```

Or directly on the server:

```bash
curl -Lo /usr/local/bin/mihomo-manager \
  https://raw.githubusercontent.com/RaylenZed/mihomo-manager/main/mihomo-manager.sh
chmod +x /usr/local/bin/mihomo-manager
```

## Usage

Launch the interactive menu:

```bash
mihomo-manager
```

Or use directly without menu:

```bash
mihomo-manager start
mihomo-manager stop
mihomo-manager restart
mihomo-manager status
mihomo-manager test
mihomo-manager log
mihomo-manager log-follow
```

## Menu Overview

```
 1  查看状态
 2  启动服务
 3  停止服务
 4  重启服务
 5  开机自启 设置
 ─────────────────────
 7  安装 Mihomo
 8  导入 / 查看配置文件
 9  更新到最新版本
 ─────────────────────
11  网络连通性测试
12  查看日志
 ─────────────────────
15  Tailscale 兼容  [已启用/未启用]
14  卸载 Mihomo
 0  退出
```

## Config File Location

```
/etc/mihomo/
├── config.yaml     ← your Mihomo config (place it here)
├── Country.mmdb    ← GeoIP database (auto-downloaded)
├── ASN.mmdb        ← ASN database (auto-downloaded)
└── ruleset/        ← rule set cache
```

## Tailscale Coexistence

Enable via menu option 15. The script will automatically patch your config:

- `tun.exclude-interface: tailscale0` — prevents Mihomo TUN from hijacking Tailscale traffic
- `dns.fake-ip-filter: *.ts.net` — preserves Tailscale MagicDNS resolution
- `IP-CIDR,100.64.0.0/10,DIRECT` — routes Tailscale device IPs directly
- `PROCESS-NAME,tailscaled,DIRECT` — bypasses Tailscale daemon traffic

## License

MIT
