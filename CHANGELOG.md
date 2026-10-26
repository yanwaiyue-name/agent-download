# 更新日志

本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [4.3.0] - 2026-10-26

「实用工具」新增一个硬件自检入口：图吧工具箱。

### 新增项目（1 个）
| 名称 | 分组 | 安装方式 |
|---|---|---|
| **图吧工具箱（TBTool）** | 实用工具 | 仅官网入口（`install: web`），不托管、不进离线包 |

### 说明
- 图拉丁吧社区的硬件检测合集，适合装 AI 客户端或跑本地模型前，先确认 CPU、内存、显卡和硬盘状况
- 整合包内含 AIDA64、UltraISO 等第三方闭源/试用工具，安装包无数字签名，Defender 可能误报；因此**只给官网页**，不写入 Release，也不进买家版离线包
- 项目 46 → 47，`sources.json`、离线清单页、图形界面、检测脚本与推荐表同步

### 修复
- 离线清单页的分组筛选补上「本地运行」「实用工具」——此前这两组的卡片能显示，但筛选栏里没有入口

## [4.2.0] - 2026-10-25

补齐「跑 Agent 需要的环境」：开发环境分组 4 → 7，项目 43 → 46。

### 新增项目（3 个，全部进「开发环境」）
| 名称 | 解决什么 |
|---|---|
| **uv（Astral）** ⭐ | Python 类 MCP 服务器的标准启动方式（uvx）。配 MCP 报「找不到 uvx」装它 |
| **PowerShell 7.6.8** ⭐ | Windows 自带的还是 5.1；大量 Agent 安装脚本与现代工具链只认 pwsh 7（本仓库 check-links.ps1 也需要） |
| **Windows Terminal 1.25** ⭐ | Claude Code / Gemini CLI 等全屏 TUI 在老 conhost 里渲染和交互有问题；微软官方终端，含免安装便携版 |

### 依据
- Claude Code 官方文档：原生安装已不需要 Node.js；Git for Windows 可选推荐（已有）；ripgrep 随 Claude Code 内置，无需单收
- ripgrep / bun / Docker Desktop 经评估不收：前者内置、后者与 Node.js 重复 / 体积与许可不适合本清单定位

## [4.1.0] - 2026-10-24

新增 5 个应用、2 个分组，新增版本过期检测 CI。

### 新增分组
- **本地运行**：Ollama、LM Studio —— 在自己电脑上跑开源模型，不走云端 API
- **实用工具**：Motrix —— 开源多线程下载器（aria2 内核），配合镜像前缀加速 GitHub 直链

### 新增项目（5 个）
| 名称 | 分组 | 安装方式 |
|---|---|---|
| ZCode 桌面版 | 桌面端 | 原生 exe（win x64 / arm64，Z.ai CDN 国内直连） |
| Qoder | IDE | 官网（阿里 agentic 编程平台，Quest 模式） |
| Ollama | 本地运行 | 官方安装包（1.5 GB 内置运行引擎；ARM64 Windows 走 zip 解压版） |
| LM Studio | 本地运行 | 官网 |
| Motrix | 实用工具 | 原生 exe（win x64 / arm64） |

### 新增
- `scripts/check-versions.ps1` + 每周 CI（`version-check.yml`）：对比钉住版本与上游 latest Release，落后自动开 issue。首次运行即发现 CC Switch 4.0.18 落后于上游 4.0.19
- 为 9 个 CLI 条目补齐 `github` 字段（Claude Code / Gemini CLI / Qwen Code / Kimi CLI / Pi / Goose / OpenHands / Cline / Grox），启动器可优先解析 latest Release，版本检测覆盖到全部 GitHub 条目

### 变更
- 项目 38 → 43，分组 6 → 8，版本号 4.0 → 4.1
- 离线清单页、图形界面、本机检测脚本同步新数据

## [4.0.0] - 2026-10-24

分组重构、项目从 20 扩到 38。

### 新增分组
- **IDE**：Cursor、Trae（国际版）、Trae CN（国内版）、Windsurf、VS Code
- **CLI Code**：Claude Code、Gemini CLI、Qwen Code、Kimi CLI、Pi、Codex CLI、OpenClaw、Aider、iFlow CLI

