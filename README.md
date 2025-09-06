# 🚀Sing-box 规则集自动转换工具

![GitHub Actions Workflow](https://img.shields.io/github/actions/workflow/status/gr294949/sing-box-rule-converter/convert-rulesets.yml?label=规则转换)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/gr294949/sing-box-rule-converter)
![GitHub](https://img.shields.io/github/license/gr294949/sing-box-rule-converter)

自动化将 JSON 和 LIST 格式的 sing-box 分流规则转换为高性能的 SRS 二进制格式，通过 GitHub Actions 实现完全自动化的规则集管理。

## ✨ 特性

- 🔄 **自动转换**: 将 JSON 和 LIST 格式规则自动编译为 SRS 二进制格式
- ⏰ **定时更新**: 支持每周自动更新规则集，确保规则最新
- 🏷️ **版本发布**: 自动创建 GitHub Release 并打包生成的文件
- 🛡️ **稳定可靠**: 多重回退机制和错误处理，确保流程稳定性
- 🔧 **易于配置**: 简单的配置文件管理所有规则源
- 📦 **多架构支持**: 自动检测系统架构并下载合适的 sing-box 版本

## 🚀 快速开始

### 前置要求

- GitHub 账户
- Fork 本仓库

### 安装步骤

1. **Fork 本仓库**
   - 点击右上角的 "Fork" 按钮，将仓库复制到你的账户

2. **配置规则源**
   - 编辑 `configs/rule_sources.json` 文件，添加你需要的规则源
   - 示例配置已包含常用规则源（GeoIP CN、Geosite CN 等）

3. **手动触发工作流**
   - 进入仓库的 **Actions** 标签页
   - 选择 **Convert Sing-box Rulesets** 工作流
   - 点击 **Run workflow** 触发手动转换

4. **获取生成的 SRS 文件**
   - 在工作流运行完成后，在 **Artifacts** 部分下载生成的 SRS 文件
   - 或创建 Git 标签自动打包发布到 Release

## ⚙️ 配置说明

### 规则源配置

编辑 `configs/rule_sources.json` 文件来管理你的规则源：

```json
{
  "rulesets": [
    {
      "name": "规则集名称（输出文件名）",
      "url": "规则源URL",
      "format": "格式类型（json/list/auto）"
    },
    {
      "name": "geoip-cn",
      "url": "https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-cn.json",
      "format": "json"
    },
    {
      "name": "geosite-cn",
      "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-cn.json",
      "format": "json"
    }
  ]
}
```

### 支持的类型

- **JSON 格式**: sing-box 原生规则集格式
- **LIST 格式**: 纯文本列表格式（支持 DOMAIN、DOMAIN-SUFFIX、IP-CIDR 等前缀）

## 📁 项目结构

```
sing-box-rule-converter/
├── .github/
│   └── workflows/
│       └── convert-rulesets.yml     # GitHub Actions 工作流定义
├── scripts/
│   ├── convert.py                   # 主要转换脚本
│   └── helpers.py                   # 辅助函数（下载、架构检测等）
├── configs/
│   └── rule_sources.json            # 规则源配置文件
├── outputs/                         # 生成的 SRS 文件目录
├── .gitignore
├── LICENSE
└── README.md
```

## 🔧 工作流详情

### 触发条件

- **手动触发**: 通过 GitHub UI 手动运行
- **定时任务**: 每周一 UTC 时间 00:00 自动运行
- **配置变更**: 当规则源配置文件更改时自动触发
- **标签发布**: 创建 Git 标签时自动发布 Release

### 执行流程

1. 检查最新版本的 sing-box
2. 根据系统架构下载合适的 sing-box 二进制文件
3. 下载配置中指定的所有规则源
4. 将规则编译为 SRS 格式
5. 上传生成的文件到 Artifacts
6. （可选）创建 GitHub Release

## 🐛 故障排除

### 常见问题

**Q: 工作流运行失败，显示 "Failed to download sing-box tool"**
A: 这通常是网络问题导致的下载失败，工作流会自动重试。如果问题持续，请检查 GitHub 的网络连接状态。

**Q: 规则转换失败**
A: 检查规则源 URL 是否可访问，以及规则格式是否正确配置。

**Q: 生成的 SRS 文件无法加载**
A: 确保使用兼容的 sing-box 版本（v1.12.4+）。

### 查看日志

工作流运行详情可以在仓库的 **Actions** 标签页中查看，每个步骤都有详细的日志输出。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进本项目！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [SagerNet/sing-box](https://github.com/SagerNet/sing-box) - 优秀的代理平台
- GitHub Actions - 强大的自动化平台

## 📞 支持

如果你遇到任何问题或有建议，请：

1. 查看 [现有 Issue](https://github.com/gr294949/sing-box-rule-converter/issues)
2. 如果找不到解决方案，请创建新 Issue 并提供详细描述

---

⭐ 如果你觉得这个项目有用，请给它一个星标！


