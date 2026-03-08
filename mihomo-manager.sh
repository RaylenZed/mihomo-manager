#!/bin/bash
# ============================================================
#  Mihomo Manager - 交互式代理管理脚本
# ============================================================

# ── 常量 ────────────────────────────────────────────────────
BINARY="/usr/local/bin/mihomo"
CONFIG_DIR="/etc/mihomo"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
SERVICE_FILE="/etc/systemd/system/mihomo.service"
SERVICE_NAME="mihomo"
LATEST_VERSION_API="https://api.github.com/repos/MetaCubeX/mihomo/releases/latest"
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_VERSION="1.1.2"
SCRIPT_RAW_URL="https://raw.githubusercontent.com/RaylenZed/mihomo-manager/main/mihomo-manager.sh"
SCRIPT_VERSION_URL="https://raw.githubusercontent.com/RaylenZed/mihomo-manager/main/version"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── 工具函数 ─────────────────────────────────────────────────
info()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*"; }
section() { echo -e "\n${BOLD}${CYAN}━━ $* ━━${NC}"; }
pause()   { echo -e "\n按 ${BOLD}Enter${NC} 返回菜单..."; read -r; }

require_root() {
    [ "$(id -u)" -eq 0 ] || {
        whiptail --title "权限不足" --msgbox "此操作需要 root 权限。\n请使用 sudo $(basename "$SCRIPT_PATH") 运行。" 8 50
        return 1
    }
}

# ── 状态栏（菜单顶部信息） ────────────────────────────────────
_status_line() {
    local svc_status installed version tun_status config_status

    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        svc_status="运行中 ●"
    else
        svc_status="已停止 ○"
    fi

    if [ -f "$BINARY" ]; then
        version=$("$BINARY" -v 2>/dev/null | grep -o 'v[0-9.]*' | head -1)
        installed="已安装 ($version)"
    else
        installed="未安装"
    fi

    if ip link show Meta >/dev/null 2>&1; then
        tun_status="已启用"
    else
        tun_status="未启用"
    fi

    [ -f "$CONFIG_FILE" ] && config_status="存在" || config_status="缺失"

    echo "服务: $svc_status  |  版本: $installed  |  TUN: $tun_status  |  配置: $config_status"
}

# ── 主菜单 ────────────────────────────────────────────────────
main_menu() {
    while true; do
        local STATUS TS_LABEL
        STATUS=$(_status_line)
        if _tailscale_enabled; then
            TS_LABEL="Tailscale 兼容  [已启用]"
        else
            TS_LABEL="Tailscale 兼容  [未启用]"
        fi

        local TS_INSTALLED
        command -v tailscale >/dev/null 2>&1 && TS_INSTALLED="已安装" || TS_INSTALLED="未安装"

        CHOICE=$(whiptail --title "Mihomo Manager" \
            --menu "$STATUS\n\n请选择操作：" 26 65 14 \
            "1" "查看状态" \
            "2" "启动服务" \
            "3" "停止服务" \
            "4" "重启服务" \
            "5" "开机自启 设置" \
            "6" "─────────────────────" \
            "7" "安装 Mihomo" \
            "8" "导入 / 查看配置文件" \
            "9" "更新到最新版本" \
            "10" "─────────────────────" \
            "11" "网络连通性测试" \
            "12" "查看日志" \
            "13" "─────────────────────" \
            "15" "Tailscale 管理  [$TS_INSTALLED]" \
            "16" "$TS_LABEL" \
            "17" "─────────────────────" \
            "14" "卸载 Mihomo" \
            "18" "脚本自更新  [当前 v$SCRIPT_VERSION]" \
            "0" "退出" \
            3>&1 1>&2 2>&3) || break

        case "$CHOICE" in
            1)  menu_status ;;
            2)  menu_start ;;
            3)  menu_stop ;;
            4)  menu_restart ;;
            5)  menu_autostart ;;
            6|10|13) : ;;
            7)  menu_install ;;
            8)  menu_config ;;
            9)  menu_update ;;
            11) menu_test ;;
            12) menu_log ;;
            15) menu_tailscale_manage ;;
            16) menu_tailscale ;;
            17) : ;;
            14) menu_uninstall ;;
            18) menu_self_update ;;
            0)  clear; exit 0 ;;
        esac
    done
    clear
}

