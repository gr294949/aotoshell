"""辅助函数"""
import os
import requests
import json
import tarfile
import platform
import re
import time
import shutil
import subprocess  
from urllib.parse import urljoin

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
    
    # 组合成sing-box发布包常见的格式
    return f"linux-{base_arch}"

def get_latest_stable_sing_box_release(arch):
    """
    通过GitHub API获取最新的稳定版（非预发布）sing-box版本号和下载链接。

    Args:
        arch (str): 系统架构字符串

    Returns:
        tuple: (latest_version, download_url) 或 (None, None)
    """
    api_url = "https://api.github.com/repos/SagerNet/sing-box/releases/latest"
    try:
        headers = {
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        response = requests.get(api_url, headers=headers, timeout=30)
        response.raise_for_status()
        release_info = response.json()

        # 确保不是预发布版本
        if release_info.get('prerelease', False):
            print("最新版本是预发布版本，正在查找上一个稳定版...")
            # 如果不是稳定版，则获取所有发布版本来查找最新的稳定版
            all_releases_url = "https://api.github.com/repos/SagerNet/sing-box/releases"
            all_response = requests.get(all_releases_url, headers=headers, timeout=30)
            all_response.raise_for_status()
            all_releases = all_response.json()
            
            for release in all_releases:
                if not release.get('prerelease', False) and not release.get('draft', False):
                    release_info = release
                    break
            else:
                print("未找到任何稳定版本。")
                return None, None

        latest_version = release_info['tag_name'].lstrip('v')
        print(f"找到最新稳定版: {latest_version}")

        # 构建预期的资产文件名
        expected_asset_name = f"sing-box-{latest_version}-{arch}.tar.gz"
        
        # 在资产中查找匹配的文件
        for asset in release_info.get('assets', []):
            asset_name = asset['name']
            if asset_name == expected_asset_name:
                download_url = asset['browser_download_url']
                print(f"找到匹配的资产: {asset_name}")
                return latest_version, download_url

        # 如果没有找到完全匹配的，尝试寻找包含架构名称的资产
        for asset in release_info.get('assets', []):
            asset_name = asset['name']
            if arch in asset_name and asset_name.endswith('.tar.gz'):
                download_url = asset['browser_download_url']
                print(f"找到兼容的资产: {asset_name}")
                return latest_version, download_url

        # 如果还是没找到，尝试构建默认的下载URL
        download_url = f"https://github.com/SagerNet/sing-box/releases/download/v{latest_version}/sing-box-{latest_version}-{arch}.tar.gz"
        print(f"未找到完全匹配的资产，使用构建的URL: {download_url}")
        return latest_version, download_url

    except requests.exceptions.RequestException as e:
        print(f"请求GitHub API失败: {str(e)}")
    except Exception as e:
        print(f"解析发布信息时发生错误: {str(e)}")
    
    # 如果所有尝试都失败，回退到已知的稳定版本
    print("使用回退版本: 1.12.4")
    return "1.12.4", f"https://github.com/SagerNet/sing-box/releases/download/v1.12.4/sing-box-1.12.4-{arch}.tar.gz"

def download_file(url, destination, extract=False, max_retries=3):
    """下载文件（可选解压），增加重试机制和超时"""
    for attempt in range(max_retries):
        try:
            print(f"尝试下载 ({attempt + 1}/{max_retries}): {url}")
            response = requests.get(url, stream=True, timeout=60)
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
            tar.extractall(path=extract_dir)
        
        # 寻找可执行文件
        for file in os.listdir(extract_dir):
            if file == 'sing-box':
                full_path = os.path.join(extract_dir, file)
                if os.path.isfile(full_path):
                    return full_path

        # 如果在子目录中
        for root, dirs, files in os.walk(extract_dir):
            for file in files:
                if file == 'sing-box':
                    full_path = os.path.join(root, file)
                    if os.path.isfile(full_path):
                        return full_path
        
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
        result = subprocess.run(["sing-box", "version"], 
                              capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            print("使用系统已安装的 sing-box")
            return "sing-box"
    except FileNotFoundError:
        pass
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

if __name__ == "__main__":
    arch = get_system_architecture()
    version, url = get_latest_stable_sing_box_release(arch)
    print(f"系统架构: {arch}")
    print(f"最新稳定版本: {version}")
    print(f"下载URL: {url}")
