<p align="center">
  <img src="docs/images/01-首页.png" alt="AI Client Download Center" width="880">
</p>

<h1 align="center">📦 AI Client Download Center</h1>

<p align="center"><strong>Version 4.0</strong></p>

<p align="center">
  <em>Curated official download links for mainstream AI desktop clients,<br>
  with per-architecture guidance so you install the right build the first time.</em>
</p>

<p align="center">
  <a href="https://github.com/yanwaiyue-name/agent-download/stargazers"><img src="https://img.shields.io/github/stars/yanwaiyue-name/agent-download?logo=github&label=Stars" alt="Stars"></a>
  <a href="https://github.com/yanwaiyue-name/agent-download/blob/master/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat" alt="MIT"></a>
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20macOS-0078d4" alt="Platform">
  <img src="https://img.shields.io/badge/software-43%20apps-2ea44f" alt="43 apps">
</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a>
</p>

---

## What this is

Installing AI desktop clients from mainland China usually fails at three points:

1. **You cannot find the real download page** — the first search results are all "download accelerators" bundling adware.
2. **You cannot tell which build you need** — the same app ships x64 / ARM64, installer / portable / MSI.
3. **The download stalls** — some official CDNs are unreachable directly.

This repo does three things: **curates official links**, **tells you which build matches your machine**, and **ships a tool that auto-detects your hardware and installs offline**.

> This repository contains **scripts and a manifest only** — no installer binaries. Get every installer from the official pages listed below.

---

## ⚡ 30-second lookup

**43 entries in 8 groups.** ⭐ = recommended.

> Important: entries marked `npm` / `pip` have **no downloadable installer** — that is how the vendor ships them, not a missing file.

### Desktop clients (10)