# ── 状态 ─────────────────────────────────────────────────────
menu_status() {
    clear
    section "Mihomo 运行状态"

    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        echo -e "  服务状态:  ${GREEN}● 运行中${NC}"
    else
        echo -e "  服务状态:  ${RED}● 已停止${NC}"
    fi

    if systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
        echo -e "  开机自启:  ${GREEN}已启用${NC}"
    else
        echo -e "  开机自启:  ${YELLOW}未启用${NC}"
    fi

    [ -f "$BINARY" ] && echo -e "  版本:      $("$BINARY" -v 2>/dev/null | head -1)"

    PORTS=$(ss -tlnp 2>/dev/null | grep mihomo | awk '{print $4}' | tr '\n' '  ')
    [ -n "$PORTS" ] && echo -e "  监听端口:  $PORTS"

    if ip link show Meta >/dev/null 2>&1; then
        echo -e "  TUN 接口:  ${GREEN}Meta (已创建)${NC}"
    else
        echo -e "  TUN 接口:  ${YELLOW}未创建${NC}"
    fi

    [ -f "$CONFIG_FILE" ] \
        && echo -e "  配置文件:  $CONFIG_FILE ${GREEN}(存在)${NC}" \
        || echo -e "  配置文件:  ${RED}缺失${NC}"

    CTRL=$(grep 'external-controller' "$CONFIG_FILE" 2>/dev/null | awk '{print $2}')
    [ -n "$CTRL" ] && echo -e "  控制面板:  http://$CTRL"

    echo ""
    systemctl status "$SERVICE_NAME" --no-pager -l 2>/dev/null | tail -10 || true
    pause
}

# ── 启动 ─────────────────────────────────────────────────────
menu_start() {
    require_root || return
    if ! [ -f "$CONFIG_FILE" ]; then
        whiptail --title "错误" --msgbox "配置文件不存在：$CONFIG_FILE\n\n请先通过「导入配置文件」选项配置。" 10 55
        return
    fi
    clear
    section "启动 Mihomo"
    systemctl start "$SERVICE_NAME" && info "服务已启动" || error "启动失败"
    sleep 2
    systemctl status "$SERVICE_NAME" --no-pager | tail -6
    pause
}

# ── 停止 ─────────────────────────────────────────────────────
menu_stop() {
    require_root || return
    if whiptail --title "确认停止" --yesno "确定要停止 Mihomo 服务吗？\n停止后所有代理流量将中断。" 9 50; then
        clear
        section "停止 Mihomo"
        systemctl stop "$SERVICE_NAME" && info "服务已停止" || error "停止失败"
        pause
    fi
}

# ── 重启 ─────────────────────────────────────────────────────
menu_restart() {
    require_root || return
    clear
    section "重启 Mihomo"
    systemctl restart "$SERVICE_NAME" && info "服务已重启" || error "重启失败"
    sleep 2
    systemctl status "$SERVICE_NAME" --no-pager | tail -6
    pause
}

# ── 开机自启 ──────────────────────────────────────────────────
menu_autostart() {
    require_root || return
    local current
    if systemctl is-enabled "$SERVICE_NAME" >/dev/null 2>&1; then
        current="已启用"
        ACTION=$(whiptail --title "开机自启" --menu "当前状态：$current" 12 50 2 \
            "disable" "取消开机自启" \
            "back"    "返回" \
            3>&1 1>&2 2>&3) || return
        [ "$ACTION" = "disable" ] && systemctl disable "$SERVICE_NAME" && \
            whiptail --title "完成" --msgbox "已取消开机自启。" 8 40
    else
        current="未启用"
        ACTION=$(whiptail --title "开机自启" --menu "当前状态：$current" 12 50 2 \
            "enable" "设为开机自启" \
            "back"   "返回" \
            3>&1 1>&2 2>&3) || return
        [ "$ACTION" = "enable" ] && systemctl enable "$SERVICE_NAME" && \
            whiptail --title "完成" --msgbox "已设为开机自启。" 8 40
    fi
}

