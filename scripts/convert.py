#!/usr/bin/env python3
"""
Sing-box规则集转换脚本
将JSON和LIST格式规则转换为SRS二进制格式
"""

import os
import json
import yaml
import requests
import subprocess
from pathlib import Path
from helpers import download_file, load_config

def convert_to_srs(json_path, output_path):
    """使用sing-box工具转换JSON到SRS格式"""
    try:
        result = subprocess.run([
            "sing-box", "rule-set", "compile",
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

def process_list_format(url, output_filename):
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
                
            # 根据内容类型创建规则（简单示例，实际需更复杂逻辑）
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
    success = convert_to_srs(temp_json_path, output_path)
    
    # 清理临时文件
    os.remove(temp_list_path)
    os.remove(temp_json_path)
    
    return success

def process_json_format(url, output_filename):
    """处理JSON格式规则文件"""
    print(f"Processing JSON format: {url}")
    
    # 下载JSON文件
    temp_json_path = f"/tmp/{output_filename}.json"
    if not download_file(url, temp_json_path):
        return False
    
    # 转换为SRS
    output_path = f"outputs/{output_filename}.srs"
    success = convert_to_srs(temp_json_path, output_path)
    
    # 清理临时文件
    os.remove(temp_json_path)
    
    return success

def main():
    """主函数"""
    # 创建输出目录
    os.makedirs("outputs", exist_ok=True)
    
    # 加载配置
    config = load_config("configs/rule_sources.json")
    
    # 下载sing-box工具
    sing_box_url = "https://github.com/SagerNet/sing-box/releases/download/v1.8.0/sing-box-1.8.0-linux-amd64.tar.gz"
    sing_box_path = download_file(sing_box_url, "/tmp/sing-box.tar.gz", extract=True)
    
    if not sing_box_path:
        print("Failed to download sing-box tool")
        return
    
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
            success = process_list_format(url, name)
        elif format_type == "json":
            success = process_json_format(url, name)
        else:
            print(f"Unknown format: {format_type}")
            continue
        
        if success:
            print(f"Successfully converted {name}")
        else:
            print(f"Failed to convert {name}")

if __name__ == "__main__":
    main()
