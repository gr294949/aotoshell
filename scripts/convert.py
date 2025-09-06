#!/usr/bin/env python3
"""
Sing-box规则集转换脚本
自动检测最新稳定版本并下载合适的sing-box二进制文件
"""

import os
import json
import subprocess
import sys
from helpers import (
    get_system_architecture,
    get_latest_stable_sing_box_release,  # 函数名变更
    download_file,
    check_sing_box_installed,
    load_config
)

def setup_sing_box():
    """设置并返回sing-box工具路径"""
    installed_path = check_sing_box_installed()
    if installed_path:
        return installed_path
    
    system_arch = get_system_architecture()
    print(f"系统架构: {system_arch}")
    
    # 使用新的函数名
    latest_version, download_url = get_latest_stable_sing_box_release(system_arch)
    if not latest_version or not download_url:
        print("获取sing-box最新稳定版本信息失败")
        latest_version = "1.12.4"
        download_url = f"https://github.com/SagerNet/sing-box/releases/download/v{latest_version}/sing-box-{latest_version}-{system_arch}.tar.gz"
        print(f"使用降级版本: {latest_version}")
    
    print(f"目标sing-box稳定版本: {latest_version}")
    print(f"下载地址: {download_url}")
    
    sing_box_filename = f"sing-box-{latest_version}-{system_arch}"
    sing_box_path = download_file(download_url, f"/tmp/{sing_box_filename}.tar.gz", extract=True)
    
    if not sing_box_path:
        print("主下载源失败，尝试备用镜像...")
        alt_download_url = f"https://github.loohps.com/https://github.com/SagerNet/sing-box/releases/download/v{latest_version}/sing-box-{latest_version}-{system_arch}.tar.gz"
        sing_box_path = download_file(alt_download_url, f"/tmp/{sing_box_filename}_alt.tar.gz", extract=True)
    
    if sing_box_path:
        os.chmod(sing_box_path, 0o755)
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
    
    temp_list_path = f"/tmp/{output_filename}.list"
    if not download_file(url, temp_list_path):
        return False
    
    json_rules = {"version": 1, "rules": []}
    
    with open(temp_list_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
                
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
                if '.' in line and '/' not in line:
                    rule["domain_suffix"] = [line]
                elif '/' in line:
                    rule["ip_cidr"] = [line]
            
            json_rules["rules"].append(rule)
    
    temp_json_path = f"/tmp/{output_filename}.json"
    with open(temp_json_path, 'w') as f:
        json.dump(json_rules, f, indent=2)
    
    output_path = f"outputs/{output_filename}.srs"
    success = convert_to_srs(temp_json_path, output_path, sing_box_path)
    
    if os.path.exists(temp_list_path):
        os.remove(temp_list_path)
    if os.path.exists(temp_json_path):
        os.remove(temp_json_path)
    
    return success

def process_json_format(url, output_filename, sing_box_path):
    """处理JSON格式规则文件"""
    print(f"Processing JSON format: {url}")
    
    temp_json_path = f"/tmp/{output_filename}.json"
    if not download_file(url, temp_json_path):
        return False
    
    output_path = f"outputs/{output_filename}.srs"
    success = convert_to_srs(temp_json_path, output_path, sing_box_path)
    
    if os.path.exists(temp_json_path):
        os.remove(temp_json_path)
    
    return success

def main():
    """主函数"""
    os.makedirs("outputs", exist_ok=True)
    
    sing_box_path = setup_sing_box()
    if not sing_box_path:
        print("Failed to setup sing-box tool")
        return 1
    
    config = load_config("configs/rule_sources.json")
    
    success_count = 0
    for ruleset in config["rulesets"]:
        url = ruleset["url"]
        name = ruleset["name"]
        format_type = ruleset.get("format", "auto")
        
        print(f"\nProcessing {name} from {url}")
        
        if format_type == "auto":
            if url.endswith('.list') or url.endswith('.txt'):
                format_type = "list"
            elif url.endswith('.json'):
                format_type = "json"
        
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
            success_count += 1
        else:
            print(f"Failed to convert {name}")
    
    print(f"\n转换完成: {success_count}/{len(config['rulesets'])} 个规则集成功转换")
    return 0 if success_count > 0 else 1

if __name__ == "__main__":
    sys.exit(main())