# ── 安装 ─────────────────────────────────────────────────────
menu_install() {
    require_root || return

    if [ -f "$BINARY" ]; then
        local ver
        ver=$("$BINARY" -v 2>/dev/null | grep -o 'v[0-9.]*' | head -1)
        if ! whiptail --title "已安装" --yesno "Mihomo $ver 已安装。\n是否重新安装（覆盖）？" 9 50; then
            return
        fi
    fi

    clear
    section "安装 Mihomo"

    info "获取最新版本..."
    LATEST=$(curl -s "$LATEST_VERSION_API" | grep '"tag_name"' | head -1 | grep -o 'v[0-9.]*')
    if [ -z "$LATEST" ]; then
        error "无法获取版本信息"
        echo ""
        warn "服务器可能无法访问 GitHub，请手动安装："
        echo ""
        echo "  1. 在有代理的机器上执行："
        echo "     curl -L -o /tmp/mihomo.gz 'https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-linux-amd64.gz'"
        echo "     gunzip /tmp/mihomo.gz"
        echo "     scp /tmp/mihomo-linux-amd64 服务器:/usr/local/bin/mihomo"
        echo ""
        echo "  2. 然后重新运行此脚本选择「安装」"
        pause
        return
    fi

    info "最新版本: $LATEST"

    ARCH=$(uname -m)
    case $ARCH in
        x86_64)  ARCH_NAME="amd64" ;;
        aarch64) ARCH_NAME="arm64" ;;
        armv7l)  ARCH_NAME="armv7" ;;
        *) error "不支持的架构: $ARCH"; pause; return ;;
    esac

    DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/${LATEST}/mihomo-linux-${ARCH_NAME}-${LATEST}.gz"
    info "下载 $DOWNLOAD_URL ..."

    TMP_GZ=$(mktemp /tmp/mihomo-XXXXXX.gz)
    if curl -L -o "$TMP_GZ" "$DOWNLOAD_URL" --progress-bar; then
        info "解压安装..."
        gunzip -f "$TMP_GZ"
        TMP_BIN="${TMP_GZ%.gz}"
        mv "$TMP_BIN" "$BINARY"
        chmod +x "$BINARY"
        rm -f "$TMP_GZ" 2>/dev/null || true
        info "Mihomo $LATEST 安装成功"
    else
        rm -f "$TMP_GZ" 2>/dev/null || true
        error "下载失败（服务器可能无法访问 GitHub）"
        echo ""
        warn "请在本机执行以下命令后重试："
        echo "  curl -L -o /tmp/mihomo.gz 'https://github.com/MetaCubeX/mihomo/releases/download/${LATEST}/mihomo-linux-${ARCH_NAME}-${LATEST}.gz'"
        echo "  gunzip /tmp/mihomo.gz"
        echo "  scp /tmp/mihomo-linux-${ARCH_NAME} 服务器:/usr/local/bin/mihomo"
        pause
        return
    fi

    mkdir -p "$CONFIG_DIR/ruleset"
    _install_geodata
    _install_service
    _install_alias

    info "安装完成！"
    pause
}

_install_alias() {
    ln -sf "$SCRIPT_PATH" /usr/local/bin/mm
    info "已创建快捷命令 mm（等同于 mihomo-manager）"
}

_install_geodata() {
    info "下载 GeoIP 数据库..."
    curl -sL -o "$CONFIG_DIR/Country.mmdb" \
        "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/country.mmdb" \
        && info "Country.mmdb 下载成功" \
        || warn "Country.mmdb 下载失败，可手动放到 $CONFIG_DIR/Country.mmdb"

    curl -sL -o "$CONFIG_DIR/ASN.mmdb" \
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

# ── 配置 ─────────────────────────────────────────────────────
menu_config() {
    local CHOICE
    CHOICE=$(whiptail --title "配置文件管理" \
        --menu "配置文件位置：$CONFIG_FILE" 16 60 4 \
        "1" "查看当前配置信息" \
        "2" "从路径导入配置文件" \
        "3" "显示目录结构说明" \
        "0" "返回" \
        3>&1 1>&2 2>&3) || return

    case "$CHOICE" in
        1) _config_show ;;
        2) _config_import ;;
        3) _config_tree ;;
    esac
}

_config_show() {
    clear
    section "当前配置信息"
    echo -e "  配置文件: ${BOLD}$CONFIG_FILE${NC}"
    echo ""
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "  ${CYAN}混合端口:${NC}   $(grep 'mixed-port' "$CONFIG_FILE" | awk '{print $2}')"
        echo -e "  ${CYAN}控制面板:${NC}   $(grep 'external-controller' "$CONFIG_FILE" | awk '{print $2}')"
        echo -e "  ${CYAN}代理模式:${NC}   $(grep '^mode:' "$CONFIG_FILE" | awk '{print $2}')"
        echo -e "  ${CYAN}TUN 模式:${NC}   $(grep -A2 '^tun:' "$CONFIG_FILE" | grep 'enable' | awk '{print $2}')"
        echo -e "  ${CYAN}DNS 模式:${NC}   $(grep 'enhanced-mode' "$CONFIG_FILE" | awk '{print $2}')"
        echo ""
        echo -e "  代理节点："
        grep '  - name:' "$CONFIG_FILE" | sed 's/  - name:/    •/'
        echo ""
        echo -e "  策略组："
        grep -A1 'proxy-groups:' "$CONFIG_FILE" | grep 'name:' | sed 's/.*name:/    •/'
    else
        warn "配置文件不存在"
    fi
    pause
}

