#!/bin/bash
# ============================================================
#  Mihomo Manager - 代理服务管理脚本
#  项目地址: https://github.com/RaylenZed/mihomo-manager
# ============================================================

# ── 常量 ────────────────────────────────────────────────────
BINARY="/usr/local/bin/mihomo"
CONFIG_DIR="/etc/mihomo"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
SERVICE_FILE="/etc/systemd/system/mihomo.service"
SERVICE_NAME="mihomo"
LATEST_VERSION_API="https://api.github.com/repos/MetaCubeX/mihomo/releases/latest"
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_VERSION="2.0.0"
SCRIPT_RAW_URL="https://raw.githubusercontent.com/RaylenZed/mihomo-manager/main/mihomo-manager.sh"
SCRIPT_VERSION_URL="https://raw.githubusercontent.com/RaylenZed/mihomo-manager/main/version"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# ── 基础工具 ─────────────────────────────────────────────────
info()    { echo -e "  ${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "  ${YELLOW}[!]${NC} $*"; }
error()   { echo -e "  ${RED}[✗]${NC} $*"; }
title()   { echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; \
            echo -e "${BOLD}${CYAN}  $*${NC}"; \
            echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }
divider() { echo -e "  ${DIM}────────────────────────────────────${NC}"; }
pause()   { echo -e "\n  按 ${BOLD}Enter${NC} 返回..."; read -r; }

ask() {
    # ask "提示" 默认值(y/n)  →  返回 0=yes 1=no
    local prompt="$1" default="${2:-n}"
    local yn
    if [ "$default" = "y" ]; then
        printf "  %s [Y/n]: " "$prompt"
    else
        printf "  %s [y/N]: " "$prompt"
    fi
    read -r yn
    yn="${yn:-$default}"
    case "$yn" in [yY]*) return 0 ;; *) return 1 ;; esac
}

require_root() {
    [ "$(id -u)" -eq 0 ] || { error "此操作需要 root 权限，请使用 sudo 运行"; return 1; }
}

# ── 状态摘要 ─────────────────────────────────────────────────
_status_bar() {
    local svc ver tun ts

    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        svc="${GREEN}运行中${NC}"
    else
        svc="${RED}已停止${NC}"
    fi

    if [ -f "$BINARY" ]; then
        ver=$("$BINARY" -v 2>/dev/null | grep -o 'v[0-9.]*' | head -1)
    else
        ver="未安装"
    fi

    ip link show Meta >/dev/null 2>&1 && tun="${GREEN}已启用${NC}" || tun="${YELLOW}未启用${NC}"

    command -v tailscale >/dev/null 2>&1 && ts="${GREEN}已安装${NC}" || ts="${DIM}未安装${NC}"

    echo -e "  Mihomo: $svc  版本: ${CYAN}$ver${NC}  TUN: $tun  Tailscale: $ts"
}

# ════════════════════════════════════════════════════════════
#  主菜单
# ════════════════════════════════════════════════════════════
main_menu() {
    while true; do
        clear
        echo -e "${BOLD}${CYAN}"
        echo "  ╔══════════════════════════════════════╗"
        echo "  ║         Mihomo Manager v${SCRIPT_VERSION}         ║"
        echo "  ╚══════════════════════════════════════╝${NC}"
        echo ""
        _status_bar
        echo ""
        divider
        echo -e "  ${BOLD}Mihomo 服务${NC}"
        divider
        echo "  1. 查看状态"
        echo "  2. 启动服务"
        echo "  3. 停止服务"
        echo "  4. 重启服务"
        echo "  5. 开机自启设置"
        echo ""
        divider
        echo -e "  ${BOLD}安装与配置${NC}"
        divider
        echo "  6. 安装 Mihomo"
        echo "  7. 配置文件管理"
        echo "  8. 更新 Mihomo"
        echo ""
        divider
        echo -e "  ${BOLD}诊断与监控${NC}"
        divider
        echo "  9. 网络连通性测试"
        echo " 10. 查看日志"
        echo ""
        divider
        echo -e "  ${BOLD}Tailscale${NC}"
        divider
        echo " 11. Tailscale 管理"
        echo " 12. Tailscale 兼容设置"
        echo ""
        divider
        echo -e "  ${BOLD}其他${NC}"
        divider
        echo " 13. 脚本自更新  ${DIM}(当前 v${SCRIPT_VERSION})${NC}"
        echo " 14. 卸载 Mihomo"
        echo "  0. 退出"
        divider
        echo ""
        printf "  请输入选项: "
        read -r choice

        case "$choice" in
            1)  menu_status ;;
            2)  menu_start ;;
            3)  menu_stop ;;
            4)  menu_restart ;;
            5)  menu_autostart ;;
            6)  menu_install ;;
            7)  menu_config ;;
            8)  menu_update ;;
            9)  menu_test ;;
            10) menu_log ;;
            11) menu_tailscale_manage ;;
            12) menu_tailscale_compat ;;
            13) menu_self_update ;;
            14) menu_uninstall ;;
            0)  clear; echo "  再见！"; exit 0 ;;
            *)  error "无效选项，请重新输入"; sleep 1 ;;
        esac
    done
}

