#!/bin/bash

# ==============================================
# sing-box 增强版管理脚本
# 版本: 2.0
# 作者: gr294949
# GitHub: https://github.com/gr294949/sing-box-rule-converter
# 功能: 安装/卸载/更新 sing-box，配置透明网关
# ==============================================

# 定义颜色代码
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 脚本配置
SCRIPT_VERSION="2.0"
SCRIPT_URL="https://raw.githubusercontent.com/gr294949/sing-box-rule-converter/main/singbox-manager.sh"
CONFIG_DIR="/etc/sing-box"
SERVICE_FILE="/etc/systemd/system/sing-box.service"
BINARY_PATH="/usr/local/bin/sing-box"

# 函数：打印带颜色的消息
print_info() {
    echo -e "${CYAN}[信息]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# 函数：检查网络连接
check_network() {
    if ! curl -Is https://github.com | head -n 1 > /dev/null; then
        print_error "网络连接失败，请检查网络设置"
        return 1
    fi
    return 0
}

# 函数：检查并更新脚本
update_script() {
    print_header "检查脚本更新..."
    
    if ! check_network; then
        print_warning "无法检查更新，网络连接失败"
        return 1
    fi
    
    local remote_version
    remote_version=$(curl -fsL "$SCRIPT_URL" | grep -m 1 "SCRIPT_VERSION=" | cut -d'"' -f2)
    
    if [ -z "$remote_version" ]; then
        print_warning "无法获取远程版本信息"
        return 1
    fi
    
    if [ "$SCRIPT_VERSION" != "$remote_version" ]; then
        print_info "发现新版本: $remote_version (当前: $SCRIPT_VERSION)"
        read -p "是否更新脚本? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "正在更新脚本..."
            curl -fsL "$SCRIPT_URL" -o "$0"
            chmod +x "$0"
            print_success "脚本已更新到版本 $remote_version"
            print_info "请重新运行脚本"
            exit 0
        fi
    else
        print_info "脚本已是最新版本 ($SCRIPT_VERSION)"
    fi
}

# 函数：检测已安装的 sing-box 版本
detect_singbox() {
    if command -v sing-box &> /dev/null || [ -f "$BINARY_PATH" ]; then
        if [ -f "$BINARY_PATH" ]; then
            SINGBOX_VERSION=$("$BINARY_PATH" version 2>/dev/null | grep -oP 'sing-box \K[^\s]+' || echo "未知版本")
        else
            SINGBOX_VERSION=$(sing-box version 2>/dev/null | grep -oP 'sing-box \K[^\s]+' || echo "未知版本")
        fi
        SINGBOX_INSTALLED=true
        
        # 检测安装方式
        if dpkg -l | grep -q "sing-box"; then
            INSTALL_METHOD="apt"
        elif [ -f "$BINARY_PATH" ] || [ -f "/usr/local/bin/sing-box" ]; then
            INSTALL_METHOD="manual"
        else
            INSTALL_METHOD="unknown"
        fi
        return 0
    else
        SINGBOX_INSTALLED=false
        INSTALL_METHOD="none"
        return 1
    fi
}

# 函数：显示系统信息
show_system_info() {
    print_header "===== 系统信息 ====="
    echo "操作系统: $(lsb_release -d | cut -f2 2>/dev/null || uname -s)"
    echo "内核版本: $(uname -r)"
    echo "系统架构: $(uname -m)"
    echo "主机名: $(hostname)"
    echo "当前用户: $(whoami)"
    echo "当前时间: $(date)"
    echo ""
}

# 函数：显示 sing-box 状态
show_singbox_status() {
    print_header "===== sing-box 状态 ====="
    
    if detect_singbox; then
        echo -e "状态: ${GREEN}已安装${NC}"
        echo "版本: $SINGBOX_VERSION"
        echo "安装方式: $INSTALL_METHOD"
        
        if [ -f "$BINARY_PATH" ]; then
            echo "路径: $BINARY_PATH"
        else
            echo "路径: $(which sing-box)"
        fi
        
        # 检查服务状态
        if systemctl is-active sing-box --quiet 2>/dev/null; then
            echo -e "服务状态: ${GREEN}运行中${NC}"
        else
            echo -e "服务状态: ${RED}未运行${NC}"
        fi
        
        if systemctl is-enabled sing-box --quiet 2>/dev/null; then
            echo -e "开机启动: ${GREEN}已启用${NC}"
        else
            echo -e "开机启动: ${RED}未启用${NC}"
        fi
    else
        echo -e "状态: ${RED}未安装${NC}"
    fi
    echo ""
}

# 函数：自动设置权限
set_permissions() {
    print_info "设置文件和目录权限..."
    
    # 创建 sing-box 用户
    if ! id sing-box &>/dev/null; then
        useradd --system --no-create-home --shell /usr/sbin/nologin sing-box
    fi
    
    # 创建必要的目录
    mkdir -p "$CONFIG_DIR" /var/lib/sing-box
    
    # 设置目录权限
    chown -R sing-box:sing-box "$CONFIG_DIR" /var/lib/sing-box
    chmod 755 "$CONFIG_DIR" /var/lib/sing-box
    
    # 设置二进制文件权限
    if [ -f "$BINARY_PATH" ]; then
        chown sing-box:sing-box "$BINARY_PATH"
        chmod 755 "$BINARY_PATH"
    fi
    
    print_success "权限设置完成"
}

# 函数：下载最新版 sing-box
download_singbox() {
    print_header "下载 sing-box..."
    
    local api_url="https://api.github.com/repos/SagerNet/sing-box/releases/latest"
    local download_url
    
    # 获取最新版本下载链接
    if [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then
        download_url=$(curl -s $api_url | grep -o "https://.*linux-arm64.*tar.gz" | head -n 1)
    elif [ "$(uname -m)" = "x86_64" ]; then
        download_url=$(curl -s $api_url | grep -o "https://.*linux-amd64.*tar.gz" | head -n 1)
    else
        print_error "不支持的架构: $(uname -m)"
        return 1
    fi
    
    if [ -z "$download_url" ]; then
        print_error "无法获取下载链接"
        return 1
    fi
    
    print_info "下载地址: $download_url"
    
    # 创建临时目录
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # 下载并解压
    curl -fL "$download_url" -o "$temp_dir/sing-box.tar.gz"
    if [ $? -ne 0 ]; then
        print_error "下载失败"
        rm -rf "$temp_dir"
        return 1
    fi
    
    tar -xzf "$temp_dir/sing-box.tar.gz" -C "$temp_dir"
    
    # 查找可执行文件
    local binary_path
    binary_path=$(find "$temp_dir" -name "sing-box" -type f | head -n 1)
    
    if [ -z "$binary_path" ]; then
        print_error "未找到可执行文件"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 移动文件
    mv -f "$binary_path" "$BINARY_PATH"
    
    # 清理临时文件
    rm -rf "$temp_dir"
    
    print_success "sing-box 下载完成"
    return 0
}

# 函数：安装 sing-box
install_singbox() {
    print_header "开始安装 sing-box..."
    
    # 检查是否已安装
    if detect_singbox; then
        print_warning "sing-box 已安装，当前版本: $SINGBOX_VERSION"
        read -p "是否继续安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    # 选择安装方式
    print_info "请选择安装方式:"
    echo "1) 从 GitHub 下载最新版 (推荐)"
    echo "2) 从 APT 仓库安装"
    read -p "请输入选择 (1/2): " install_choice
    
    case $install_choice in
        1)
            # 从 GitHub 下载
            if ! download_singbox; then
                print_error "下载安装失败"
                return 1
            fi
            ;;
        2)
            # 从 APT 安装
            print_info "添加 GPG 密钥和软件源..."
            mkdir -p /etc/apt/keyrings
            curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
            chmod a+r /etc/apt/keyrings/sagernet.asc
            
            echo "Types: deb
URIs: https://deb.sagernet.org/
Suites: *
Components: *
Enabled: yes
Signed-By: /etc/apt/keyrings/sagernet.asc
" | tee /etc/apt/sources.list.d/sagernet.sources > /dev/null

            # 更新包列表
            print_info "更新软件包列表..."
            apt-get update -qq > /dev/null 2>&1

            # 选择安装版本
            print_info "请选择安装版本:"
            echo "1) 稳定版"
            echo "2) 测试版"
            read -p "请输入选择 (1/2): " version_choice
            
            case $version_choice in
                1)
                    print_info "安装稳定版..."
                    apt-get install sing-box -yq
                    ;;
                2)
                    print_info "安装测试版..."
                    apt-get install sing-box-beta -yq
                    ;;
                *)
                    print_error "无效选择，默认安装稳定版"
                    apt-get install sing-box -yq
                    ;;
            esac
            ;;
        *)
            print_error "无效选择"
            return 1
            ;;
    esac

    # 检查安装结果
    if detect_singbox; then
        print_success "sing-box 安装成功，版本: $SINGBOX_VERSION"
        
        # 设置权限
        set_permissions
        
        # 上传配置文件
        upload_config
        
        return 0
    else
        print_error "sing-box 安装失败"
        return 1
    fi
}