_config_import() {
    require_root || return
    local SRC
    SRC=$(whiptail --title "导入配置文件" \
        --inputbox "请输入配置文件的完整路径：" 9 60 \
        3>&1 1>&2 2>&3) || return

    clear
    section "导入配置"
    if [ -z "$SRC" ]; then
        error "路径不能为空"; pause; return
    fi
    if [ ! -f "$SRC" ]; then
        error "文件不存在: $SRC"; pause; return
    fi

    cp "$SRC" "$CONFIG_FILE"
    info "配置已导入到 $CONFIG_FILE"

    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        echo ""
        if whiptail --title "重启服务" --yesno "服务正在运行，是否立即重启以应用新配置？" 8 50 3>&1 1>&2 2>&3; then
            systemctl restart "$SERVICE_NAME" && info "服务已重启" || error "重启失败"
        fi
    fi
    pause
}

_config_tree() {
    whiptail --title "目录结构" --msgbox \
"配置目录：$CONFIG_DIR/
├── config.yaml     ← 主配置文件（放这里）
├── Country.mmdb    ← GeoIP 数据库
├── ASN.mmdb        ← ASN 数据库
└── ruleset/        ← 规则集缓存

从本机 scp 上传配置：
  scp /本机/config.yaml 服务器:$CONFIG_FILE

控制面板（在浏览器访问）：
  http://服务器IP:9090" 18 60
}

# ── 更新 ─────────────────────────────────────────────────────
menu_update() {
    require_root || return
    clear
    section "检查更新"

    local CURRENT LATEST
    CURRENT=$("$BINARY" -v 2>/dev/null | grep -o 'v[0-9.]*' | head -1 || echo "未安装")
    info "当前版本: $CURRENT"
    info "正在检查最新版本..."
    LATEST=$(curl -s "$LATEST_VERSION_API" | grep '"tag_name"' | head -1 | grep -o 'v[0-9.]*')

    if [ -z "$LATEST" ]; then
        error "无法获取版本信息"; pause; return
    fi

    info "最新版本: $LATEST"

    if [ "$CURRENT" = "$LATEST" ]; then
        echo ""
        info "已是最新版本，无需更新"
        pause
        return
    fi

    echo ""
    if whiptail --title "发现新版本" --yesno "当前: $CURRENT\n最新: $LATEST\n\n是否立即更新？" 10 45 3>&1 1>&2 2>&3; then
        systemctl stop "$SERVICE_NAME" 2>/dev/null || true
        menu_install
        systemctl start "$SERVICE_NAME" 2>/dev/null || true
    fi
}

# ── 测试 ─────────────────────────────────────────────────────
menu_test() {
    clear
    section "网络连通性测试"
    MIXED_PORT=$(grep 'mixed-port' "$CONFIG_FILE" 2>/dev/null | awk '{print $2}' || echo "7890")

    _test_url() {
        local name="$1" url="$2" proxy="$3"
        printf "  %-28s" "$name"
        local code
        if [ -n "$proxy" ]; then
            code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" --proxy "$proxy" "$url" 2>/dev/null)
        else
            code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
        fi
        if [ "$code" -ge 200 ] && [ "$code" -lt 400 ] 2>/dev/null; then
            echo -e "${GREEN}✓ OK ($code)${NC}"
        else
            echo -e "${RED}✗ 失败 ($code)${NC}"
        fi
    }

    echo -e "  ${CYAN}[ TUN 透明代理 ]${NC}"
    _test_url "Google"          "https://www.google.com"
    _test_url "YouTube"         "https://www.youtube.com"
    _test_url "GitHub"          "https://github.com"
    _test_url "Twitter / X"     "https://twitter.com"
    _test_url "Baidu"           "https://www.baidu.com"

    echo ""
    echo -e "  ${CYAN}[ HTTP 代理 端口 $MIXED_PORT ]${NC}"
    _test_url "Google (proxy)"  "https://www.google.com"  "http://127.0.0.1:$MIXED_PORT"
    _test_url "Baidu (proxy)"   "https://www.baidu.com"   "http://127.0.0.1:$MIXED_PORT"

    pause
}

