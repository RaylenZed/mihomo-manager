# Mihomo Manager

在 Linux 服务器上安装、配置和管理 [Mihomo (Clash Meta)](https://github.com/MetaCubeX/mihomo) 代理的交互式脚本。

## 功能

- **交互式 TUI 菜单** — 纯 shell 实现，无外部依赖
- **一键安装** — 自动下载最新 Mihomo 二进制和 GeoIP/GeoSite 数据库
- **TUN 透明代理** — 系统级代理，所有程序（curl、apt、docker、pip 等）自动走代理
- **Docker 兼容** — 自动处理 TUN 与 Docker 容器的路由冲突（fake-ip 自适应）
- **Tailscale 共存** — 一键开关兼容模式，防止与 Tailscale 路由冲突
- **服务管理** — 启动 / 停止 / 重启 / 开机自启
- **配置管理** — 导入配置、在线编辑、添加域名规则、更新 GeoIP 数据库、重建路由规则
- **Docker 代理** — 配置 Docker daemon 代理，容器网络诊断
- **网络测试** — 并行检测 Google、YouTube、GitHub、Claude、ChatGPT 等连通性及出口 IP
- **IPv6 管理** — 一键启用/禁用 IPv6 并持久化
- **脚本自更新** — 在线检测新版本，一键升级
- **日志查看** — 查看最近日志或实时跟踪

## 环境要求

- Linux（Debian / Ubuntu 或任意 systemd 发行版）
- `root` 权限或 `sudo`
- `curl`（安装和更新时需要）

## 安装

**方式一：在服务器上直接下载**

```bash
curl -Lo /usr/local/bin/mihomo-manager \
  https://raw.githubusercontent.com/RaylenZed/mihomo-manager/main/mihomo-manager.sh
chmod +x /usr/local/bin/mihomo-manager
```

**方式二：从本机 scp 上传**

```bash
scp mihomo-manager.sh 服务器:/usr/local/bin/mihomo-manager
ssh 服务器 "chmod +x /usr/local/bin/mihomo-manager"
```

安装完成后，脚本会自动创建 `mm` 快捷命令。

## 使用方法

启动交互式菜单：

```bash
mm
# 或
mihomo-manager
```

也支持直接传参（非交互模式）：

```bash
mm start        # 启动
mm stop         # 停止
mm restart      # 重启
mm status       # 查看状态
mm test         # 网络连通性测试
mm log          # 查看最近日志
mm log-follow   # 实时日志
```

## 菜单结构

```
━━ Mihomo 服务 ━━
 1  查看状态
 2  启动服务
 3  停止服务
 4  重启服务
 5  开机自启设置

━━ 安装与配置 ━━
 6  安装 Mihomo
 7  配置文件管理 ────┐
 8  更新 Mihomo      │
                     │  ┌─ 1. 查看当前配置摘要
━━ 诊断与监控 ━━     │  ├─ 2. 从路径导入配置文件
 9  网络连通性测试   │  ├─ 3. 查看目录结构说明
10  查看日志         │  ├─ 4. 编辑配置文件
                     │  ├─ 5. 更新 GeoIP/GeoSite 数据库
━━ Tailscale ━━      │  ├─ 6. 添加域名直连/代理规则
11  Tailscale 管理   │  └─ 7. 重建路由规则
12  Tailscale 兼容   │
                     └──────────────────────
━━ 其他 ━━
15  系统网络设置（IPv6 管理）
16  Docker 代理设置
13  脚本自更新
14  卸载 Mihomo
 0  退出
```

## 配置文件位置

```
/etc/mihomo/
├── config.yaml         ← 主配置文件
├── Country.mmdb        ← GeoIP 数据库（自动下载）
├── ASN.mmdb            ← ASN 数据库（自动下载）
├── geosite.dat         ← GeoSite 数据库（自动下载）
├── mihomo-rules.sh     ← TUN 路由修正脚本（自动生成）
└── ruleset/            ← 规则集缓存目录
```

## Docker 兼容

Mihomo 开启 TUN 模式后，`auto-route: true` 会创建 ip rule 劫持所有非 loopback 流量。这会导致两个问题：

1. **公网无法访问 Docker 服务** — 外部请求经 DNAT 转发到容器后，容器的 SYN-ACK 回包被 TUN 劫持，Mihomo 不认识这个连接，直接 RST
2. **容器无法通过 fake-ip 访问外网** — Docker 网段流量如果绕过 Mihomo，fake-ip（198.18.x.x）无法被还原为真实 IP，导致超时

脚本通过 `/etc/mihomo/mihomo-rules.sh` 自动添加三条 ip rule 解决：

| 优先级 | 规则 | 作用 |
|--------|------|------|
| 100 | `iif <网卡> lookup main` | 公网入站包走 main 路由，不被 TUN 劫持 |
| 190 | `from 172.16.0.0/12 to <fake-ip-range> lookup 2022` | 容器 fake-ip 流量送回 Mihomo 做 DNS 还原 |
| 200 | `from 172.16.0.0/12 lookup main` | 容器 DNAT 回包走 main 直连 |

- 网卡名和 fake-ip-range 均为**动态检测**，从系统路由表和 `config.yaml` 自动读取
- 修改 `fake-ip-range` 后，通过配置管理 → 「重建路由规则」即可一键更新

## Tailscale 共存

通过菜单选项 12 一键开关，开启后脚本自动修改配置：

| 配置项 | 作用 |
|--------|------|
| `tun.exclude-interface: tailscale0` | 防止 Mihomo TUN 劫持 Tailscale 流量 |
| `dns.fake-ip-filter: *.ts.net` | 保留 Tailscale MagicDNS 解析 |
| `IP-CIDR,100.64.0.0/10,DIRECT` | Tailscale 设备 IP 段直连 |
| `PROCESS-NAME,tailscaled,DIRECT` | Tailscale 守护进程直连 |

## 常见问题

### 启动 Mihomo 后公网无法访问服务器上的 Docker 服务

**原因**：TUN `auto-route` 劫持了 Docker 容器的 DNAT 回包。

**解决**：确保使用 v2.5.0+ 版本的脚本重新安装服务（菜单 6），或通过配置管理 → 「重建路由规则」重新生成修正规则。

### Docker 容器内无法访问百度等国内网站（fake-ip 超时）

**原因**：路由规则中的 fake-ip-range 与 `config.yaml` 中配置的不一致，导致容器的 fake-ip 流量被绕过 Mihomo。

**解决**：配置管理 → 「查看当前配置摘要」检查是否有不一致警告，然后选「重建路由规则」修复。

### Telegram / Discord 等被 GeoIP 误判为国内直连

**原因**：部分 Telegram、Discord 的 IP 被 GeoIP 数据库标记为 CN，走了 `GEOIP,CN,DIRECT` 规则。

**解决**：
1. 配置管理 → 「添加域名直连/代理规则」，添加 `telegram.org`、`t.me`、`discord.com` 等域名指向代理策略组
2. 或配置管理 → 「更新 GeoIP/GeoSite 数据库」更新到最新数据

### 容器网络走不走 TUN 透明代理？

取决于 Docker 网络模式和 TUN 配置。可通过菜单 16 → 「测试 Docker 容器网络」一键诊断。如果 TUN 未覆盖容器，可以通过 Docker 代理设置（菜单 16）配置 HTTP 代理作为替代方案。

### 修改了 config.yaml 中的 fake-ip-range 后需要做什么？

配置管理 → 「重建路由规则」，脚本会自动读取新的 range 并更新 ip rule。

### 脚本自更新失败

可能是 `raw.githubusercontent.com` 被墙或网络延迟过高。可手动更新：

```bash
curl -Lo /usr/local/bin/mihomo-manager \
  https://raw.githubusercontent.com/RaylenZed/mihomo-manager/main/mihomo-manager.sh
chmod +x /usr/local/bin/mihomo-manager
```

## License

MIT
