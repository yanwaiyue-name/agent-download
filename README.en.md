<p align="center">
  <img src="docs/images/01-首页.png" alt="AI Client Download Center" width="880">
</p>

<h1 align="center">📦 AI Client Download Center</h1>

<p align="center"><strong>Version 1.0</strong></p>

<p align="center">
  <em>Curated official download links for mainstream AI desktop clients,<br>
  with per-architecture guidance so you install the right build the first time.</em>
</p>

<p align="center">
  <a href="https://github.com/yanwaiyue-name/ai-client-download-center/stargazers"><img src="https://img.shields.io/github/stars/yanwaiyue-name/ai-client-download-center?logo=github&label=Stars" alt="Stars"></a>
  <a href="https://github.com/yanwaiyue-name/ai-client-download-center/blob/master/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat" alt="MIT"></a>
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20macOS-0078d4" alt="Platform">
  <img src="https://img.shields.io/badge/software-20%20apps-2ea44f" alt="20 apps">
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

| Software | Intel / AMD | Snapdragon / Kirin | macOS |
|---|---|---|---|
| WorkBuddy (Tencent) | ✅ installer | ⚠️ emulated | ✅ Apple Silicon |
| Claude Desktop | ✅ installer | ⚠️ emulated | ✅ Apple / Intel |
| ChatGPT Desktop (incl. Codex) | ✅ Store stub | ✅ native ARM64 | ✅ Apple / Intel |
| OpenCode Desktop | ✅ installer / portable | ✅ native ARM64 | ✅ Apple / Intel |
| DeepSeek Harness Desktop | ✅ installer | ⚠️ emulated | ✅ Apple / Intel |
| Cherry Studio | ✅ installer / portable | ✅ native ARM64 | ✅ Apple / Intel |
| LobeHub Desktop | ✅ installer | ⚠️ emulated | ✅ Apple / Intel |
| Hermes Agent Desktop | ✅ installer | ⚠️ emulated | ✅ Apple Silicon |
| Watt Toolkit | ✅ installer / portable | ⚠️ emulated | ✅ Apple / Intel |
| CC Switch | ✅ installer / portable | ✅ native ARM64 | ✅ Apple / Intel |
| Open Cowork | ✅ installer | ⚠️ emulated | ✅ Apple Silicon |
| RunJam | ✅ installer | ⚠️ emulated | ✅ Apple / Intel |
| Desktop CC GUI | ✅ installer | ⚠️ emulated | ✅ Apple / Intel |

Official links for every app live in [`sources.json`](sources.json) and in the Chinese README.

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
ai-client-download-center/
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
