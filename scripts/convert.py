#!/usr/bin/env python3
"""
Sing-box规则集转换脚本
自动检测最新版本并下载合适的sing-box二进制文件
"""

import os
import json
import requests
import subprocess
import platform
import re
import time
import tarfile
import shutil
from pathlib import Path
from urllib.parse import urljoin

# ==================== 辅助函数 ====================

def get_system_architecture():
    """
    获取当前系统的架构信息，并映射到sing-box发布包使用的命名约定。
    
    Returns:
        str: 架构标识字符串 (e.g., 'linux-amd64', 'linux-arm64')
    """
    machine = platform.machine().lower()
    system = platform.system().lower()

    # 常见的架构映射表
    arch_map = {
        'x86_64': 'amd64',
        'amd64': 'amd64',
        'i386': '386',
        'i686': '386',
        'aarch64': 'arm64',
        'arm64': 'arm64',
        'armv7l': 'armv7',
        'armv6l': 'armv6'
    }

    # 获取基础架构，默认为'amd64'
    base_arch = arch_map.get(machine, 'amd64')
    
    # 组合成sing-box发布包常见的格式，例如 'linux-amd64'
    # GitHub Actions 运行器通常是 Linux
    return f"linux-{base_arch}"

def get_latest_sing_box_release(arch):
    """
    通过解析GitHub Releases页面获取最新的稳定版sing-box版本号和下载链接。
    优先选择非Pre-release版本。

    Args:
        arch (str): 系统架构字符串

    Returns:
        tuple: (latest_version, download_url) 或 (None, None)
    """
    releases_url = "https://github.com/SagerNet/sing-box/releases"
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        response = requests.get(releases_url, headers=headers, timeout=30)
        response.raise_for_status()
        
        # 使用正则表达式查找页面中所有的发布标签
        tag_pattern = r'releases/tag/(v?\d+\.\d+\.\d+)'
        tags = re.findall(tag_pattern, response.text)
        
        # 匹配资产下载链接 (匹配包含架构和.tar.gz的链接)
        asset_pattern = rf'href="([^"]+sing-box[^"]*{arch}[^"]*\.tar\.gz)"'
        asset_urls = re.findall(asset_pattern, response.text)
        asset_urls = [urljoin("https://github.com", url) for url in asset_urls]  # 转绝对URL

        if not tags:
            print("未在发布页面找到版本标签。")
            return None, None

        # 寻找稳定版（假设版本号格式为X.Y.Z）
        stable_versions = [tag for tag in tags if re.match(r'^\d+\.\d+\.\d+$', tag.lstrip('v'))]
        if stable_versions:
            # 排序并选择最新的稳定版
            latest_stable = sorted(stable_versions, key=lambda x: [int(num) for num in x.lstrip('v').split('.')])[-1]
            latest_version = latest_stable.lstrip('v')
            print(f"找到最新稳定版: {latest_version}")
        else:
            # 降级方案：使用已知的最新稳定版
            latest_version = "1.12.4"
            print(f"未找到稳定版，使用默认版本: {latest_version}")

        # 尝试寻找匹配的下载链接
        download_url = None
        expected_name = f"sing-box-{latest_version}-{arch}.tar.gz"
        for url in asset_urls:
            if expected_name in url:
                download_url = url
                break

        # 如果没找到，尝试构建默认URL
        if not download_url:
            download_url = f"https://github.com/SagerNet/sing-box/releases/download/v{latest_version}/sing-box-{latest_version}-{arch}.tar.gz"
            print(f"使用构建的URL: {download_url}")

        return latest_version, download_url

    except Exception as e:
        print(f"获取最新版本信息失败: {str(e)}")
        # 故障回退：返回一个已知可用的版本和URL
        return "1.12.4", f"https://github.com/SagerNet/sing-box/releases/download/v1.12.4/sing-box-1.12.4-{arch}.tar.gz"

def download_file(url, destination, extract=False, max_retries=3):
    """下载文件（可选解压），增加重试机制和超时"""
    for attempt in range(max_retries):
        try:
            print(f"尝试下载 ({attempt + 1}/{max_retries}): {url}")
            response = requests.get(url, stream=True, timeout=60)  # 增加超时
            response.raise_for_status()

            with open(destination, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)

            print(f"下载成功: {destination}")
            
            if extract:
                return extract_sing_box(destination)
            return destination

        except requests.exceptions.Timeout:
            print(f"下载超时 (尝试 {attempt + 1}/{max_retries})")
        except requests.exceptions.RequestException as e:
            print(f"下载请求错误 (尝试 {attempt + 1}/{max_retries}): {str(e)}")
        except Exception as e:
            print(f"下载过程中发生未知错误 (尝试 {attempt + 1}/{max_retries}): {str(e)}")

        # 等待后重试
        if attempt < max_retries - 1:
            wait_time = (attempt + 1) * 5
            print(f"{wait_time}秒后重试...")
            time.sleep(wait_time)

    print(f"下载失败: {url} (已达最大重试次数)")
    return None