# ════════════════════════════════════════════════════════════
#  Mihomo 服务管理
# ════════════════════════════════════════════════════════════
menu_status() {
    clear
    title "Mihomo 运行状态"

    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        info "服务状态:  ${GREEN}● 运行中${NC}"
    else
        error "服务状态:  ● 已停止"
    fi

    if systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
        info "开机自启:  已启用"
    else
        warn "开机自启:  未启用"
    fi

    [ -f "$BINARY" ] && info "版本:      $("$BINARY" -v 2>/dev/null | head -1)"

    local ports
    ports=$(ss -tlnp 2>/dev/null | grep mihomo | awk '{print $4}' | tr '\n' '  ')
    [ -n "$ports" ] && info "监听端口:  $ports"

    if ip link show Meta >/dev/null 2>&1; then
        info "TUN 接口:  ${GREEN}Meta (已创建)${NC}"
    else
        warn "TUN 接口:  未创建"
    fi

    if [ -f "$CONFIG_FILE" ]; then
        info "配置文件:  $CONFIG_FILE ${GREEN}(存在)${NC}"
        local ctrl
        ctrl=$(grep 'external-controller' "$CONFIG_FILE" 2>/dev/null | awk '{print $2}')
        [ -n "$ctrl" ] && info "控制面板:  http://$ctrl"
    else
        error "配置文件:  缺失"
    fi

    echo ""
    divider
    echo ""
    systemctl status "$SERVICE_NAME" --no-pager -l 2>/dev/null | tail -12 || true
    pause
}

menu_start() {
    require_root || { pause; return; }
    clear
    title "启动 Mihomo"
    if [ ! -f "$CONFIG_FILE" ]; then
        error "配置文件不存在: $CONFIG_FILE"
        warn "请先通过「配置文件管理」导入配置"
        pause; return
    fi
    systemctl start "$SERVICE_NAME" && info "服务已启动" || error "启动失败"
    sleep 1
    echo ""
    systemctl status "$SERVICE_NAME" --no-pager | tail -5
    pause
}

menu_stop() {
    require_root || { pause; return; }
    clear
    title "停止 Mihomo"
    ask "确定要停止 Mihomo 服务吗？" n || return
    systemctl stop "$SERVICE_NAME" && info "服务已停止" || error "停止失败"
    pause
}

menu_restart() {
    require_root || { pause; return; }
    clear
    title "重启 Mihomo"
    systemctl restart "$SERVICE_NAME" && info "服务已重启" || error "重启失败"
    sleep 1
    echo ""
    systemctl status "$SERVICE_NAME" --no-pager | tail -5
    pause
}

menu_autostart() {
    require_root || { pause; return; }
    clear
    title "开机自启设置"

    if systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
        info "当前状态: 已启用"
        echo ""
        echo "  1. 取消开机自启"
        echo "  0. 返回"
        echo ""
        printf "  请输入选项: "
        read -r c
        [ "$c" = "1" ] && systemctl disable "$SERVICE_NAME" && info "已取消开机自启"
    else
        warn "当前状态: 未启用"
        echo ""
        echo "  1. 设为开机自启"
        echo "  0. 返回"
        echo ""
        printf "  请输入选项: "
        read -r c
        [ "$c" = "1" ] && systemctl enable "$SERVICE_NAME" && info "已设为开机自启"
    fi
    pause
}