# ── 日志 ─────────────────────────────────────────────────────
menu_log() {
    local CHOICE
    CHOICE=$(whiptail --title "查看日志" --menu "选择日志模式：" 12 50 3 \
        "1" "最近 50 条日志" \
        "2" "最近 100 条日志" \
        "3" "实时日志（Ctrl+C 退出）" \
        3>&1 1>&2 2>&3) || return

    clear
    case "$CHOICE" in
        1) section "最近 50 条日志"; journalctl -u "$SERVICE_NAME" --no-pager -n 50; pause ;;
        2) section "最近 100 条日志"; journalctl -u "$SERVICE_NAME" --no-pager -n 100; pause ;;
        3) section "实时日志（Ctrl+C 退出）"; journalctl -u "$SERVICE_NAME" -f ;;
    esac
}

# ── Tailscale 兼容 ───────────────────────────────────────────

# 检测当前是否已启用 Tailscale 兼容
_tailscale_enabled() {
    [ -f "$CONFIG_FILE" ] && grep -q 'tailscale0' "$CONFIG_FILE"
}

menu_tailscale() {
    require_root || return

    if _tailscale_enabled; then
        # 已启用，询问是否关闭
        local ts_ip
        ts_ip=$(ip addr show tailscale0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 || echo "未检测到")
        ACTION=$(whiptail --title "Tailscale 兼容" \
            --menu "当前状态：已启用\nTailscale IP：$ts_ip\n\n选择操作：" 14 60 2 \
            "disable" "关闭 Tailscale 兼容" \
            "info"    "查看兼容说明" \
            3>&1 1>&2 2>&3) || return
        case "$ACTION" in
            disable) _tailscale_disable ;;
            info)    _tailscale_info ;;
        esac
    else
        # 未启用，询问是否开启
        ACTION=$(whiptail --title "Tailscale 兼容" \
            --menu "当前状态：未启用\n\n启用后 Mihomo 将不干扰 Tailscale 流量。\n选择操作：" 14 60 2 \
            "enable" "启用 Tailscale 兼容" \
            "info"   "查看兼容说明" \
            3>&1 1>&2 2>&3) || return
        case "$ACTION" in
            enable) _tailscale_enable ;;
            info)   _tailscale_info ;;
        esac
    fi
}

_tailscale_enable() {
    clear
    section "启用 Tailscale 兼容"

    # 1. TUN exclude-interface
    if grep -q 'exclude-interface' "$CONFIG_FILE"; then
        # 已有 exclude-interface 块，确认 tailscale0 在不在
        if ! grep -q 'tailscale0' "$CONFIG_FILE"; then
            sed -i '/exclude-interface:/a\    - tailscale0' "$CONFIG_FILE"
            info "已在 exclude-interface 中添加 tailscale0"
        else
            info "exclude-interface 已包含 tailscale0，跳过"
        fi
    else
        # 在 tun 块的 dns-hijack 行前插入
        sed -i '/dns-hijack:/i\  exclude-interface:\n    - tailscale0' "$CONFIG_FILE"
        info "已添加 tun.exclude-interface: tailscale0"
    fi

    # 2. fake-ip-filter for *.ts.net
    if grep -q 'fake-ip-filter' "$CONFIG_FILE"; then
        if ! grep -q 'ts.net' "$CONFIG_FILE"; then
            sed -i "/fake-ip-filter:/a\    - '*.ts.net'" "$CONFIG_FILE"
            info "已在 fake-ip-filter 添加 *.ts.net"
        else
            info "fake-ip-filter 已包含 *.ts.net，跳过"
        fi
    else
        # 在 enhanced-mode 行后插入
        sed -i "/enhanced-mode:/a\  fake-ip-filter:\n    - '*.ts.net'" "$CONFIG_FILE"
        info "已添加 dns.fake-ip-filter: *.ts.net"
    fi

    # 3. 规则：在 GEOIP,LAN 前插入 Tailscale 规则
    if ! grep -q '100.64.0.0/10' "$CONFIG_FILE"; then
        sed -i '/- GEOIP,LAN,DIRECT/i\  - IP-CIDR,100.64.0.0/10,DIRECT,no-resolve\n  - IP-CIDR,100.100.100.100/32,DIRECT\n  - PROCESS-NAME,tailscaled,DIRECT' "$CONFIG_FILE"
        info "已添加 Tailscale IP 段直连规则"
    else
        info "Tailscale 规则已存在，跳过"
    fi

    # 4. 重启生效
    echo ""
    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        systemctl restart "$SERVICE_NAME" && info "Mihomo 已重启，配置生效" || error "重启失败"
    else
        warn "Mihomo 未运行，下次启动时生效"
    fi

    # 5. 检测 Tailscale 是否已安装
    if ! command -v tailscale >/dev/null 2>&1; then
        echo ""
        warn "未检测到 tailscale 命令，如需安装："
        echo "  curl -fsSL https://tailscale.com/install.sh | sh"
    else
        local ts_status
        ts_status=$(tailscale status 2>/dev/null | head -1 || echo "未知")
        info "Tailscale 状态: $ts_status"
    fi

    pause
}

