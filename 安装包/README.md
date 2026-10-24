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
│   ├── Cherry-Studio-2.1.7-win-x64-setup.exe
│   └── Cherry-Studio-2.1.7-win-arm64-setup.exe
└── <其他应用>/
```

**文件名必须和 `sources.json` 里的 `file` 字段完全一致**（大小写和空格都算）。

## 重建目录

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\gen-dirs.ps1 -Force
```

## 注意

- 本目录已在 `.gitignore` 里排除，安装包不会进仓库
- 单个安装包动辄 100+ MB，仓库只放清单和脚本
