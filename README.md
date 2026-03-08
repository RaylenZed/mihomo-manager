# Mihomo Manager

在 Linux 服务器上安装、配置和管理 [Mihomo (Clash Meta)](https://github.com/MetaCubeX/mihomo) 代理的交互式脚本。

## 功能

- **交互式 TUI 菜单** — 基于 `whiptail`，方向键导航，无需记命令
- **一键安装** — 自动下载最新 Mihomo 二进制和 GeoIP 数据库
- **TUN 透明代理** — 系统级代理，所有程序（curl、apt、docker、pip 等）自动走代理
- **Tailscale 共存** — 一键开关兼容模式，防止与 Tailscale 路由冲突
- **服务管理** — 启动 / 停止 / 重启 / 开机自启
- **配置管理** — 导入配置、查看当前设置、目录结构说明
- **网络测试** — 验证 Google、YouTube、GitHub 等网站的连通性
- **日志查看** — 查看最近日志或实时跟踪

## 环境要求

- Linux（Debian / Ubuntu 或任意 systemd 发行版）
- `root` 权限或 `sudo`
- `curl`、`whiptail`（Debian/Ubuntu 默认已安装）

## 安装

**方式一：从本机 scp 上传**

```bash
scp mihomo-manager.sh 服务器:/usr/local/bin/mihomo-manager
ssh 服务器 "chmod +x /usr/local/bin/mihomo-manager"
```

**方式二：在服务器上直接下载**

```bash
curl -Lo /usr/local/bin/mihomo-manager \
  https://raw.githubusercontent.com/RaylenZed/mihomo-manager/main/mihomo-manager.sh
chmod +x /usr/local/bin/mihomo-manager
```

## 使用方法

启动交互式菜单：

```bash
mihomo-manager
```

也支持直接传参（非交互模式）：

```bash
mihomo-manager start        # 启动
mihomo-manager stop         # 停止
mihomo-manager restart      # 重启
mihomo-manager status       # 查看状态
mihomo-manager test         # 网络连通性测试
mihomo-manager log          # 查看最近日志
mihomo-manager log-follow   # 实时日志
```

## 菜单结构

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
15  Tailscale 兼容  [已启用 / 未启用]
14  卸载 Mihomo
 0  退出
```

## 配置文件位置

```
/etc/mihomo/
├── config.yaml     ← 主配置文件（放这里）
├── Country.mmdb    ← GeoIP 数据库（自动下载）
├── ASN.mmdb        ← ASN 数据库（自动下载）
└── ruleset/        ← 规则集缓存目录
```

## Tailscale 共存

通过菜单选项 15 一键开关，开启后脚本自动修改配置：

| 配置项 | 作用 |
|--------|------|
| `tun.exclude-interface: tailscale0` | 防止 Mihomo TUN 劫持 Tailscale 流量 |
| `dns.fake-ip-filter: *.ts.net` | 保留 Tailscale MagicDNS 解析 |
| `IP-CIDR,100.64.0.0/10,DIRECT` | Tailscale 设备 IP 段直连 |
| `PROCESS-NAME,tailscaled,DIRECT` | Tailscale 守护进程直连 |

## License

MIT