_tailscale_disable() {
    clear
    section "关闭 Tailscale 兼容"

    # 删除 tailscale0 行
    sed -i '/tailscale0/d' "$CONFIG_FILE"
    info "已移除 tailscale0 排除规则"

    # 删除 exclude-interface 块（如果为空）
    sed -i '/exclude-interface:/{N;/exclude-interface:\s*$/d}' "$CONFIG_FILE" 2>/dev/null || true

    # 删除 *.ts.net
    sed -i "/'\*\.ts\.net'/d" "$CONFIG_FILE"
    info "已移除 *.ts.net fake-ip-filter"

    # 删除 Tailscale 规则
    sed -i '/100\.64\.0\.0\/10/d' "$CONFIG_FILE"
    sed -i '/100\.100\.100\.100/d' "$CONFIG_FILE"
    sed -i '/PROCESS-NAME,tailscaled/d' "$CONFIG_FILE"
    info "已移除 Tailscale IP 直连规则"

    echo ""
    if systemctl is-active "$SERVICE_NAME" >/dev/null 2>&1; then
        systemctl restart "$SERVICE_NAME" && info "Mihomo 已重启，配置生效" || error "重启失败"
    fi

    pause
}

_tailscale_info() {
    whiptail --title "Tailscale 兼容说明" --msgbox \
"Tailscale 与 Mihomo TUN 模式的冲突点：

1. TUN 路由冲突
   Mihomo auto-route 会劫持所有流量，
   包括 Tailscale 的 WireGuard 包。

2. Tailscale IP 段未绕过
   Tailscale 设备使用 100.64.0.0/10 段，
   不在 Mihomo 的 LAN 直连范围内。

3. DNS 冲突
   fake-ip 模式会拦截 *.ts.net 的解析，
   导致 MagicDNS 失效。

启用兼容后，脚本会自动修改配置：
  • tun.exclude-interface: tailscale0
  • dns.fake-ip-filter: *.ts.net
  • rules: 100.64.0.0/10 → DIRECT
  • rules: tailscaled 进程 → DIRECT" 22 58
}

# ── Tailscale 管理 ───────────────────────────────────────────
menu_tailscale_manage() {
    while true; do
        local ts_svc ts_conn ts_ip summary

        if command -v tailscale >/dev/null 2>&1; then
            if systemctl is-active tailscaled >/dev/null 2>&1; then
                ts_svc="运行中 ●"
            else
                ts_svc="已停止 ○"
            fi
            ts_ip=$(tailscale ip 2>/dev/null | head -1 || echo "未连接")
            if tailscale status >/dev/null 2>&1; then
                ts_conn="已连接"
            else
                ts_conn="未连接"
            fi
            summary="状态: $ts_svc  |  网络: $ts_conn  |  IP: $ts_ip"
        else
            summary="Tailscale 未安装"
        fi

        CHOICE=$(whiptail --title "Tailscale 管理" \
            --menu "$summary\n\n请选择操作：" 22 62 10 \
            "1" "查看状态与设备列表" \
            "2" "连接 Tailscale 网络" \
            "3" "断开 Tailscale 网络" \
            "4" "重启 tailscaled 服务" \
            "5" "─────────────────────" \
            "6" "安装 Tailscale" \
            "7" "卸载 Tailscale" \
            "0" "返回主菜单" \
            3>&1 1>&2 2>&3) || return

        case "$CHOICE" in
            1) _ts_status ;;
            2) _ts_up ;;
            3) _ts_down ;;
            4) _ts_restart ;;
            5) : ;;
            6) _ts_install ;;
            7) _ts_uninstall ;;
            0) return ;;
        esac
    done
}

_ts_check() {
    if ! command -v tailscale >/dev/null 2>&1; then
        whiptail --title "未安装" --msgbox "Tailscale 未安装。\n请先选择「安装 Tailscale」。" 8 45
        return 1
    fi
}