### 新增项目（18 个）
| 名称 | 分组 | 星 | 安装方式 |
|---|---|---|---|
| Cursor | IDE | 3.3 万 | 官网 |
| Trae / Trae CN | IDE | — | 官网（CN 版国内直连） |
| Windsurf | IDE | — | 官网 |
| VS Code | IDE | — | 官网 |
| Claude Code | CLI | — | 原生 zip（win32 x64/arm64） |
| Gemini CLI | CLI | 10.7 万 | macOS zip / **Windows 走 npm** |
| Qwen Code | CLI | 2.9 万 | 原生 zip（win x64） |
| Kimi CLI | CLI | 1.1 万 | 原生 zip（win x64/arm64） |
| Pi | CLI | 11.7 万 | 原生 zip（win x64/arm64） |
| Codex CLI | CLI | — | **npm**（官方 318 个 assets 无用户包） |
| OpenClaw | CLI | 39.3 万 | **npm**（Release 只有证据文件） |
| Aider | CLI | 5.0 万 | **pip** |
| iFlow CLI | CLI | 5077 | **npm** |
| Goose | Agents | 5.5 万 | 安装版 exe |
| OpenHands | Agents | 9.1 万 | 安装版 exe |
| Cline（桌面版） | Agents | 7.0 万 | 安装版 exe |
| Grox | Agents | 81 | 安装版 exe（社区版，非官方） |

### 变更
- 分组从 4 类改为 6 类：桌面端 / Agents / IDE / CLI Code / 运行环境 / 开发环境
- 新增 `install` 字段：标记 `web` / `npm` / `pip`，明确无二进制包的安装方式
- 校验脚本区分「缺失」与「本就走包管理器」，不再误报警告
- 离线清单页支持新分组、npm/pip 徽章、分组计数

### 未收录（附理由）
| 项目 | 理由 |
|---|---|
| Coffee CLI | 找不到官方仓库与官网，来源不明 |
| NanoBot | `Aisht669/nanobot` 0 星，2026-04 后未更新 |
| 自动交易类（FinGPT / TradingAgents / AI-Trader） | Python 库，非桌面软件 |
| VS Code 扩展类（Roo Code / Continue / kilocode） | 走扩展市场，无独立安装包 |

---

## [1.0.0] - 2026-10-24

首个公开版本。

### 新增
- `sources.json` 统一数据源：20 个应用、3 种架构、5 种格式的官方地址与文件信息
- 按架构自动选择安装包（x64 / ARM64 / x86 检测）
- 同一软件多格式支持：安装版 / MSI / 免安装 / 压缩包 / 商店版，使用者自选
- 本地图形界面：`资源中心.html` + `资源中心服务.ps1`（127.0.0.1，支持 Range 断点续传）
- 命令行安装器 `launcher.ps1`：批量下载、SHA256 校验、离线包优先
- 系统检测 `check-pc.ps1`：架构、内存、磁盘、运行库一表说清
- 维护脚本：`打包.ps1`（生成发布包）、`gen-dirs.ps1`（重建目录）、`补全安装包.ps1`（批量下载）、`清理.ps1`

### 修复
- MSI 文件头识别：MSI 是 OLE 复合文档（`D0 CF 11 E0`），旧版只认 `MZ` 会误判为下载失败
- Hermes 桌面版：官方已提供 Windows / macOS 安装包，不再只有 CLI
- 多应用共用目录（运行环境 / 开发环境）时说明文件互相覆盖

### 已知问题
- WorkBuddy / Claude / ChatGPT 直链含版本哈希，新版发布后失效
- `downloads.claude.ai`、`hermes-assets.nousresearch.com` 国内直连不稳
- Codex（ChatGPT）Windows 包为微软商店引导器，安装时仍需联网
- 安装包未签名，Windows SmartScreen 会提示

---

## 版本对照

| 版本 | 说明 |
|---|---|
| v3.0 | 内部版本，含完整离线包分发流程 |
| v1.0.0 | 首个开源版本，剥离商业分发内容，仅保留工具与清单 |
