# AI Agent 桌面版 下载地址总表（v3.0）

> 全部链接于 **2026-10-22 ~ 10-23** 逐个实测（GET/HEAD，返回 200 且字节数与官方 release 一致）。链接会随版本更新失效，文末有「怎么自己刷新」的方法。
> 用途：给你做**离线安装包分发**用——照这张表把安装包放进 `安装包/` 对应目录，用于离线分发。
> **v3.0 变更**：Hermes 补上桌面版；每个软件补齐 Windows 的全部格式（安装版 / MSI / 免安装 / 压缩包）；macOS 包单独放 `安装包/<应用>/mac/`。

---

## 一、Windows 总表（现在包里已经下好的）

| # | 应用 | 格式 | 文件名（本地） | 大小 | 来源 |
|---:|---|---|---|---:|---|
| 1 | **WorkBuddy**（腾讯） | 安装版 x64 | `WorkBuddy-win32-x64-user-5.8.3.41334564-db0e9b51.exe` | 420.7 MB | 腾讯官方 CDN |
| 2 | **Claude Desktop** | 安装版 x64 | `Claude-Setup-x64.exe` | 157.6 MB | Anthropic 官方（claude-science 通道） |
| 3 | **ChatGPT 桌面端**（含 Codex） | 商店版 x64/arm64 | `ChatGPT Installer.exe` | 0.8 MB | 微软商店引导器 |
| 4 | **OpenCode Desktop** | 安装版 x64 | `opencode-desktop-win-x64.exe` | 120.5 MB | GitHub v1.19.4 |
| 4 | | 免安装 zip x64 | `opencode-windows-x64.zip` | 78.0 MB | GitHub v1.19.4 |
| 4 | | 安装版 arm64 | `opencode-desktop-win-arm64.exe` | 113.4 MB | GitHub v1.19.4 |
| 4 | | 免安装 zip arm64 | `opencode-windows-arm64.zip` | 72.3 MB | GitHub v1.19.4 |
| 5 | **DeepSeek Harness 桌面版** | 安装版 x64 | `DSH-Desktop-2.0.18-x64-Setup.exe` | 314.8 MB | 社区仓库 v2.0.18 |
| 6 | **Cherry Studio** | 安装版 x64 | `Cherry-Studio-2.1.7-win-x64-setup.exe` | 296.4 MB | GitHub v2.1.7 |
| 6 | | 免安装 x64 | `Cherry-Studio-2.1.7-win-x64-portable.exe` | 296.1 MB | GitHub v2.1.7 |
| 6 | | 安装版 arm64 | `Cherry-Studio-2.1.7-win-arm64-setup.exe` | 275.2 MB | GitHub v2.1.7 |
| 6 | | 免安装 arm64 | `Cherry-Studio-2.1.7-win-arm64-portable.exe` | 274.8 MB | GitHub v2.1.7 |
| 7 | **LobeHub 桌面版** | 安装版 x64 | `LobeHub-2.2.20-setup.exe` | 145.5 MB | GitHub v2.2.20 |
| 8 | **CC Switch** | MSI x64 | `CC-Switch-v4.0.18-Windows.msi` | 16.7 MB | GitHub v4.0.18 |
| 8 | | 免安装 zip x64 | `CC-Switch-v4.0.18-Windows-Portable.zip` | 16.7 MB | GitHub v4.0.18 |
| 8 | | MSI arm64 | `CC-Switch-v4.0.18-Windows-arm64.msi` | 16.0 MB | GitHub v4.0.18 |
| 8 | | 免安装 zip arm64 | `CC-Switch-v4.0.18-Windows-arm64-Portable.zip` | 15.8 MB | GitHub v4.0.18 |
| 9 | **Open Cowork** | 安装版 x64 | `Open.Cowork-3.3.1-win-x64.exe` | 123.1 MB | GitHub v3.3.1 |
| 10 | **RunJam** | 安装版 x64 | `RunJam_1.0.101_x64-setup.exe` | 107.3 MB | GitHub v1.0.101 |
| 11 | **Desktop CC GUI** | 安装版 x64 | `CC.GUI_1.1.6_x64-setup.exe` | 15.0 MB | GitHub v1.1.6 |
| 12 | **Hermes Agent 桌面版** | 安装版 x64 | `Hermes-Setup.exe` | 7.6 MB | NousResearch 官方 |
| 13 | **Watt Toolkit**（瓦特工具箱，原名 Steam++） | 安装版 x64 | `Steam++_v3.1.0_win_x64.exe` | 92.3 MB | GitHub v3.1.0 |
| 13 | | 免安装 7z x64 | `Steam++_v3.1.0_win_x64.7z` | 90.3 MB | GitHub v3.1.0 |

