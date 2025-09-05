# 🚀 Sing-box规则集转换自动化仓库
下面我将为你创建一个完整的GitHub仓库方案，使用GitHub Actions自动将sing-box的JSON和LIST格式分流规则转换为高性能的SRS二进制格式。

## 功能特点

- 🔄 自动转换JSON和LIST格式规则为SRS二进制格式
- ⏰ 支持定时自动更新（每周一次）
- 🏷️ 支持版本标签自动发布
- 🔧 易于配置自定义规则源
- 📦 完全自动化，无需手动干预

## 使用方法

1. **Fork本仓库**
2. **配置规则源**

   编辑 `configs/rule_sources.json` 文件，添加你的规则源：
   ```json
   {
     "rulesets": [
       {
         "name": "my-rules",
         "url": "https://example.com/rules.json",
         "format": "json"
       }
     ]
   }
4. **手动运行工作流**

   进入仓库的 Actions 标签页
   选择 Convert Sing-box Rulesets 工作流
   点击 Run workflow 触发手动转换

6. **获取生成的SRS文件**

   在工作流运行完成后，在 Artifacts 部分下载生成的SRS文件
   或创建GitHub Release标签自动打包发布  
## 📁 仓库文件结构

sing-box-rule-converter/

├── .github/

│   └── workflows/

│       └── convert-rulesets.yml     # GitHub Actions工作流

├── scripts/

│   ├── convert.py                   # 主要转换脚本

│   └── helpers.py                   # 辅助函数

├── configs/

│   └── rule_sources.json            # 规则源定义文件

├── outputs/                         # 转换后的SRS文件(自动生成)

├── .gitignore

├── LICENSE

└── README.md

## ⚙️ GitHub Actions工作流

创建 .github/workflows/convert-rulesets.yml 文件

## 🐍 Python转换脚本

创建 scripts/convert.py 文件

## 🔧 辅助脚本

创建 scripts/helpers.py 文件

## 📋 规则源配置

创建 configs/rule_sources.json 文件