_ts_status() {
    _ts_check || return
    clear
    section "Tailscale 状态"

    # 服务状态
    if systemctl is-active tailscaled >/dev/null 2>&1; then
        echo -e "  服务状态:  ${GREEN}● 运行中${NC}"
    else
        echo -e "  服务状态:  ${RED}● 已停止${NC}"
    fi

    # 本机 IP
    local ts_ip
    ts_ip=$(tailscale ip 2>/dev/null | head -1 || echo "未获取")
    echo -e "  本机 IP:   ${CYAN}$ts_ip${NC}"

    # 网络连接状态
    echo ""
    echo -e "  ${BOLD}网络状态:${NC}"
    tailscale status 2>/dev/null || warn "未连接到 Tailscale 网络"

    pause
}

_ts_up() {
    _ts_check || return
    require_root || return

    # 询问是否需要 --accept-routes（子网路由）
    local EXTRA_ARGS=""
    if whiptail --title "连接选项" --yesno "是否接受其他节点共享的子网路由？\n（如果不确定，选否即可）" 9 55 3>&1 1>&2 2>&3; then
        EXTRA_ARGS="--accept-routes"
    fi

    clear
    section "连接 Tailscale 网络"

    # 检查是否已登录
    if ! tailscale status >/dev/null 2>&1; then
        warn "尚未登录，请复制下方链接到浏览器完成认证："
        echo ""
        # 直接输出所有内容（stdout + stderr），确保认证 URL 可见
        tailscale up $EXTRA_ARGS 2>&1
    else
        tailscale up $EXTRA_ARGS 2>&1 && info "已连接到 Tailscale 网络" || error "连接失败"
    fi

    echo ""
    local ts_ip
    ts_ip=$(tailscale ip 2>/dev/null | head -1 || echo "未获取")
    [ -n "$ts_ip" ] && info "本机 Tailscale IP: $ts_ip"

    pause
}

_ts_down() {
    _ts_check || return
    require_root || return

    if whiptail --title "确认断开" --yesno "确定要断开 Tailscale 网络连接吗？\n（tailscaled 服务仍会保持运行）" 9 55 3>&1 1>&2 2>&3; then
        clear
        section "断开 Tailscale 网络"
        tailscale down && info "已断开 Tailscale 网络" || error "断开失败"
        pause
    fi
}

_ts_restart() {
    require_root || return
    _ts_check || return
    clear
    section "重启 tailscaled 服务"
    systemctl restart tailscaled && info "tailscaled 已重启" || error "重启失败"
    sleep 1
    systemctl status tailscaled --no-pager | tail -5
    pause
}

_ts_install() {
    require_root || return
    if command -v tailscale >/dev/null 2>&1; then
        local ver
        ver=$(tailscale version 2>/dev/null | head -1)
        whiptail --title "已安装" --msgbox "Tailscale 已安装：$ver" 8 45
        return
    fi

    clear
    section "安装 Tailscale"
    info "正在下载并运行官方安装脚本..."
    echo ""
    if curl -fsSL https://tailscale.com/install.sh | sh; then
        echo ""
        info "Tailscale 安装成功！"
        echo ""
        info "版本: $(tailscale version 2>/dev/null | head -1)"
        echo ""
        warn "下一步：运行「连接 Tailscale 网络」完成认证登录"

        # 如果 Mihomo 兼容未启用，提示开启
        if ! _tailscale_enabled; then
            echo ""
            warn "检测到 Mihomo 兼容模式未启用"
            warn "建议返回主菜单开启「Tailscale 兼容」，避免与 Mihomo 冲突"
        fi
    else
        error "安装失败，请检查网络连接"
        echo ""
        warn "如果无法访问 tailscale.com，可在本机执行后手动安装 .deb 包"
    fi
    pause
}

_ts_uninstall() {
    require_root || return
    _ts_check || return

    if ! whiptail --title "确认卸载" --yesno "确定要卸载 Tailscale 吗？\n此操作将删除 tailscale 和 tailscaled。" 9 52 3>&1 1>&2 2>&3; then
        return
    fi

    clear
    section "卸载 Tailscale"
    tailscale down 2>/dev/null || true
    systemctl stop tailscaled 2>/dev/null || true

    if command -v apt >/dev/null 2>&1; then
        apt-get remove -y tailscale && info "已通过 apt 卸载 Tailscale"
    elif command -v yum >/dev/null 2>&1; then
        yum remove -y tailscale && info "已通过 yum 卸载 Tailscale"
    else
        rm -f /usr/bin/tailscale /usr/sbin/tailscaled
        rm -f /etc/systemd/system/tailscaled.service
        systemctl daemon-reload
        info "已手动删除 Tailscale 文件"
    fi

    # 如果 Mihomo 兼容已启用，提示可关闭
    if _tailscale_enabled; then
        echo ""
        warn "Tailscale 已卸载，建议返回主菜单关闭「Tailscale 兼容」模式"
    fi

    pause
}