# 函数：上传配置文件
upload_config() {
    print_header "配置 sing-box..."
    
    # 创建配置目录
    mkdir -p "$CONFIG_DIR"
    
    print_info "请选择配置方式:"
    echo "1) 使用默认配置文件 (透明网关)"
    echo "2) 手动上传配置文件"
    read -p "请输入选择 (1/2): " config_choice
    
    case $config_choice in
        1)
            # 使用默认配置
            create_default_config
            ;;
        2)
            # 手动上传配置
            read -p "请输入配置文件路径: " config_path
            if [ -f "$config_path" ]; then
                cp "$config_path" "$CONFIG_DIR/config.json"
                print_success "配置文件已上传"
            else
                print_error "文件不存在: $config_path"
                return 1
            fi
            ;;
        *)
            print_error "无效选择，使用默认配置"
            create_default_config
            ;;
    esac
    
    # 设置配置文件权限
    chown sing-box:sing-box "$CONFIG_DIR/config.json"
    chmod 644 "$CONFIG_DIR/config.json"
    
    print_success "配置完成"
    return 0
}

# 函数：创建默认配置文件
create_default_config() {
    print_info "创建默认配置文件..."
    
    cat > "$CONFIG_DIR/config.json" << EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "google",
        "address": "tls://8.8.8.8",
        "detour": "direct"
      },
      {
        "tag": "local",
        "address": "local",
        "detour": "direct"
      }
    ],
    "rules": [
      {
        "outbound": "any",
        "server": "local"
      }
    ],
    "strategy": "ipv4_first"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "tun0",
      "mtu": 9000,
      "stack": "mixed",
      "endpoint_independent_nat": true,
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "ipv4_only",
      "inet4_address": "172.19.0.1/30",
      "auto_route": true,
      "strict_route": true
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      },
      {
        "ip_cidr": [
          "224.0.0.0/3",
          "ff00::/8"
        ],
        "outbound": "block"
      },
      {
        "geoip": [
          "private",
          "cn"
        ],
        "outbound": "direct"
      }
    ],
    "auto_detect_interface": true
  }
}
EOF

    print_success "默认配置文件已创建"
}