> 第 5 行另有官方校验清单 `SHA256SUMS.txt`（同目录，0.0 MB），DSH 下完可以对照。

### 按架构速查（Windows）

| 使用者电脑 | 该给哪个版本 | 说明 |
|---|---|---|
| **x64**（Intel / AMD，绝大多数） | 全部下 x64 版 | 最常见 |
| **ARM64**（骁龙 X / 麒麟等） | OpenCode、Cherry Studio、CC Switch 有 **arm64 原生包**（含免安装）；WorkBuddy、Claude、DSH、LobeHub、Open Cowork、RunJam、Desktop CC GUI、Hermes 只有 x64，**靠系统模拟运行**（能用，稍慢、更耗电）；Codex 走微软商店，商店自动下发对应架构 | 交付时提前说一句「会慢一点」，避免使用者抱怨 |
| **x86**（32 位老系统） | **一个都装不了** | 这些软件全部只发 64 位 |

**Windows 上只有 OpenCode、Cherry Studio、CC Switch 提供 ARM64 原生包**。别承诺「ARM 版原生支持」。

---

## 二、macOS 包（在 `安装包/<应用>/mac/`，默认不进发布包）

| 应用 | 文件 | 直链 |
|---|---|---|
| WorkBuddy | `WorkBuddy-darwin-arm64-5.8.3.41334564-db0e9b51.dmg` | `https://download.codebuddy.cn/workbuddy/saas/darwin-arm64/WorkBuddy-darwin-arm64-5.8.3.41334564-db0e9b51.dmg` |
| Claude Desktop | `Claude-mac-arm64.dmg` / `Claude-mac-x64.dmg` | `https://downloads.claude.ai/claude-science/latest/mac-arm64.dmg` ／ `.../mac-x64.dmg` |
| ChatGPT | `ChatGPT.dmg` | `https://persistent.oaistatic.com/sidekick/public/ChatGPT.dmg` |
| OpenCode | `opencode-desktop-mac-arm64.dmg` / `-x64.dmg` | `.../releases/latest/download/opencode-desktop-mac-arm64.dmg` |
| DeepSeek Harness | `DSH.Desktop-2.0.18-universal.dmg` | `.../releases/latest/download/DSH.Desktop-2.0.18-universal.dmg` |
| Cherry Studio | `Cherry-Studio-2.1.7-mac-arm64.dmg` / `-x64.dmg` | `.../releases/latest/download/Cherry-Studio-2.1.7-mac-arm64.dmg` |
| LobeHub | `LobeHub-2.2.20-arm64.dmg` / `-x64.dmg` | `.../releases/latest/download/LobeHub-2.2.20-arm64.dmg` |
| CC Switch | `CC-Switch-v4.0.18-macOS.dmg` | `.../download/v4.0.18/CC-Switch-v4.0.18-macOS.dmg` |
| Open Cowork | `Open.Cowork-3.3.1-mac-arm64.dmg` | `.../download/v3.3.1/Open.Cowork-3.3.1-mac-arm64.dmg` |
| RunJam | `RunJam_1.0.101_aarch64.dmg` / `_x64.dmg` | `.../download/v1.0.101/RunJam_1.0.101_aarch64.dmg` |
| Desktop CC GUI | `ccgui_1.1.6_aarch64.dmg` / `_x86_64.dmg` | `.../download/v1.1.6/ccgui_1.1.6_aarch64.dmg` |
| Hermes | `Hermes-Setup.dmg` | `https://hermes-assets.nousresearch.com/Hermes-Setup.dmg` |