# ════════════════════════════════════════════════════════════
#  安装与配置
# ════════════════════════════════════════════════════════════
menu_install() {
    require_root || { pause; return; }
    clear
    title "安装 Mihomo"

    if [ -f "$BINARY" ]; then
        local ver
        ver=$("$BINARY" -v 2>/dev/null | grep -o 'v[0-9.]*' | head -1)
        warn "Mihomo $ver 已安装"
        ask "是否重新安装（覆盖）？" n || return
        echo ""
    fi

    info "获取最新版本信息..."
    local latest arch_name download_url
    latest=$(curl -s --max-time 15 "$LATEST_VERSION_API" | grep '"tag_name"' | head -1 | grep -o 'v[0-9.]*')

    if [ -z "$latest" ]; then
        error "无法获取版本信息（服务器可能无法访问 GitHub）"
        echo ""
        warn "请在本机执行以下命令后将文件传到服务器："
        local arch
        arch=$(uname -m)
        [ "$arch" = "aarch64" ] && arch="arm64" || arch="amd64"
        echo ""
        echo "  curl -L -o /tmp/mihomo.gz 'https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-linux-${arch}.gz'"
        echo "  gunzip /tmp/mihomo.gz"
        echo "  scp /tmp/mihomo-linux-${arch} 服务器:/usr/local/bin/mihomo"
        echo ""
        warn "传完后重新选择「安装 Mihomo」即可完成后续步骤"
        pause; return
    fi

    info "最新版本: $latest"

    case $(uname -m) in
        x86_64)  arch_name="amd64" ;;
        aarch64) arch_name="arm64" ;;
        armv7l)  arch_name="armv7" ;;
        *) error "不支持的架构: $(uname -m)"; pause; return ;;
    esac

    download_url="https://github.com/MetaCubeX/mihomo/releases/download/${latest}/mihomo-linux-${arch_name}-${latest}.gz"
    info "下载中: $download_url"
    echo ""

    local tmp_gz
    tmp_gz=$(mktemp /tmp/mihomo-XXXXXX.gz)
    if curl -L -o "$tmp_gz" "$download_url" --progress-bar; then
        info "解压安装..."
        gunzip -f "$tmp_gz"
        local tmp_bin="${tmp_gz%.gz}"
        mv "$tmp_bin" "$BINARY"
        chmod +x "$BINARY"
        rm -f "$tmp_gz" 2>/dev/null || true
        info "Mihomo $latest 安装成功"
    else
        rm -f "$tmp_gz" 2>/dev/null || true
        error "下载失败"
        warn "请参考上方手动安装说明"
        pause; return
    fi

    echo ""
    mkdir -p "$CONFIG_DIR/ruleset"
    _install_geodata
    echo ""
    _install_service
    _install_alias
    echo ""
    info "全部完成！下一步请通过「配置文件管理」导入 config.yaml"
    pause
}

_install_geodata() {
    info "下载 GeoIP 数据库..."
    curl -sL --max-time 30 -o "$CONFIG_DIR/Country.mmdb" \
        "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/country.mmdb" \
        && info "Country.mmdb 下载成功" \
        || warn "Country.mmdb 下载失败，可手动放到 $CONFIG_DIR/Country.mmdb"

    curl -sL --max-time 30 -o "$CONFIG_DIR/ASN.mmdb" \
        "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/GeoLite2-ASN.mmdb" \
        && info "ASN.mmdb 下载成功" \
        || warn "ASN.mmdb 下载失败，可手动放到 $CONFIG_DIR/ASN.mmdb"
}

_install_service() {
    cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=Mihomo Proxy Service
After=network.target NetworkManager.service systemd-networkd.service

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/mihomo -d /etc/mihomo
Restart=always
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    info "systemd 服务注册完成，已设为开机自启"
}

_install_alias() {
    ln -sf "$SCRIPT_PATH" /usr/local/bin/mm
    info "已创建快捷命令 mm（等同于 mihomo-manager）"
}

menu_config() {
    while true; do
        clear
        title "配置文件管理"
        echo "  配置文件路径: ${BOLD}$CONFIG_FILE${NC}"
        echo ""
        echo "  1. 查看当前配置摘要"
        echo "  2. 从路径导入配置文件"
        echo "  3. 查看目录结构说明"
        echo "  0. 返回主菜单"
        echo ""
        printf "  请输入选项: "
        read -r c
        case "$c" in
            1) _config_show ;;
            2) _config_import ;;
            3) _config_tree ;;
            0) return ;;
            *) error "无效选项"; sleep 1 ;;
        esac
    done
}