def extract_sing_box(archive_path):
    """解压sing-box压缩包并返回可执行文件路径"""
    try:
        extract_dir = os.path.dirname(archive_path)
        
        with tarfile.open(archive_path, 'r:gz') as tar:
            # 安全提取：检查文件名是否在预期范围内
            safe_members = []
            for member in tar.getmembers():
                # 防止路径遍历攻击，确保文件提取到目标目录内
                member_path = os.path.join(extract_dir, member.name)
                if not os.path.realpath(member_path).startswith(os.path.realpath(extract_dir)):
                    continue
                safe_members.append(member)
            tar.extractall(path=extract_dir, members=safe_members)
        
        # 优先在当前目录寻找
        sing_box_candidate = os.path.join(extract_dir, 'sing-box')
        if os.path.isfile(sing_box_candidate):
            return sing_box_candidate

        # 如果在子目录中，寻找并移动出来
        for root, dirs, files in os.walk(extract_dir):
            for file in files:
                if file == 'sing-box':
                    found_path = os.path.join(root, file)
                    # 如果不在根目录，就移动到根目录
                    if root != extract_dir:
                        shutil.move(found_path, sing_box_candidate)
                        # 可选：删除空子目录
                        try:
                            os.rmdir(root)
                        except OSError:
                            pass  # 目录非空，忽略
                    return sing_box_candidate
        
        return None
    except tarfile.TarError as e:
        print(f"解压tar文件错误: {str(e)}")
        return None
    except Exception as e:
        print(f"解压过程中发生未知错误: {str(e)}")
        return None