| Software | Intel/AMD | Snapdragon/Kirin | macOS | Official |
|---|---|---|---|---|
| WorkBuddy (Tencent) ⭐ | ✅ installer | ⚠️ emulated | ✅ Apple Silicon | [link](https://www.workbuddy.cn) |
| Claude Desktop ⭐ | ✅ installer | ⚠️ emulated | ✅ Apple/Intel | [link](https://claude.ai/download) |
| ChatGPT Desktop (incl. Codex) ⭐ | ✅ Store stub | ✅ native | ✅ Apple/Intel | [link](https://chatgpt.com/download) |
| OpenCode Desktop ⭐ | ✅ installer/portable | ✅ native | ✅ Apple/Intel | [link](https://opencode.ai/download) |
| DeepSeek Harness Desktop | ✅ installer | ⚠️ emulated | ✅ Apple/Intel | [link](https://github.com/anywhere-labs/dsh-desktop/releases) |
| Cherry Studio ⭐ | ✅ installer/portable | ✅ native | ✅ Apple/Intel | [link](https://www.cherry-ai.com) |
| LobeHub Desktop | ✅ installer | ⚠️ emulated | ✅ Apple/Intel | [link](https://github.com/lobehub/lobehub/releases) |
| Hermes Agent Desktop ⭐ | ✅ installer | ⚠️ emulated | ✅ Apple Silicon | [link](https://hermes-agent.nousresearch.com/) |
| Watt Toolkit | ✅ installer/portable | ⚠️ emulated | ✅ Apple/Intel | [link](https://steampp.net/) |
| ZCode Desktop ⭐ | ✅ installer | ✅ native | ✅ Apple/Intel | [link](https://zcode.z.ai/cn) |

### Agents (8)

| Software | Intel/AMD | Snapdragon/Kirin | macOS | Official |
|---|---|---|---|---|
| CC Switch ⭐ | ✅ installer/portable | ✅ native | ✅ Apple/Intel | [link](https://ccswitch.io) |
| Open Cowork ⭐ | ✅ installer | ⚠️ emulated | ✅ Apple Silicon | [link](https://github.com/OpenCoworkAI/open-cowork/releases) |
| RunJam ⭐ | ✅ installer | ⚠️ emulated | ✅ Apple/Intel | [link](https://www.runjam.app) |
| Desktop CC GUI ⭐ | ✅ installer | ⚠️ emulated | ✅ Apple/Intel | [link](https://github.com/zhukunpenglinyutong/desktop-cc-gui/releases) |
| Goose ⭐ | ✅ installer | ⚠️ emulated | ✅ Apple/Intel | [link](https://github.com/aaif-goose/goose/releases) |
| OpenHands ⭐ | ✅ installer | ⚠️ emulated | — | [link](https://github.com/OpenHands/OpenHands/releases) |
| Cline (desktop) ⭐ | ✅ installer | ⚠️ emulated | — | [link](https://github.com/cline/cline/releases) |
| Grox (community) | ✅ installer | ⚠️ emulated | — | [link](https://github.com/dandandujie/Grox) |

### IDE (6)

| Software | Install | Notes |
|---|---|---|
| Cursor | official site | AI-native editor |
| Trae (global) | official site | ByteDance, needs proxy in CN |
| **Trae CN** ⭐ | official site | **ByteDance China build — direct access in CN** |
| Windsurf | official site | Codeium, Cascade agent |
| VS Code | official site | base for Cline / Roo Code / Continue extensions |
| **Qoder** ⭐ | official site | Alibaba agentic coding platform, Quest mode |

### CLI Code (9)

| Tool | Install | Windows binary |
|---|---|---|
| Claude Code ⭐ | zip | ✅ win32 x64 / arm64 |
| Qwen Code ⭐ | zip | ✅ win x64 |
| Kimi CLI ⭐ | zip | ✅ win x64 / arm64 |
| Pi ⭐ | zip | ✅ win x64 / arm64 |
| **Gemini CLI** ⭐ | **npm** | ❌ macOS only |
| **Codex CLI** | **npm** | ❌ no user-facing builds |
| **OpenClaw** ⭐ | **npm** | ❌ release has manifests only |
| Aider | pip | ❌ Python package |
| iFlow CLI | npm | ❌ no binary |

### Local inference (2)

Run open models (Qwen / DeepSeek / Llama) on your own hardware, no cloud API.

| Software | Install | Notes |
|---|---|---|
| **Ollama** ⭐ | installer (1.5 GB) | de-facto standard for local models; ARM64 Windows uses zip |
| **LM Studio** ⭐ | official site | local-model GUI, OpenAI-compatible server |

### Utilities (1)

Not AI apps — they just make the downloads above faster.

| Software | Intel/AMD | Snapdragon/Kirin | macOS | Official |
|---|---|---|---|---|
| **Motrix** ⭐ | ✅ installer | ✅ native | ✅ Apple/Intel | [link](https://motrix.app) |

### Runtime (3) / Dev toolchain (4)

WebView2 online + offline, VC++ redist; Python 3.13.10, Node.js 24.22.1 LTS, Git 2.56.0.3, 7-Zip 25.01.

---

## 🤔 Which build is mine?

| You see | Meaning | Choose |
|---|---|---|
| Intel Core / AMD Ryzen | plain **x64**, ~90% of PCs | x64 build |
| Snapdragon X / Kirin | **ARM64** PC | native ARM64 if available, else x64 (emulated, slower) |
| Apple M-series | **Apple Silicon** | macOS arm64 dmg |
| Apple Intel Mac | **Intel Mac** | macOS x64 dmg |

On Windows, just run `双击检测.bat` — it prints the recommended build and writes a shareable `本机检测报告.txt`.

---

## 🚀 Three ways to use it

**1. GUI (best for beginners).** Run `打开资源中心.bat`. Your browser opens a local catalogue: cards per app, category filters, search, x64/ARM64 toggle, resumable downloads. It listens on `127.0.0.1` only — no network calls, no telemetry, no admin rights.

**2. CLI.** Run `双击启动.bat` and type an index. `A` downloads all defaults, `V` verifies SHA256, `Q` quits.

**3. Fully offline.** Download installers on any networked machine, place them under `安装包/<AppName>/`, copy the folder over, then run `双击启动.bat`. Everything shows "ready" and installs without touching the network.

---

## 📁 Layout

```
agent-download/
├── README.md / README.en.md
├── 双击启动.bat          CLI installer (main entry)
├── 双击检测.bat          hardware detection
├── 打开资源中心.bat      GUI entry
├── launcher.ps1         install logic
├── check-pc.ps1         system detection
├── 资源中心服务.ps1      local HTTP server (127.0.0.1)
├── 资源中心.html         catalogue UI
├── sources.json         ★ single source of truth
├── docs/                maintainer guide, link table, screenshots
└── scripts/             packaging, directory generation, bulk download, cleanup
```

---

## 🔧 Adding an app

Edit the `apps` array in `sources.json` only, then run `scripts/gen-dirs.ps1 -Force`. Full field reference: [docs/MAINTAINER.md](docs/MAINTAINER.md).

Do not invent variants the vendor never published — it only produces 404s.

---

## ⚠️ Known limitations

| Limitation | Detail |
|---|---|
| Some links embed a version hash | WorkBuddy / Claude / ChatGPT URLs break on each release. Prefer the official page links |
| Claude / Hermes need a proxy | Official CDNs are unreliable from mainland China |
| Codex stub is 813 KB | It is a Microsoft Store stub; the real app downloads on first launch |
| Hermes stub is 7.6 MB | Same — a bootstrapper that fetches the runtime |
| No code signing | Windows SmartScreen will warn. Expected |
| macOS dmgs ship separately | The Windows launcher does not read them |

---

## 📄 Notice

- No installer binaries are hosted here. This project only curates official links and adds convenience.
- All installers remain the property of their vendors; obtain them from official channels and respect their licences.
- Verify file name and publisher before installing.
- Some vendors' CDNs require a proxy from mainland China.

## License

[MIT](LICENSE) — scripts and manifest are free to use, modify and redistribute.