> 下全 macOS 包用：`powershell -ExecutionPolicy Bypass -File .\补全安装包.ps1 -Mac`
> 交付时带上它们用：`.\打包.ps1 -Mac`
>
> **当前状态（2026-10-23）**：18 个 dmg 已全部下完，共 3.18 GB，位于 `安装包\<应用>\mac\`。
> Windows 侧 21 个安装程序也全齐（含 Cherry Studio x64 免安装版）。合计 40 个文件 / 6.00 GB。
> 全量校验通过：exe 查 MZ、msi 查 OLE 头、zip 查 PK、dmg 查末尾 512 字节 trailer 的 `koly` 签名。

---

## 二·五、运行环境（`安装包/运行环境/`）

这些不是软件，是软件运行要依赖的底层组件。目标机器上缺了，表现是「装好了但打不开」「窗口一片白」「缺少 VCRUNTIME140.dll」。

| 文件 | 大小 | 直链 | 说明 |
|---|---|---|---|
| `MicrosoftEdgeWebview2Setup.exe` | 1.8 MB | `https://go.microsoft.com/fwlink/p/?LinkId=2124703` | WebView2 **在线引导器**，安装时联网下载约 150 MB |
| `MicrosoftEdgeWebView2RuntimeInstallerX64.exe` | 204.9 MB | `https://go.microsoft.com/fwlink/p/?LinkId=2124701` | WebView2 **离线完整包**，装的时候不联网 |
| `VC_redist.x64.exe` | 24.4 MB | `https://aka.ms/vs/17/release/vc_redist.x64.exe` | VC++ 2015-2022 运行库 x64 |

**两个 WebView2 选一个装就行**，不用都装：
- 使用者电脑能上网 → 用 1.8 MB 在线版
- 使用者电脑完全离线 → 用 204.9 MB 离线包

**LinkId 别记错**（我一开始就搞反过）：

| LinkId | 实际是什么 | 大小 |
|---|---|---|
| 2124701 | x64 **离线独立包**（`...RuntimeInstallerX64.exe`） | 214.8 MB |
| 2124703 | x64 **在线引导器**（`MicrosoftEdgeWebview2Setup.exe`） | 1.87 MB |
| 2124702 | 已失效，重定向到一个 Linux RPM，别用 | — |

**哪些应用真的依赖 WebView2**：Tauri 框架的。CC Switch 的 MSI 里直接内置了 WebView2 安装器，可以直接确认；其他应用是 NSIS 压缩包，字符串查不出来，但同一批里 Tauri 的都在内。Windows 11 自带 WebView2，Windows 10 一般随 Edge 预装，所以**大多数机器其实不用装**。

**不用装 Python / Node.js**：这 12 个桌面软件自带运行环境。Python 只在维护者侧用（`_scratch/fetch-packs.py`），Node 只在用 opencode / hermes 的**命令行版**时才需要。

---

## 二·六、开发环境（`安装包/开发环境/`）

**先说清楚定位**：上面 13 个桌面软件**都不需要**这些，它们自带运行时。这一组是给「想用命令行工具」的人准备的——Claude Code、opencode CLI 这类工具要靠 npm 装，跑脚本要靠 Python。

| 文件 | 大小 | 说明 |
|---|---|---|
| `python-3.13.10-amd64.exe` / `-arm64.exe` | 27 / 26 MB | Python 官方安装器（含 pip） |
| `node-v24.22.1-x64.msi` / `-arm64.msi` | 31 / 28 MB | Node.js LTS（含 npm） |
| `Git-2.56.0.3-64-bit.exe` / `-arm64.exe` | 61 / 59 MB | Git for Windows（含 Git Bash） |
| `7z2501-x64.exe` / `-arm64.exe` | 1.5 MB | 7-Zip，解 `.7z` 用（Watt 免安装版需要） |

### 镜像优先（重要）