def check_sing_box_installed():
    """检查系统是否已安装sing-box并返回路径"""
    try:
        # 尝试直接运行 sing-box version
        result = subprocess.run(["sing-box", "version"], 
                              capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            print("使用系统已安装的 sing-box")
            return "sing-box"
    except FileNotFoundError:
        pass  # 没找到是正常的
    except Exception as e:
        print(f"检查已安装sing-box时出错: {str(e)}")
    
    return None

def load_config(config_path):
    """加载配置文件"""
    try:
        with open(config_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading config {config_path}: {str(e)}")
        return {"rulesets": []}

# ==================== 主要功能函数 ====================

def setup_sing_box():
    """设置并返回sing-box工具路径"""
    # 首先检查是否已安装sing-box
    installed_path = check_sing_box_installed()
    if installed_path:
        return installed_path
    
    # 获取系统信息
    system_arch = get_system_architecture()
    print(f"系统架构: {system_arch}")
    
    # 获取最新版本信息
    latest_version, download_url = get_latest_sing_box_release(system_arch)
    if not latest_version or not download_url:
        print("获取sing-box最新版本信息失败")
        # 尝试使用一个已知的稳定版本和URL作为降级方案
        latest_version = "1.12.4"  # 使用用户提供的已知稳定版本
        download_url = f"https://github.com/SagerNet/sing-box/releases/download/v{latest_version}/sing-box-{latest_version}-{system_arch}.tar.gz"
        print(f"使用降级版本: {latest_version}")
    
    print(f"目标sing-box版本: {latest_version}")
    print(f"下载地址: {download_url}")
    
    # 下载sing-box
    sing_box_filename = f"sing-box-{latest_version}-{system_arch}"
    sing_box_path = download_file(download_url, f"/tmp/{sing_box_filename}.tar.gz", extract=True)
    
    # 如果主下载源失败，尝试备用下载源
    if not sing_box_path:
        print("主下载源失败，尝试备用镜像...")
        alt_download_url = f"https://github.loohps.com/https://github.com/SagerNet/sing-box/releases/download/v{latest_version}/sing-box-{latest_version}-{system_arch}.tar.gz"
        sing_box_path = download_file(alt_download_url, f"/tmp/{sing_box_filename}_alt.tar.gz", extract=True)
    
    if sing_box_path:
        # 设置执行权限
        os.chmod(sing_box_path, 0o755)
        # 验证版本
        try:
            result = subprocess.run([sing_box_path, "version"], capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                print(f"Sing-box 准备就绪: {sing_box_path}")
                print(f"版本信息: {result.stdout.strip()}")
                return sing_box_path
            else:
                print(f"Sing-box 版本验证失败: {result.stderr}")
        except Exception as e:
            print(f"验证sing-box版本时出错: {str(e)}")
    
    print("设置sing-box工具失败")
    return None

def convert_to_srs(json_path, output_path, sing_box_path):
    """使用sing-box工具转换JSON到SRS格式"""
    try:
        result = subprocess.run([
            sing_box_path, "rule-set", "compile",
            json_path, "-o", output_path
        ], capture_output=True, text=True, timeout=300)
        
        if result.returncode != 0:
            print(f"Error converting {json_path}: {result.stderr}")
            return False
            
        return True
    except subprocess.TimeoutExpired:
        print(f"Timeout converting {json_path}")
        return False
    except Exception as e:
        print(f"Exception converting {json_path}: {str(e)}")
        return False

def process_list_format(url, output_filename, sing_box_path):
    """处理LIST格式规则文件"""
    print(f"Processing LIST format: {url}")
    
    # 下载列表文件
    temp_list_path = f"/tmp/{output_filename}.list"
    if not download_file(url, temp_list_path):
        return False
    
    # 转换LIST为Sing-box JSON格式
    json_rules = {"version": 1, "rules": []}
    
    with open(temp_list_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
                
            # 根据内容类型创建规则
            rule = {"outbound": "block"}
            if line.startswith('DOMAIN,'):
                domain = line.split(',')[1]
                rule["domain"] = [domain]
            elif line.startswith('DOMAIN-SUFFIX,'):
                domain_suffix = line.split(',')[1]
                rule["domain_suffix"] = [domain_suffix]
            elif line.startswith('IP-CIDR,'):
                ip_cidr = line.split(',')[1]
                rule["ip_cidr"] = [ip_cidr]
            else:
                # 尝试自动检测类型
                if '.' in line and '/' not in line:
                    rule["domain_suffix"] = [line]
                elif '/' in line:
                    rule["ip_cidr"] = [line]
            
            json_rules["rules"].append(rule)
    
    # 保存临时JSON文件
    temp_json_path = f"/tmp/{output_filename}.json"
    with open(temp_json_path, 'w') as f:
        json.dump(json_rules, f, indent=2)
    
    # 转换为SRS
    output_path = f"outputs/{output_filename}.srs"
    success = convert_to_srs(temp_json_path, output_path, sing_box_path)
    
    # 清理临时文件
    if os.path.exists(temp_list_path):
        os.remove(temp_list_path)
    if os.path.exists(temp_json_path):
        os.remove(temp_json_path)
    
    return success

def process_json_format(url, output_filename, sing_box_path):
    """处理JSON格式规则文件"""
    print(f"Processing JSON format: {url}")
    
    # 下载JSON文件
    temp_json_path = f"/tmp/{output_filename}.json"
    if not download_file(url, temp_json_path):
        return False
    
    # 转换为SRS
    output_path = f"outputs/{output_filename}.srs"
    success = convert_to_srs(temp_json_path, output_path, sing_box_path)
    
    # 清理临时文件
    if os.path.exists(temp_json_path):
        os.remove(temp_json_path)
    
    return success

# ==================== 主函数 ====================

def main():
    """主函数"""
    # 创建输出目录
    os.makedirs("outputs", exist_ok=True)
    
    # 设置sing-box
    sing_box_path = setup_sing_box()
    if not sing_box_path:
        print("Failed to setup sing-box tool")
        return
    
    # 加载配置
    config = load_config("configs/rule_sources.json")
    
    # 处理所有规则集
    for ruleset in config["rulesets"]:
        url = ruleset["url"]
        name = ruleset["name"]
        format_type = ruleset.get("format", "auto")
        
        print(f"\nProcessing {name} from {url}")
        
        # 自动检测格式
        if format_type == "auto":
            if url.endswith('.list') or url.endswith('.txt'):
                format_type = "list"
            elif url.endswith('.json'):
                format_type = "json"
        
        # 根据格式处理
        success = False
        if format_type == "list":
            success = process_list_format(url, name, sing_box_path)
        elif format_type == "json":
            success = process_json_format(url, name, sing_box_path)
        else:
            print(f"Unknown format: {format_type}")
            continue
        
        if success:
            print(f"Successfully converted {name}")
        else:
            print(f"Failed to convert {name}")

if __name__ == "__main__":
    main()