_config_show() {
    clear
    title "当前配置摘要"
    if [ ! -f "$CONFIG_FILE" ]; then
        warn "配置文件不存在: $CONFIG_FILE"
        pause; return
    fi
    info "混合端口:  $(grep 'mixed-port' "$CONFIG_FILE" | awk '{print $2}')"
    info "控制面板:  $(grep 'external-controller' "$CONFIG_FILE" | awk '{print $2}')"
    info "代理模式:  $(grep '^mode:' "$CONFIG_FILE" | awk '{print $2}')"
    info "TUN 模式:  $(grep -A2 '^tun:' "$CONFIG_FILE" | grep 'enable' | awk '{print $2}')"
    info "DNS 模式:  $(grep 'enhanced-mode' "$CONFIG_FILE" | awk '{print $2}')"
    echo ""
    divider
    echo -e "  ${BOLD}代理节点:${NC}"
    grep '  - name:' "$CONFIG_FILE" | sed 's/  - name:/    •/'
    echo ""
    divider
    echo -e "  ${BOLD}策略组:${NC}"
    grep -A1 'proxy-groups:' "$CONFIG_FILE" | grep 'name:' | sed 's/.*name:/    •/'
    pause
}

_config_import() {
    require_root || { pause; return; }
    clear
    title "导入配置文件"
    printf "  请输入配置文件完整路径: "
    read -r src

    [ -z "$src" ] && { error "路径不能为空"; pause; return; }
    [ ! -f "$src" ] && { error "文件不存在: $src"; pause; return; }

    cp "$src" "$CONFIG_FILE"
    info "配置已导入到 $CONFIG_FILE"

    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        echo ""
        if ask "服务正在运行，是否立即重启以应用新配置？" y; then
            systemctl restart "$SERVICE_NAME" && info "服务已重启" || error "重启失败"
        fi
    fi
    pause
}

_config_tree() {
    clear
    title "目录结构说明"
    echo "  $CONFIG_DIR/"
    echo "  ├── config.yaml     ← ${YELLOW}主配置文件（放这里）${NC}"
    echo "  ├── Country.mmdb    ← GeoIP 数据库（自动下载）"
    echo "  ├── ASN.mmdb        ← ASN 数据库（自动下载）"
    echo "  └── ruleset/        ← 规则集缓存目录"
    echo ""
    divider
    echo ""
    echo "  从本机 scp 上传配置："
    echo "  ${CYAN}scp /本机/config.yaml 服务器:$CONFIG_FILE${NC}"
    echo ""
    echo "  Web 控制面板（浏览器访问）："
    local ctrl
    ctrl=$(grep 'external-controller' "$CONFIG_FILE" 2>/dev/null | awk '{print $2}')
    [ -n "$ctrl" ] && echo "  ${CYAN}http://服务器IP:$(echo "$ctrl" | cut -d: -f2)${NC}" \
                   || echo "  ${DIM}（配置文件中未设置 external-controller）${NC}"
    pause
}

menu_update() {
    require_root || { pause; return; }
    clear
    title "更新 Mihomo"

    local current latest
    current=$("$BINARY" -v 2>/dev/null | grep -o 'v[0-9.]*' | head -1 || echo "未安装")
    info "当前版本: $current"
    info "正在检查最新版本..."
    latest=$(curl -s --max-time 15 "$LATEST_VERSION_API" | grep '"tag_name"' | head -1 | grep -o 'v[0-9.]*')

    if [ -z "$latest" ]; then
        error "无法获取版本信息"; pause; return
    fi

    info "最新版本: $latest"

    if [ "$current" = "$latest" ]; then
        echo ""
        info "已是最新版本，无需更新"
        pause; return
    fi

    echo ""
    if ask "发现新版本 $latest，是否立即更新？" y; then
        systemctl stop "$SERVICE_NAME" 2>/dev/null || true
        menu_install
        systemctl start "$SERVICE_NAME" 2>/dev/null || true
    fi
}