# 函数：配置透明网关
setup_transparent_gateway() {
    print_header "设置透明网关..."
    
    # 检查是否已安装 sing-box
    if ! detect_singbox; then
        print_error "请先安装 sing-box"
        return 1
    fi
    
    # 启用 IP 转发
    print_info "启用 IP 转发..."
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
    sysctl -p
    
    # 创建 nftables 规则
    print_info "创建 nftables 规则..."
    cat > /etc/nftables.singbox.rules << EOF
#!/usr/sbin/nft -f

flush ruleset

table inet sing-box {
    chain prerouting {
        type filter hook prerouting priority mangle; policy accept;
        meta mark 0x00000001 mark set 0x00000002
    }
    
    chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        meta mark 0x00000002 masquerade
    }
}
EOF
    
    # 应用 nftables 规则
    nft -f /etc/nftables.singbox.rules
    
    # 创建 systemd 服务
    print_info "创建 systemd 服务..."
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=sing-box
Group=sing-box
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=$BINARY_PATH run -c $CONFIG_DIR/config.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNPROC=512
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载 systemd
    systemctl daemon-reload
    
    # 启用并启动服务
    systemctl enable sing-box
    systemctl start sing-box
    
    print_success "透明网关设置完成"
    print_info "请将客户端网关设置为当前设备 IP 地址"
}

