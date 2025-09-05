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
3. **手动运行工作流**

   进入仓库的 Actions 标签页
   选择 Convert Sing-box Rulesets 工作流
   点击 Run workflow 触发手动转换

4. **获取生成的SRS文件**

   在工作流运行完成后，在 Artifacts 部分下载生成的SRS文件
   或创建GitHub Release标签自动打包发布  
## 配置选项

   规则源格式
   {
    "name": "规则集名称（输出文件名）",
    "url": "规则源URL",
    "format": "格式类型（json/list/auto）"
   }
## 工作流触发条件
   
   手动触发: 通过GitHub UI手动运行
   
   定时任务: 每周一UTC时间00:00自动运行
   
   配置变更: 当规则源配置文件更改时自动触发
## 文件说明
  .github/workflows/convert-rulesets.yml - GitHub Actions工作流定义

  scripts/convert.py - 主要转换脚本

  scripts/helpers.py - 辅助函数

  configs/rule_sources.json - 规则源配置

  outputs/ - 生成的SRS文件目录

## 注意事项
   
   确保规则源URL可公开访问

   List格式规则支持常见格式（DOMAIN, DOMAIN-SUFFIX, IP-CIDR）

   大型规则集转换可能需要较长时间（最多5分钟）

   生成的SRS文件与sing-box 1.8.0+版本兼容

## 常见问题
   **转换失败怎么办？**
   
   检查规则源URL是否可访问

   确认规则格式配置正确

   查看Actions日志获取详细错误信息

   **如何添加新规则源？**
   
   编辑 configs/rule_sources.json

   添加新的规则源配置

   提交更改将自动触发转换

## 贡献
   
   欢迎提交Issue和Pull Request来改进本项目！