# ════════════════════════════════════════════════════════════
#  诊断与监控
# ════════════════════════════════════════════════════════════
menu_test() {
    clear
    title "网络连通性测试"
    local port
    port=$(grep 'mixed-port' "$CONFIG_FILE" 2>/dev/null | awk '{print $2}' || echo "7890")

    _test() {
        local name="$1" url="$2" proxy="$3"
        printf "  %-30s" "$name"
        local code
        if [ -n "$proxy" ]; then
            code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" --proxy "$proxy" "$url" 2>/dev/null)
        else
            code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
        fi
        if [ "$code" -ge 200 ] && [ "$code" -lt 400 ] 2>/dev/null; then
            echo -e "${GREEN}✓  $code${NC}"
        else
            echo -e "${RED}✗  $code${NC}"
        fi
    }

    echo -e "  ${BOLD}[ TUN 透明代理 ]${NC}"
    echo ""
    _test "Google"       "https://www.google.com"
    _test "YouTube"      "https://www.youtube.com"
    _test "GitHub"       "https://github.com"
    _test "Twitter / X"  "https://twitter.com"
    _test "Baidu"        "https://www.baidu.com"
    echo ""
    divider
    echo ""
    echo -e "  ${BOLD}[ HTTP 代理 端口 $port ]${NC}"
    echo ""
    _test "Google  (via proxy)"  "https://www.google.com"  "http://127.0.0.1:$port"
    _test "Baidu   (via proxy)"  "https://www.baidu.com"   "http://127.0.0.1:$port"
    pause
}

menu_log() {
    while true; do
        clear
        title "查看日志"
        echo "  1. 最近 50 条"
        echo "  2. 最近 100 条"
        echo "  3. 实时日志（Ctrl+C 退出后按 Enter 返回）"
        echo "  0. 返回"
        echo ""
        printf "  请输入选项: "
        read -r c
        case "$c" in
            1) clear; journalctl -u "$SERVICE_NAME" --no-pager -n 50; pause ;;
            2) clear; journalctl -u "$SERVICE_NAME" --no-pager -n 100; pause ;;
            3) clear; journalctl -u "$SERVICE_NAME" -f; pause ;;
            0) return ;;
            *) error "无效选项"; sleep 1 ;;
        esac
    done
}

# ════════════════════════════════════════════════════════════
#  Tailscale 管理
# ════════════════════════════════════════════════════════════
menu_tailscale_manage() {
    while true; do
        clear
        title "Tailscale 管理"

        # 状态摘要
        if command -v tailscale >/dev/null 2>&1; then
            local ts_svc ts_ip
            systemctl is-active tailscaled >/dev/null 2>&1 \
                && ts_svc="${GREEN}运行中${NC}" || ts_svc="${RED}已停止${NC}"
            ts_ip=$(tailscale ip 2>/dev/null | head -1 || echo "未连接")
            echo -e "  服务: $ts_svc  |  IP: ${CYAN}$ts_ip${NC}"
        else
            warn "Tailscale 未安装"
        fi

        echo ""
        echo "  1. 查看状态与设备列表"
        echo "  2. 连接 Tailscale 网络"
        echo "  3. 断开 Tailscale 网络"
        echo "  4. 重启 tailscaled 服务"
        divider
        echo "  5. 安装 Tailscale"
        echo "  6. 卸载 Tailscale"
        echo "  0. 返回"
        echo ""
        printf "  请输入选项: "
        read -r c
        case "$c" in
            1) _ts_status ;;
            2) _ts_up ;;
            3) _ts_down ;;
            4) _ts_restart ;;
            5) _ts_install ;;
            6) _ts_uninstall ;;
            0) return ;;
            *) error "无效选项"; sleep 1 ;;
        esac
    done
}

_ts_check() {
    command -v tailscale >/dev/null 2>&1 || { error "Tailscale 未安装，请先选择「安装 Tailscale」"; pause; return 1; }
}

_ts_status() {
    _ts_check || return
    clear
    title "Tailscale 状态"

    systemctl is-active tailscaled >/dev/null 2>&1 \
        && info "服务状态: ${GREEN}● 运行中${NC}" || error "服务状态: ● 已停止"

    info "本机 IP:  ${CYAN}$(tailscale ip 2>/dev/null | head -1 || echo '未连接')${NC}"
    echo ""
    divider
    echo ""
    tailscale status 2>/dev/null || warn "未连接到 Tailscale 网络"
    pause
}

