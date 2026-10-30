# 安装包 / Installers

把离线安装包放在这里，启动器会显示「已就绪」，点击直接安装，**全程不联网**。

## 目录结构

按 `sources.json` 里每个应用的 `dir` 字段建子目录：

```
安装包/
├── WorkBuddy/
│   └── WorkBuddy-win32-x64-user-5.8.3.exe
├── Claude Desktop/
│   └── Claude-Setup-x64.exe
├── Cherry Studio/
│   ├── Cherry-Studio-2.1.8-win-x64-setup.exe
│   └── Cherry-Studio-2.1.8-win-arm64-setup.exe
└── <其他应用>/
```

**文件名必须和 `sources.json` 里的 `file` 字段完全一致**（大小写和空格都算）。

## 重建目录

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\gen-dirs.ps1 -Force
```

## 这个目录是空的，这是设计如此

本仓库**不托管任何安装包本体**：

| 原因 | 说明 |
|---|---|
| 体积 | 全套约 6.8 GB，进 git 会让 clone 不可用 |
| 许可 | 部分软件不允许再分发 |
| 时效 | 安装包每周更新，仓库里存副本永远滞后 |

**要现成文件，去 [GitHub Release](https://github.com/yanwaiyue-name/agent-download/releases)。**

想自己准备离线包：按上面的结构把文件放好，启动器会自动识别。
`sources.json` 里每项都标了 `dir`（放哪个文件夹）、`file`（叫什么名字）、`size`（多大）。