# ── 卸载 ─────────────────────────────────────────────────────
menu_uninstall() {
    require_root || return

    local MODE
    MODE=$(whiptail --title "卸载 Mihomo" --menu \
        "请选择卸载方式：" 12 55 2 \
        "soft"  "卸载程序（保留配置文件）" \
        "purge" "完全卸载（删除程序+配置）" \
        3>&1 1>&2 2>&3) || return

    local msg="确认卸载 Mihomo 程序和服务？\n配置文件将被保留。"
    [ "$MODE" = "purge" ] && msg="确认完全卸载？\n程序、服务和配置文件将全部删除！"

    if ! whiptail --title "二次确认" --yesno "$msg" 10 55 3>&1 1>&2 2>&3; then
        return
    fi

    clear
    section "卸载 Mihomo"
    systemctl stop "$SERVICE_NAME" 2>/dev/null && info "服务已停止"
    systemctl disable "$SERVICE_NAME" 2>/dev/null && info "开机自启已取消"
    rm -f "$SERVICE_FILE" && systemctl daemon-reload
    rm -f "$BINARY" && info "二进制已删除"

    if [ "$MODE" = "purge" ]; then
        rm -rf "$CONFIG_DIR" && info "配置目录已删除"
    else
        warn "配置文件保留在 $CONFIG_DIR"
    fi

    info "卸载完成"
    pause
}

# ── 脚本自更新 ───────────────────────────────────────────────
menu_self_update() {
    require_root || return
    clear
    section "脚本自更新"

    info "当前版本: v$SCRIPT_VERSION"
    info "正在检查最新版本..."

    local LATEST_VER
    LATEST_VER=$(curl -fsSL --max-time 10 "$SCRIPT_VERSION_URL" 2>/dev/null | tr -d '[:space:]')

    if [ -z "$LATEST_VER" ]; then
        error "无法获取版本信息，请检查网络连接"
        pause
        return
    fi

    info "最新版本: v$LATEST_VER"

    if [ "$SCRIPT_VERSION" = "$LATEST_VER" ]; then
        echo ""
        info "已是最新版本，无需更新"
        pause
        return
    fi

    echo ""
    if ! whiptail --title "发现新版本" \
        --yesno "当前版本：v$SCRIPT_VERSION\n最新版本：v$LATEST_VER\n\n是否立即更新？" \
        10 45 3>&1 1>&2 2>&3; then
        return
    fi

    clear
    section "下载更新..."

    local TMP_SCRIPT
    TMP_SCRIPT=$(mktemp /tmp/mihomo-manager-XXXXXX.sh)

    if curl -fsSL --max-time 30 -o "$TMP_SCRIPT" "$SCRIPT_RAW_URL"; then
        # 验证下载的文件是合法脚本
        if ! bash -n "$TMP_SCRIPT" 2>/dev/null; then
            error "下载的文件校验失败，已中止更新"
            rm -f "$TMP_SCRIPT"
            pause
            return
        fi

        chmod +x "$TMP_SCRIPT"
        # 备份当前脚本
        cp "$SCRIPT_PATH" "${SCRIPT_PATH}.bak"
        info "已备份当前版本到 ${SCRIPT_PATH}.bak"

        # 替换脚本
        mv "$TMP_SCRIPT" "$SCRIPT_PATH"
        info "更新完成！当前版本 → v$LATEST_VER"
        echo ""
        warn "脚本已替换，即将重新启动..."
        sleep 2
        exec "$SCRIPT_PATH"
    else
        rm -f "$TMP_SCRIPT"
        error "下载失败，更新已中止"
        warn "可手动更新："
        echo "  curl -Lo $SCRIPT_PATH $SCRIPT_RAW_URL"
        pause
    fi
}

# ── 入口 ──────────────────────────────────────────────────────
# 支持直接传命令参数（兼容非交互使用）
if [ -n "$1" ]; then
    case "$1" in
        start)     require_root && systemctl start "$SERVICE_NAME" ;;
        stop)      require_root && systemctl stop "$SERVICE_NAME" ;;
        restart)   require_root && systemctl restart "$SERVICE_NAME" ;;
        status)    menu_status ;;
        test)      menu_test ;;
        log)       journalctl -u "$SERVICE_NAME" --no-pager -n "${2:-50}" ;;
        log-follow) journalctl -u "$SERVICE_NAME" -f ;;
        *) echo "用法: $(basename "$0") [start|stop|restart|status|test|log|log-follow]" ;;
    esac
else
    main_menu
fi