_ts_up() {
    _ts_check || return
    require_root || { pause; return; }
    clear
    title "连接 Tailscale 网络"

    local extra=""
    if ask "是否接受其他节点共享的子网路由？（不确定选 n）" n; then
        extra="--accept-routes"
    fi
    echo ""

    if ! tailscale status >/dev/null 2>&1; then
        warn "尚未登录，正在获取认证链接..."
        echo ""

        # tailscale up 在非交互终端会将 URL 写入 /dev/tty 而非 stdout/stderr
        # 方案：后台运行 + 轮询临时文件提取 URL
        local ts_log
        ts_log=$(mktemp /tmp/ts-up-XXXXXX.log)
        tailscale up $extra >"$ts_log" 2>&1 &
        local ts_pid=$!

        local auth_url="" i=0
        while [ $i -lt 30 ]; do
            sleep 0.5
            auth_url=$(grep -o 'https://login\.tailscale\.com/[^ ]*' "$ts_log" 2>/dev/null | head -1)
            [ -n "$auth_url" ] && break
            i=$((i + 1))
        done

        if [ -n "$auth_url" ]; then
            echo -e "  请在浏览器中打开以下链接完成认证："
            echo ""
            echo -e "  ${BOLD}${CYAN}$auth_url${NC}"
            echo ""
            warn "认证完成后连接将自动建立，请稍候..."
            wait "$ts_pid" 2>/dev/null || true
        else
            warn "未能自动提取认证链接，原始输出如下："
            echo ""
            cat "$ts_log"
            wait "$ts_pid" 2>/dev/null || true
        fi

        rm -f "$ts_log"
    else
        tailscale up $extra 2>&1 && info "已连接到 Tailscale 网络" || error "连接失败"
    fi

    echo ""
    local ts_ip
    ts_ip=$(tailscale ip 2>/dev/null | head -1)
    [ -n "$ts_ip" ] && info "本机 Tailscale IP: $ts_ip"
    pause
}

_ts_down() {
    _ts_check || return
    require_root || { pause; return; }
    clear
    title "断开 Tailscale 网络"
    ask "确定要断开 Tailscale 网络连接吗？（tailscaled 服务仍会保持运行）" n || return
    tailscale down && info "已断开 Tailscale 网络" || error "断开失败"
    pause
}

_ts_restart() {
    require_root || { pause; return; }
    _ts_check || return
    clear
    title "重启 tailscaled 服务"
    systemctl restart tailscaled && info "tailscaled 已重启" || error "重启失败"
    sleep 1
    systemctl status tailscaled --no-pager | tail -5
    pause
}

_ts_install() {
    require_root || { pause; return; }
    clear
    title "安装 Tailscale"

    if command -v tailscale >/dev/null 2>&1; then
        info "Tailscale 已安装: $(tailscale version 2>/dev/null | head -1)"
        pause; return
    fi

    info "正在下载并运行官方安装脚本..."
    echo ""
    if curl -fsSL https://tailscale.com/install.sh | sh; then
        echo ""
        info "安装成功！版本: $(tailscale version 2>/dev/null | head -1)"
        echo ""
        warn "下一步：选择「连接 Tailscale 网络」完成认证登录"
        if ! _tailscale_compat_enabled; then
            echo ""
            warn "建议返回主菜单开启「Tailscale 兼容设置」，避免与 Mihomo 冲突"
        fi
    else
        error "安装失败，请检查网络连接"
    fi
    pause
}

_ts_uninstall() {
    require_root || { pause; return; }
    _ts_check || return
    clear
    title "卸载 Tailscale"
    ask "确定要卸载 Tailscale 吗？" n || return
    echo ""

    tailscale down 2>/dev/null || true
    systemctl stop tailscaled 2>/dev/null || true

    if command -v apt >/dev/null 2>&1; then
        apt-get remove -y tailscale && info "已通过 apt 卸载"
    elif command -v yum >/dev/null 2>&1; then
        yum remove -y tailscale && info "已通过 yum 卸载"
    else
        rm -f /usr/bin/tailscale /usr/sbin/tailscaled
        rm -f /etc/systemd/system/tailscaled.service
        systemctl daemon-reload
        info "已手动删除 Tailscale 文件"
    fi

    if _tailscale_compat_enabled; then
        echo ""
        warn "Tailscale 已卸载，建议返回主菜单关闭「Tailscale 兼容设置」"
    fi
    pause
}

# ════════════════════════════════════════════════════════════
#  Tailscale 兼容设置
# ════════════════════════════════════════════════════════════
_tailscale_compat_enabled() {
    [ -f "$CONFIG_FILE" ] && grep -q 'tailscale0' "$CONFIG_FILE"
}

