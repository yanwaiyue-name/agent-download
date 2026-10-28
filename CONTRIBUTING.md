# 怎么贡献

本项目的贡献指南在 [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)。

## 快速上手

1. **改数据**：所有应用信息在 `sources.json`，不要直接改 `清单.html`（它是生成的）
2. **加应用**：按现有条目格式补 `id / name / vendor / group / variants / page` 等字段
3. **验证**：提交前跑

```powershell
./scripts/verify.ps1        # 校验 sources.json 结构与脚本语法
./scripts/check-links.ps1   # 检查所有下载直链是否可用
```

## 收录标准

**收**：有官方发布渠道的 AI 客户端、命令行工具、开发环境。

**不收**：
- 只能通过第三方下载站获取的
- 需要破解或非官方激活的
- 已停止维护一年以上且无替代的

## 关于下载链接

部分应用（Cursor、VS Code、Aider 等）不提供稳定直链，走官网或 npm/pip 安装。这类条目在 `tip` 字段里写明了正确安装方法，不是数据缺失。

## 免责

本项目只汇总官方下载地址，不托管任何安装包。链接失效请提 Issue，每周一自动体检。