`python.org` 在国内实测只有 **11 KB/s**，`nodejs.org` 约 200 KB/s。所以 `sources.json` 里把镜像放在了**第一个**，官方源作兜底：

| 环境 | 首选（快） | 兜底（官方） |
|---|---|---|
| Python | `https://mirrors.huaweicloud.com/python/3.13.10/`（实测 1.8 MB/s） | `https://www.python.org/ftp/python/3.13.10/` |
| Node.js | `https://registry.npmmirror.com/-/binary/node/v24.22.1/`（实测 2.1 MB/s） | `https://nodejs.org/dist/v24.22.1/` |
| Git | `github.com/git-for-windows/git/releases` + 加速前缀 | 同左 |
| 7-Zip | `github.com/ip7z/7zip/releases` + 加速前缀 | `https://www.7-zip.org/a/7z2501-x64.exe`（会 302 到 GitHub） |

### 版本选择与踩坑

- **Python 选 3.13.10 不选 3.14.2**：3.14 虽然是最新，但不少 AI 工具的依赖还没出 3.14 的 wheel，装包容易失败。3.13 是兼容性最稳的。想用 3.14 的链接：`https://www.python.org/ftp/python/3.14.2/python-3.14.2-amd64.exe`
- **Git 的 tag 容易拼错**：正确是 `v2.56.0.windows.3`，资产名却是 `Git-2.56.0.3-64-bit.exe`。我一开始按资产名把 tag 写成 `v2.56.0.3.windows.3`，直接 404
- **Python 安装器默认不勾 PATH**：必须手动勾「Add python.exe to PATH」，否则命令行找不到 `python`。这是最常见的问题，已写进 `使用说明.txt`
- 7-Zip 官网 `/a/7z2501-x64.exe` 会 302 跳到 GitHub，直接 `curl -I` 只看到 302，要跟跳转

### 没有收录的（说明理由）

| 环境 | 为什么不收 |
|---|---|
| Java | 本清单没有任何软件需要 |
| Go / Rust | 同上；opencode 有现成 exe，不用装 Go |
| .NET SDK | Watt Toolkit 的 7z 包里自带 `dotnet\` 运行时，用户不用装 |
| Docker / WSL | 与这批软件无关，且体积大、装完要重启 |

需要这些的话，链接都在官方页：`https://adoptium.net`（Java）、`https://go.dev/dl/`、`https://rustup.rs`、`https://dot.net`。

---

## 三、官方下载页（给人看的入口，别丢）

| 应用 | 官方下载页 | 官网 / 仓库 |
|---|---|---|
| WorkBuddy | https://www.workbuddy.cn/ → 点「Windows / Mac」 | https://www.workbuddy.cn |
| Claude Desktop | https://claude.ai/download | https://claude.ai |
| Codex / ChatGPT | https://chatgpt.com/download | https://openai.com/codex |
| OpenCode | https://opencode.ai/download | https://opencode.ai |
| DeepSeek Harness | https://github.com/anywhere-labs/dsh-desktop/releases | https://github.com/deepseek-ai/deepseek-harness |
| **Hermes** | **https://hermes-agent.nousresearch.com/ （首页就有 Desktop App 的 Windows / macOS 按钮）** | https://github.com/NousResearch/hermes-agent |
| Cherry Studio | https://www.cherry-ai.com | https://github.com/CherryHQ/cherry-studio |
| LobeHub | https://github.com/lobehub/lobehub/releases | 同左 |
| CC Switch | https://ccswitch.io | https://github.com/farion1231/cc-switch/releases |
| Open Cowork | https://github.com/OpenCoworkAI/open-cowork/releases | 同左 |
| RunJam | https://www.runjam.app | https://github.com/peintune/runjam/releases |
| Desktop CC GUI | https://github.com/zhukunpenglinyutong/desktop-cc-gui/releases | 同左 |

---

## 四、关键事实（跟直觉不一样的地方）

### 1. Hermes 有桌面版了（v2.2 这里写错了）

旧文档写「Hermes 只有 CLI，releases 里连 exe 都没有」，**这是错的**，已经改掉。