menu_tailscale_compat() {
    clear
    title "Tailscale 兼容设置"

    if _tailscale_compat_enabled; then
        info "当前状态: ${GREEN}已启用${NC}"
        local ts_ip
        ts_ip=$(ip addr show tailscale0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
        [ -n "$ts_ip" ] && info "Tailscale IP: $ts_ip"
    else
        warn "当前状态: 未启用"
    fi

    echo ""
    echo "  此设置修改 Mihomo 配置，防止与 Tailscale 流量冲突："
    echo "  • tun.exclude-interface: tailscale0"
    echo "  • dns.fake-ip-filter: *.ts.net"
    echo "  • rules: 100.64.0.0/10 → DIRECT"
    echo "  • rules: tailscaled 进程 → DIRECT"
    echo ""
    divider

    if _tailscale_compat_enabled; then
        echo ""
        echo "  1. 关闭兼容设置"
        echo "  0. 返回"
        echo ""
        printf "  请输入选项: "
        read -r c
        [ "$c" = "1" ] && _tailscale_compat_disable
    else
        echo ""
        echo "  1. 启用兼容设置"
        echo "  0. 返回"
        echo ""
        printf "  请输入选项: "
        read -r c
        [ "$c" = "1" ] && _tailscale_compat_enable
    fi
}

_tailscale_compat_enable() {
    require_root || { pause; return; }
    clear
    title "启用 Tailscale 兼容"

    # tun exclude-interface
    if grep -q 'exclude-interface' "$CONFIG_FILE"; then
        grep -q 'tailscale0' "$CONFIG_FILE" \
            && info "exclude-interface 已包含 tailscale0，跳过" \
            || { sed -i '/exclude-interface:/a\    - tailscale0' "$CONFIG_FILE"; info "已添加 tun.exclude-interface: tailscale0"; }
    else
        sed -i '/dns-hijack:/i\  exclude-interface:\n    - tailscale0' "$CONFIG_FILE"
        info "已添加 tun.exclude-interface: tailscale0"
    fi

    # fake-ip-filter
    if grep -q 'fake-ip-filter' "$CONFIG_FILE"; then
        grep -q 'ts.net' "$CONFIG_FILE" \
            && info "fake-ip-filter 已包含 *.ts.net，跳过" \
            || { sed -i "/fake-ip-filter:/a\    - '*.ts.net'" "$CONFIG_FILE"; info "已添加 dns.fake-ip-filter: *.ts.net"; }
    else
        sed -i "/enhanced-mode:/a\  fake-ip-filter:\n    - '*.ts.net'" "$CONFIG_FILE"
        info "已添加 dns.fake-ip-filter: *.ts.net"
    fi

    # 路由规则
    if ! grep -q '100.64.0.0/10' "$CONFIG_FILE"; then
        sed -i '/- GEOIP,LAN,DIRECT/i\  - IP-CIDR,100.64.0.0\/10,DIRECT,no-resolve\n  - IP-CIDR,100.100.100.100\/32,DIRECT\n  - PROCESS-NAME,tailscaled,DIRECT' "$CONFIG_FILE"
        info "已添加 Tailscale IP 段直连规则"
    else
        info "Tailscale 规则已存在，跳过"
    fi

    echo ""
    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        systemctl restart "$SERVICE_NAME" && info "Mihomo 已重启，配置生效" || error "重启失败"
    else
        warn "Mihomo 未运行，下次启动时生效"
    fi
    pause
}

_tailscale_compat_disable() {
    require_root || { pause; return; }
    clear
    title "关闭 Tailscale 兼容"

    sed -i '/tailscale0/d' "$CONFIG_FILE"
    sed -i "/'\*\.ts\.net'/d" "$CONFIG_FILE"
    sed -i '/100\.64\.0\.0\/10/d' "$CONFIG_FILE"
    sed -i '/100\.100\.100\.100/d' "$CONFIG_FILE"
    sed -i '/PROCESS-NAME,tailscaled/d' "$CONFIG_FILE"
    info "已移除所有 Tailscale 兼容配置"

    echo ""
    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        systemctl restart "$SERVICE_NAME" && info "Mihomo 已重启，配置生效" || error "重启失败"
    fi
    pause
}

# ════════════════════════════════════════════════════════════
#  脚本自更新
# ════════════════════════════════════════════════════════════
menu_self_update() {
    require_root || { pause; return; }
    clear
    title "脚本自更新"

    info "当前版本: v$SCRIPT_VERSION"
    info "正在检查最新版本（最长等待 30 秒）..."

    local latest_ver
    latest_ver=$(curl -fsSL --max-time 30 "$SCRIPT_VERSION_URL" 2>/dev/null | tr -d '[:space:]')

    if [ -z "$latest_ver" ]; then
        error "无法获取版本信息"
        echo ""
        warn "可能原因：raw.githubusercontent.com 网络延迟过高，可稍后重试"
        warn "或手动更新："
        echo ""
        echo "  curl -Lo $SCRIPT_PATH $SCRIPT_RAW_URL && chmod +x $SCRIPT_PATH"
        pause; return
    fi

    info "最新版本: v$latest_ver"

    if [ "$SCRIPT_VERSION" = "$latest_ver" ]; then
        echo ""
        info "已是最新版本，无需更新"
        pause; return
    fi

    echo ""
    ask "发现新版本 v$latest_ver，是否立即更新？" y || return

    clear
    title "下载更新..."

    local tmp_script
    tmp_script=$(mktemp /tmp/mihomo-manager-XXXXXX.sh)

    if curl -fsSL --max-time 60 -o "$tmp_script" "$SCRIPT_RAW_URL"; then
        if ! bash -n "$tmp_script" 2>/dev/null; then
            error "下载的文件校验失败，已中止更新"
            rm -f "$tmp_script"; pause; return
        fi

        chmod +x "$tmp_script"
        cp "$SCRIPT_PATH" "${SCRIPT_PATH}.bak"
        info "已备份当前版本到 ${SCRIPT_PATH}.bak"
        mv "$tmp_script" "$SCRIPT_PATH"
        info "更新完成！v$SCRIPT_VERSION → v$latest_ver"
        echo ""
        warn "即将重新启动..."
        sleep 2
        exec "$SCRIPT_PATH"
    else
        rm -f "$tmp_script"
        error "下载失败，更新已中止"
        warn "可手动更新："
        echo ""
        echo "  curl -Lo $SCRIPT_PATH $SCRIPT_RAW_URL && chmod +x $SCRIPT_PATH"
        pause
    fi
}

# ════════════════════════════════════════════════════════════
#  卸载 Mihomo
# ════════════════════════════════════════════════════════════
menu_uninstall() {
    require_root || { pause; return; }
    clear
    title "卸载 Mihomo"

    echo "  1. 卸载程序（保留配置文件）"
    echo "  2. 完全卸载（删除程序 + 配置）"
    echo "  0. 返回"
    echo ""
    printf "  请输入选项: "
    read -r mode

    [ "$mode" = "0" ] && return
    [[ "$mode" != "1" && "$mode" != "2" ]] && { error "无效选项"; sleep 1; return; }

    echo ""
    ask "确认卸载？" n || return

    echo ""
    systemctl stop "$SERVICE_NAME" 2>/dev/null && info "服务已停止"
    systemctl disable "$SERVICE_NAME" 2>/dev/null && info "开机自启已取消"
    rm -f "$SERVICE_FILE" && systemctl daemon-reload
    rm -f "$BINARY" /usr/local/bin/mm && info "二进制和 mm 命令已删除"

    if [ "$mode" = "2" ]; then
        rm -rf "$CONFIG_DIR" && info "配置目录已删除"
    else
        warn "配置文件保留在 $CONFIG_DIR"
    fi

    info "卸载完成"
    pause
}

# ════════════════════════════════════════════════════════════
#  入口：支持命令行参数直接调用
# ════════════════════════════════════════════════════════════
case "${1:-}" in
    start)      require_root && systemctl start "$SERVICE_NAME" ;;
    stop)       require_root && systemctl stop "$SERVICE_NAME" ;;
    restart)    require_root && systemctl restart "$SERVICE_NAME" ;;
    status)     menu_status ;;
    test)       menu_test ;;
    log)        journalctl -u "$SERVICE_NAME" --no-pager -n "${2:-50}" ;;
    log-follow) journalctl -u "$SERVICE_NAME" -f ;;
    "")         main_menu ;;
    *)          echo "用法: $(basename "$0") [start|stop|restart|status|test|log|log-follow]" ;;
esac
