#!/bin/bash

# ==============================================
# sing-box 管理脚本
# 版本: 1.2
# 作者: autoShell
# GitHub: https://github.com/gr294949/aotoshell
# ==============================================

# 定义颜色代码
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# 函数：检测已安装的 sing-box 版本
detect_singbox() {
    if command -v sing-box &> /dev/null; then
        SINGBOX_VERSION=$(sing-box version 2>/dev/null | grep -oP 'sing-box \K[^\s]+' || echo "未知版本")
        SINGBOX_INSTALLED=true
        
        # 检测安装方式
        if dpkg -l | grep -q "sing-box"; then
            INSTALL_METHOD="apt"
        elif [ -f "/usr/local/bin/sing-box" ]; then
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
    echo "操作系统: $(lsb_release -d | cut -f2)"
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
        echo "路径: $(which sing-box)"
        
        # 检查服务状态
        if systemctl is-active sing-box --quiet; then
            echo -e "服务状态: ${GREEN}运行中${NC}"
        else
            echo -e "服务状态: ${RED}未运行${NC}"
        fi
        
        if systemctl is-enabled sing-box --quiet; then
            echo -e "开机启动: ${GREEN}已启用${NC}"
        else
            echo -e "开机启动: ${RED}未启用${NC}"
        fi
    else
        echo -e "状态: ${RED}未安装${NC}"
    fi
    echo ""
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
    
    # 添加官方 GPG 密钥和仓库
    print_info "添加 GPG 密钥和软件源..."
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

    # 更新包列表
    print_info "更新软件包列表..."
    sudo apt-get update -qq > /dev/null 2>&1

    # 选择安装版本
    print_info "请选择安装版本:"
    echo "1) 稳定版"
    echo "2) 测试版"
    read -p "请输入选择 (1/2): " version_choice
    
    case $version_choice in
        1)
            print_info "安装稳定版..."
            sudo apt-get install sing-box -yq
            ;;
        2)
            print_info "安装测试版..."
            sudo apt-get install sing-box-beta -yq
            ;;
        *)
            print_error "无效选择，默认安装稳定版"
            sudo apt-get install sing-box -yq
            ;;
    esac

    # 检查安装结果
    if detect_singbox; then
        print_success "sing-box 安装成功，版本: $SINGBOX_VERSION"
        
        # 创建系统用户和设置权限
        print_info "设置系统用户和权限..."
        if ! id sing-box &>/dev/null; then
            sudo useradd --system --no-create-home --shell /usr/sbin/nologin sing-box
        fi
        
        sudo mkdir -p /var/lib/sing-box /etc/sing-box
        sudo chown -R sing-box:sing-box /var/lib/sing-box /etc/sing-box
        
        return 0
    else
        print_error "sing-box 安装失败"
        return 1
    fi
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
    sudo systemctl stop sing-box 2>/dev/null
    sudo systemctl disable sing-box 2>/dev/null
    
    # 根据安装方式卸载
    case $INSTALL_METHOD in
        "apt")
            print_info "通过 apt 卸载..."
            sudo apt-get remove --purge sing-box sing-box-beta -y
            ;;
        "manual")
            print_info "手动卸载..."
            sudo rm -f /usr/local/bin/sing-box
            sudo rm -rf /etc/sing-box /var/lib/sing-box
            ;;
        *)
            print_warning "未知安装方式，尝试通用卸载..."
            sudo apt-get remove --purge sing-box sing-box-beta -y 2>/dev/null
            sudo rm -f /usr/local/bin/sing-box
            sudo rm -rf /etc/sing-box /var/lib/sing-box
            ;;
    esac
    
    # 删除 nftables-singbox 服务
    if [ -f "/etc/systemd/system/nftables-singbox.service" ]; then
        print_info "删除 nftables-singbox 服务..."
        sudo systemctl stop nftables-singbox.service 2>/dev/null
        sudo systemctl disable nftables-singbox.service 2>/dev/null
        sudo rm -f /etc/systemd/system/nftables-singbox.service
        sudo systemctl daemon-reload
        sudo systemctl reset-failed
    fi
    
    # 删除相关脚本
    print_info "清理相关文件..."
    for script_path in "/usr/local/bin/nftables-singbox.sh" "/etc/singbox/nftables.sh" "/opt/singbox/nftables.sh"; do
        if [ -f "$script_path" ]; then
            sudo rm -f "$script_path"
        fi
    done
    
    # 删除软件源和密钥
    if [ -f "/etc/apt/sources.list.d/sagernet.sources" ]; then
        sudo rm -f /etc/apt/sources.list.d/sagernet.sources
    fi
    
    if [ -f "/etc/apt/keyrings/sagernet.asc" ]; then
        sudo rm -f /etc/apt/keyrings/sagernet.asc
    fi
    
    # 删除用户
    if id "sing-box" &>/dev/null; then
        sudo userdel -r sing-box 2>/dev/null || sudo userdel sing-box 2>/dev/null
    fi
    
    # 清理残留配置
    sudo apt-get autoremove -y 2>/dev/null
    sudo apt-get autoclean -y 2>/dev/null
    
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
    read -p "请输入选择 (1-6): " service_choice
    
    case $service_choice in
        1)
            sudo systemctl start sing-box
            print_success "服务已启动"
            ;;
        2)
            sudo systemctl stop sing-box
            print_success "服务已停止"
            ;;
        3)
            sudo systemctl restart sing-box
            print_success "服务已重启"
            ;;
        4)
            systemctl status sing-box
            ;;
        5)
            sudo systemctl enable sing-box
            print_success "已启用开机启动"
            ;;
        6)
            sudo systemctl disable sing-box
            print_success "已禁用开机启动"
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
    echo "5) 退出"
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
    
    # 显示系统信息
    show_system_info
    
    # 检测 sing-box 状态
    detect_singbox
    show_singbox_status
    
    # 主循环
    while true; do
        show_menu
        read -p "请选择操作 (1-5): " choice
        
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