- 官方首页 https://hermes-agent.nousresearch.com/ 有 **Hermes Desktop App** 区块，明确写 macOS 12+ / Windows 10/11 都可以下载桌面版
- 实际直链：
  - Windows：`https://hermes-assets.nousresearch.com/Hermes-Setup.exe?build=dc0fe3e476a0`（7,946,048 字节 = 7.6 MB）
  - macOS：`https://hermes-assets.nousresearch.com/Hermes-Setup.dmg?build=dc0fe3e476a0`
- GitHub releases 的 `assets` 数组确实是**空的**（`assets: []`），所以只看 API 会误判成"没有桌面版"。
  真正的原因是官方把安装包放在自己的 CDN（`hermes-assets.nousresearch.com`），没挂到 GitHub Release 上。
- release note 里也写了更新方式：`Microsoft Store app: updates through the Store. Desktop app installed from the installer (.exe / .dmg)`，说明桌面版有两条分发线（商店 + 安装器）
- 注意：`Hermes-Setup.exe` 是**引导器**，首次启动会联网拉运行时（跟 ChatGPT 那个 0.8MB 的引导器一个道理）。想纯离线，得在联网机器上装一次再把 `%LOCALAPPDATA%\hermes` 一起打包——这一步没做，如实说明需要联网
- 命令行版依然可用：`irm https://hermes-agent.nousresearch.com/install.ps1 | iex`（`-IncludeDesktop` 参数可以把桌面版一起装）

### 2. Codex 没有独立安装包，桌面版就是 ChatGPT 使用者端

`openai.com/codex` 页面上所有「Download for Windows」都指向**微软商店的 ChatGPT 应用**（产品 ID `9PLM9XGG6VKS`），不是 `Codex-Setup.exe`。

- **Windows**：装 ChatGPT 应用 → 里面开 Codex 面板。走微软商店，国内可访问
- **macOS**：`ChatGPT.dmg`，装完也是同一个应用
- 纯 Codex 只有 CLI（`npm i -g @openai/codex`）和 IDE 插件

**交付时别说「Codex 桌面版安装包」**，说「ChatGPT 桌面端，里面自带 Codex」。

那个 Windows 链接下载下来只有 **813,088 字节**，文件名 `ChatGPT Installer.exe`，是**微软商店引导器**——双击后还要联网从商店拉几百 MB 主程序。想要纯离线包得另配 `msixbundle`（`https://store.rg-adguard.net/` 输产品 ID → 选 Retail）。

### 3. DeepSeek Harness 官方仓库没有桌面安装包

`deepseek-ai/deepseek-harness` **只发源码，没有 releases**。桌面版在社区仓库 `anywhere-labs/dsh-desktop`，最新 v2.0.18（2026-10-17）。跟使用者讲清楚：装的是社区打包版。

### 4. Claude 的直链路径叫 `claude-science`

`https://downloads.claude.ai/claude-science/latest/windows-x64.exe` —— 路径里的 `claude-science` 不是笔误，是官方现在的发布通道。
老通道（旧版，别用）：`https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe`

### 5. MSI 的文件头不是 MZ（踩过的坑）

`CC-Switch-*.msi` 是 **OLE 复合文档**，文件头是 `D0 CF 11 E0`，不是 `MZ`。
v2.2 的 `Test-InstallerMagic` 对所有 exe/msi 都要求 MZ，结果**两个 MSI 下完就被判成"下载失败"删掉了**。
v3.0 已修：msi 认 `D0CF`（或个别封装器的 `MZ`），zip 认 `PK`，7z 认 `377ABCAF271C`，exe 认 `MZ`。

### 6. Watt Toolkit：三个名字都不一样

这个软件最容易找错仓库，三处命名全是不同的：

| 你看到的 | 实际是 |
|---|---|
| 产品名 / 桌面图标 | **Watt Toolkit**（瓦特工具箱） |
| 安装后的目录和程序 | `C:\Program Files\Steam++\Steam++.exe` |
| GitHub 仓库 | **`BeyondDimension/SteamTools`** |
| Release 资产文件名 | `Steam++_v3.1.0_win_x64.exe` |
| 官网 | https://steampp.net/ |