# 函数：卸载 sing-box
uninstall_singbox() {
    print_header "开始卸载 sing-box..."
    
    if ! detect_singbox; then
        print_warning "未检测到已安装的 sing-box"
        return 1
    fi
    
    # 确认卸载
    read -p "确定要卸载 sing-box? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "取消卸载"
        return 1
    fi
    
    # 停止并禁用服务
    print_info "停止服务..."
    systemctl stop sing-box 2>/dev/null
    systemctl disable sing-box 2>/dev/null
    
    # 根据安装方式卸载
    case $INSTALL_METHOD in
        "apt")
            print_info "通过 apt 卸载..."
            apt-get remove --purge sing-box sing-box-beta -y
            ;;
        "manual")
            print_info "手动卸载..."
            rm -f "$BINARY_PATH"
            rm -rf "$CONFIG_DIR" /var/lib/sing-box
            ;;
        *)
            print_warning "未知安装方式，尝试通用卸载..."
            apt-get remove --purge sing-box sing-box-beta -y 2>/dev/null
            rm -f "$BINARY_PATH"
            rm -rf "$CONFIG_DIR" /var/lib/sing-box
            ;;
    esac
    
    # 删除服务文件
    if [ -f "$SERVICE_FILE" ]; then
        rm -f "$SERVICE_FILE"
    fi
    
    # 删除 nftables 规则
    if [ -f "/etc/nftables.singbox.rules" ]; then
        rm -f /etc/nftables.singbox.rules
    fi
    
    # 删除软件源和密钥
    if [ -f "/etc/apt/sources.list.d/sagernet.sources" ]; then
        rm -f /etc/apt/sources.list.d/sagernet.sources
    fi
    
    if [ -f "/etc/apt/keyrings/sagernet.asc" ]; then
        rm -f /etc/apt/keyrings/sagernet.asc
    fi
    
    # 删除用户
    if id "sing-box" &>/dev/null; then
        userdel -r sing-box 2>/dev/null || userdel sing-box 2>/dev/null
    fi
    
    # 清理残留配置
    apt-get autoremove -y 2>/dev/null
    apt-get autoclean -y 2>/dev/null
    
    print_success "sing-box 已完全卸载"
    return 0
}

# 函数：管理 sing-box 服务
manage_service() {
    print_header "sing-box 服务管理"
    
    if ! detect_singbox; then
        print_error "请先安装 sing-box"
        return 1
    fi
    
    echo "请选择操作:"
    echo "1) 启动服务"
    echo "2) 停止服务"
    echo "3) 重启服务"
    echo "4) 查看服务状态"
    echo "5) 启用开机启动"
    echo "6) 禁用开机启动"
    echo "7) 查看服务日志"
    read -p "请输入选择 (1-7): " service_choice
    
    case $service_choice in
        1)
            systemctl start sing-box
            print_success "服务已启动"
            ;;
        2)
            systemctl stop sing-box
            print_success "服务已停止"
            ;;
        3)
            systemctl restart sing-box
            print_success "服务已重启"
            ;;
        4)
            systemctl status sing-box
            ;;
        5)
            systemctl enable sing-box
            print_success "已启用开机启动"
            ;;
        6)
            systemctl disable sing-box
            print_success "已禁用开机启动"
            ;;
        7)
            journalctl -u sing-box -f
            ;;
        *)
            print_error "无效选择"
            return 1
            ;;
    esac
    
    return 0
}

# 函数：显示主菜单
show_menu() {
    print_header "===== sing-box 管理脚本 ====="
    echo "1) 安装 sing-box"
    echo "2) 卸载 sing-box"
    echo "3) 服务管理"
    echo "4) 查看状态"
    echo "5) 设置透明网关"
    echo "6) 更新脚本"
    echo "7) 退出"
    echo ""
}

# 主函数
main() {
    # 检查 root 权限
    if [ "$EUID" -ne 0 ]; then
        print_error "此脚本需要以 root 权限运行"
        print_info "请使用 sudo 重新运行此脚本"
        exit 1
    fi
    
    # 检查更新
    update_script
    
    # 显示系统信息
    show_system_info
    
    # 检测 sing-box 状态
    detect_singbox
    show_singbox_status
    
    # 主循环
    while true; do
        show_menu
        read -p "请选择操作 (1-7): " choice
        
        case $choice in
            1)
                install_singbox
                ;;
            2)
                uninstall_singbox
                ;;
            3)
                manage_service
                ;;
            4)
                show_system_info
                show_singbox_status
                ;;
            5)
                setup_transparent_gateway
                ;;
            6)
                update_script
                ;;
            7)
                print_info "再见!"
                exit 0
                ;;
            *)
                print_error "无效选择，请重新输入"
                ;;
        esac
        
        echo ""
        read -p "按回车键继续..."
        echo ""
    done
}

# 执行主函数
main "$@"
