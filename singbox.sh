#!/bin/bash

# 定义颜色
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

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

# 函数：检测已安装的 sing-box 版本
detect_singbox_version() {
    if command -v sing-box &> /dev/null; then
        SINGBOX_VERSION=$(sing-box version | grep -oP 'sing-box \K[^\s]+')
        SINGBOX_INSTALLED=true
        print_info "检测到已安装的 sing-box 版本: $SINGBOX_VERSION"
        
        # 检测安装方式
        if dpkg -l | grep -q "sing-box"; then
            INSTALL_METHOD="apt"
            print_info "安装方式: 通过 apt 包管理器安装"
        elif [ -f "/usr/local/bin/sing-box" ]; then
            INSTALL_METHOD="manual"
            print_info "安装方式: 手动安装"
        else
            INSTALL_METHOD="unknown"
            print_warning "无法确定安装方式"
        fi
    else
        SINGBOX_INSTALLED=false
        print_info "未检测到已安装的 sing-box"
    fi
}

# 函数：卸载 sing-box
uninstall_singbox() {
    print_info "开始卸载 sing-box..."
    
    # 停止并禁用 sing-box 服务
    if systemctl is-active --quiet sing-box; then
        print_info "停止 sing-box 服务..."
        systemctl stop sing-box
    fi
    
    if systemctl is-enabled --quiet sing-box; then
        print_info "禁用 sing-box 服务..."
        systemctl disable sing-box
    fi
    
    # 根据安装方式选择卸载方法
    case $INSTALL_METHOD in
        "apt")
            print_info "通过 apt 卸载 sing-box..."
            apt-get remove --purge sing-box sing-box-beta -y
            ;;
        "manual")
            print_info "手动删除 sing-box 文件..."
            # 删除二进制文件
            rm -f /usr/local/bin/sing-box
            # 删除配置目录
            rm -rf /etc/sing-box
            # 删除数据目录
            rm -rf /var/lib/sing-box
            ;;
        *)
            print_warning "未知安装方式，尝试通用卸载方法..."
            # 尝试通过包管理器卸载
            if dpkg -l | grep -q "sing-box"; then
                apt-get remove --purge sing-box sing-box-beta -y
            fi
            # 删除可能的手动安装文件
            rm -f /usr/local/bin/sing-box
            rm -rf /etc/sing-box
            rm -rf /var/lib/sing-box
            ;;
    esac
    
    # 删除 nftables-singbox 服务
    if [ -f "/etc/systemd/system/nftables-singbox.service" ]; then
        print_info "删除 nftables-singbox 服务..."
        systemctl stop nftables-singbox.service 2>/dev/null
        systemctl disable nftables-singbox.service 2>/dev/null
        rm -f /etc/systemd/system/nftables-singbox.service
        systemctl daemon-reload
        systemctl reset-failed
    fi
    
    # 删除可能的相关脚本
    for script_path in "/usr/local/bin/nftables-singbox.sh" "/etc/singbox/nftables.sh" "/opt/singbox/nftables.sh"; do
        if [ -f "$script_path" ]; then
            print_info "删除脚本文件: $script_path"
            rm -f "$script_path"
        fi
    done
    
    # 删除 sagernet 源
    if [ -f "/etc/apt/sources.list.d/sagernet.sources" ]; then
        print_info "删除 sagernet 源..."
        rm -f /etc/apt/sources.list.d/sagernet.sources
    fi
    
    # 删除 GPG 密钥
    if [ -f "/etc/apt/keyrings/sagernet.asc" ]; then
        print_info "删除 GPG 密钥..."
        rm -f /etc/apt/keyrings/sagernet.asc
    fi
    
    # 删除 sing-box 用户
    if id "sing-box" &>/dev/null; then
        print_info "删除 sing-box 用户..."
        userdel -r sing-box 2>/dev/null || print_warning "无法删除 sing-box 用户，可能仍有进程在使用"
    fi
    
    print_success "sing-box 卸载完成!"
}

# 函数：安装 sing-box
install_singbox() {
    # 添加官方 GPG 密钥和仓库
    sudo mkdir -p /etc/apt/keyrings
    sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
    sudo chmod a+r /etc/apt/keyrings/sagernet.asc
    echo "Types: deb
URIs: https://deb.sagernet.org/
Suites: *
Components: *
Enabled: yes
Signed-By: /etc/apt/keyrings/sagernet.asc
" | sudo tee /etc/apt/sources.list.d/sagernet.sources > /dev/null

    # 始终更新包列表
    print_info "正在更新包列表，请稍候..."
    sudo apt-get update -qq > /dev/null 2>&1

    # 选择安装稳定版或测试版
    while true; do
        read -rp "请选择安装版本(1: 稳定版, 2: 测试版): " version_choice
        case $version_choice in
            1)
                print_info "安装稳定版..."
                sudo apt-get install sing-box -yq > /dev/null 2>&1
                print_info "安装已完成"
                break
                ;;
            2)
                print_info "安装测试版..."
                sudo apt-get install sing-box-beta -yq > /dev/null 2>&1
                print_info "安装已完成"
                break
                ;;
            *)
                print_error "无效的选择，请输入 1 或 2。"
                ;;
        esac
    done

    if command -v sing-box &> /dev/null; then
        sing_box_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
        print_success "sing-box 安装成功，版本：$sing_box_version"
         
        # 自动创建 sing-box 用户并设置权限
        if ! id sing-box &>/dev/null; then
            print_info "正在创建 sing-box 系统用户..."
            sudo useradd --system --no-create-home --shell /usr/sbin/nologin sing-box
        fi
        print_info "正在设置 /var/lib/sing-box 和 /etc/sing-box 目录权限..."
        sudo mkdir -p /var/lib/sing-box
        sudo chown -R sing-box:sing-box /var/lib/sing-box
        sudo chown -R sing-box:sing-box /etc/sing-box
    else
        print_error "sing-box 安装失败，请检查日志或网络配置"
    fi
}

# 主函数
main() {
    # 检查是否以 root 权限运行
    if [ "$EUID" -ne 0 ]; then
        print_error "此脚本需要以 root 权限运行"
        exit 1
    fi
    
    # 检测已安装的 sing-box
    detect_singbox_version
    
    # 显示菜单
    echo "======================================"
    echo "          sing-box 管理脚本"
    echo "======================================"
    
    if [ "$SINGBOX_INSTALLED" = true ]; then
        echo "1. 重新安装 sing-box"
        echo "2. 卸载 sing-box"
        echo "3. 退出"
        read -p "请选择操作 [1-3]: " choice
        
        case $choice in
            1)
                uninstall_singbox
                install_singbox
                ;;
            2)
                uninstall_singbox
                ;;
            3)
                exit 0
                ;;
            *)
                print_error "无效的选择"
                exit 1
                ;;
        esac
    else
        echo "1. 安装 sing-box"
        echo "2. 退出"
        read -p "请选择操作 [1-2]: " choice
        
        case $choice in
            1)
                install_singbox
                ;;
            2)
                exit 0
                ;;
            *)
                print_error "无效的选择"
                exit 1
                ;;
        esac
    fi
}

# 执行主函数
main