搜 "WattToolkit" 会 404（我试过 `BeyondDimension/WattToolkit`，API 返回 Not Found）。

**版本情况（2026-10-23 核实）**：

- 最新稳定版 **3.1.0**，2026-03-11 发布
- **Windows 只有 x64，从来没有 arm64**（历史版本只给 Linux 出过 arm64）
- Windows 两种格式：`.exe` 安装版（92.3 MB）、`.7z` 免安装版（90.3 MB）
- macOS 一个通用 dmg（220.0 MB）
- Linux 有 `.tgz`（81.7 MB），本包不收

**7z 免安装版的两个要点**：

1. 它是**自包含**的：930 个文件、解压后 351 MB，里面自带 `dotnet\` 运行时，所以**不用装 .NET**
2. `.7z` 不能用 Windows 自带的 `Expand-Archive` 解压，必须装 7-Zip。启动器已经处理了：检测到 7-Zip 就自动解压，没装就提示改用安装版

**历史版本怎么找**：`https://github.com/BeyondDimension/SteamTools/releases`（3.0.0-rc.10 ~ rc.16 都还在，本机装的就是 rc.16）

---

## 五、GitHub 加速站实测（2026-10-22）

拿 CC GUI 的 15MB exe 和 Cherry 的 296MB 包做的测试：

| 加速前缀 | 结果 | 说明 |
|---|---|---|
| `https://gh-proxy.com/` | ✅ 200，约 350–490 KB/s | 推荐首选 |
| `https://ghfast.top/` | ✅ 200，约 320–470 KB/s | 备用 |
| `https://gh.llkk.cc/` | ✅ 200（偶发连不上） | 备用 |
| `https://ghproxy.net/` | ⚠️ 200 但只有 10 KB/s | 基本不能用 |
| `https://hub.gitmirror.com/` | ❌ 连接被关闭 | 别用 |
| 直连 `github.com` | ❌ 本机 000（被墙） | 国内基本不通 |

**用法**：在原 GitHub 链接前面拼前缀即可。

```
原链接：https://github.com/anomalyco/opencode/releases/download/v1.19.4/opencode-desktop-win-x64.exe
加速后：https://gh-proxy.com/https://github.com/anomalyco/opencode/releases/download/v1.19.4/opencode-desktop-win-x64.exe
```

⚠️ **加速站对 `api.github.com` 的支持不一样**：`ghfast.top` 代理 api 会 403，`gh-proxy.com` 可以（200）。所以自动查版本时优先 `gh-proxy.com`。

⚠️ 实测单连接速度波动很大（同一文件 8 MB/s 到 200 KB/s 都有），**多线程并发能到 3–4 MB/s**。所以批量下包别串行。

⚠️ 这些是**第三方公益站**，随时可能挂或限速。**推荐做法是：你自己用加速站下好，把包放进 `安装包/`，不要让使用者现场下载。**

---

## 六、需要代理才能下载的

| 域名 | 直连 | 说明 |
|---|---|---|
| `downloads.claude.ai` | ❌ 502 / 000 | 必须通过代理访问 |
| `hermes-assets.nousresearch.com` | ⚠️ 不稳 | 走代理稳（约 220 KB/s） |
| `download.codebuddy.cn` | ✅ 7.7 MB/s | 腾讯国内 CDN，飞快 |
| `get.microsoft.com` | ✅ | 微软商店引导器 |
| `persistent.oaistatic.com` | ✅ | ChatGPT macOS dmg |

---

## 七、npm 镜像（装 CLI 用，不是桌面版）

```bash
npm config set registry https://registry.npmmirror.com
npm i -g @anthropic-ai/claude-code
npm i -g @openai/codex
npm i -g @opencode/cli@latest
npm i -g @deepseek-ai/dsh
```

装完记得改回来：`npm config set registry https://registry.npmjs.org`

---

## 八、离线包准备清单

**每个软件有自己的文件夹，文件名必须和 `sources.json` 里的 `file` 字段完全一致**（包括空格和大小写），
否则安装器认不出来，会以为「需下载」。

