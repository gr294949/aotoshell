"""辅助函数"""
import os
import requests
import json
import tarfile

def download_file(url, destination, extract=False):
    """下载文件（可选解压）"""
    try:
        response = requests.get(url, stream=True, timeout=30)
        response.raise_for_status()
        
        with open(destination, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        if extract:
            # 处理压缩文件
            if destination.endswith('.tar.gz') or destination.endswith('.tgz'):
                with tarfile.open(destination, 'r:gz') as tar:
                    tar.extractall(path=os.path.dirname(destination))
                # 寻找可执行文件
                extract_dir = os.path.dirname(destination)
                for file in os.listdir(extract_dir):
                    if file.startswith('sing-box'):
                        full_path = os.path.join(extract_dir, file)
                        if os.path.isfile(full_path) and os.access(full_path, os.X_OK):
                            return full_path
            return None
        return destination
    except Exception as e:
        print(f"Error downloading {url}: {str(e)}")
        return None

def load_config(config_path):
    """加载配置文件"""
    try:
        with open(config_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading config {config_path}: {str(e)}")
        return {"rulesets": []}