```
安装包/
├── WorkBuddy/                安装版 x64 + mac/
├── Claude Desktop/           安装版 x64 + mac/（arm64 / x64 两个 dmg）
├── Codex (ChatGPT)/          商店版引导器 + mac/ChatGPT.dmg
├── OpenCode/                 安装版 + zip（x64/arm64 各一套）+ mac/
├── DeepSeek Harness/         安装版 x64 + SHA256SUMS.txt + mac/
├── Cherry Studio/            安装版 + 免安装（x64/arm64 各一套）+ mac/
├── LobeHub/                  安装版 x64 + mac/
├── CC Switch/                MSI + 免安装 zip（x64/arm64 各一套）+ mac/
├── Open Cowork/              安装版 x64 + mac/
├── RunJam/                   安装版 x64 + mac/
├── Desktop CC GUI/           安装版 x64 + mac/
└── Hermes/                   安装版 x64 + mac/
```

**目录不用手建**：

```powershell
powershell -ExecutionPolicy Bypass -File .\gen-dirs.ps1 -Force   # 建目录 + 写「放这里.txt」
powershell -ExecutionPolicy Bypass -File .\补全安装包.ps1        # 把缺的格式都下全
powershell -ExecutionPolicy Bypass -File .\launcher.ps1 -Check   # 看是不是全「已就绪」
```

### 全量 / 精简怎么选

| 做法 | 体积 | 适用 |
|---|---|---|
| 只带 x64 主格式（每个软件一份） | 约 1.9 GB | 使用者都是 Intel/AMD 普通机器 |
| 全格式（x64 + arm64 + 免安装 + zip） | 约 2.6 GB | 面向架构不确定的使用者，一个包通吃 |
| 全格式 + macOS 包 | 约 5.8 GB | 连 macOS 使用者一起做 |

⚠️ 别把 arm64 包放到 `安装包/` 根目录去 —— 根目录是兜底查找位置，混放会让 x64 使用者也去扫这些废包。**放对应的子文件夹就没事。**
⚠️ `mac/` 子目录里的 dmg 启动器不会读，只用于单独发给 macOS 使用者。

---

## 九、校验下载是否完整

**Windows（PowerShell）**
```powershell
Get-FileHash .\Claude-Setup-x64.exe -Algorithm SHA256
```

**macOS / Linux**
```bash
shasum -a 256 Claude-Setup-x64.exe
```

DSH 官方提供校验清单（下载后对照）：
```
https://github.com/anywhere-labs/dsh-desktop/releases/download/v2.0.18/SHA256SUMS.txt
```

其它几家不提供校验文件，用「文件大小是否与第一节一致」做粗校验即可（差 1 MB 以上就说明没下完）。
`补全安装包.ps1` 会把每个文件的 SHA256 写进 `下载日志.txt`，以后替换包时对比这个就行。

---

## 十、链接过期了怎么自己刷新

**办法 1：GitHub 系 —— 用 `latest` 重定向**
把链接里的版本号换成 `latest/download`：
```
https://github.com/anomalyco/opencode/releases/latest/download/opencode-desktop-win-x64.exe
```
这个地址永远指向最新版，不会失效。**建议离线包里就用这个形式。**

**办法 2：查最新版本号**
```powershell
# 通过加速站查（gh-proxy 可用，ghfast 对 api 会 403）
Invoke-RestMethod "https://gh-proxy.com/https://api.github.com/repos/anomalyco/opencode/releases/latest" |
  Select-Object tag_name
```

**办法 3：WorkBuddy / Claude / ChatGPT / Hermes —— 只能打开官网点一次**
这四家的直链带版本哈希或 build 参数，没法猜。打开官网、点下载按钮，在浏览器下载列表里右键「复制下载链接」。
Hermes 的 build 参数（`?build=dc0fe3e476a0`）会随版本变，直接从首页按钮复制最保险。

---

*本文档所有链接均已实测。数据来源：各项目官方站点、GitHub Releases API、微软商店页面、Hermes 官网，2026-10-22 ~ 10-23。*