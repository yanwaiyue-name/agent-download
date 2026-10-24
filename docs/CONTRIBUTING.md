# 贡献指南

## 最需要的贡献：补充或修正下载信息

添加一个应用**只需改一个文件**：`sources.json`。

### 1. 确认官方来源

必须是厂商官方渠道：
- 官方网站的下载页
- 官方 GitHub Releases
- 官方 CDN 直链

不接受第三方网盘、聚合站、破解站的链接。

### 2. 加一条 app

```json
{
  "id": "my-app",
  "name": "我的软件",
  "vendor": "厂商名",
  "group": "基础桌面客户端",
  "audience": "适合谁",
  "recommend": false,
  "reason": "推荐理由",
  "desc": "一句话说明",
  "dir": "MyApp",
  "arch": "both",
  "variants": [
    { "arch": "x64", "format": "setup", "file": "MyApp-x64.exe", "size": "120 MB",
      "urls": ["https://example.com/MyApp-x64.exe"] },
    { "arch": "arm64", "format": "setup", "file": "MyApp-arm64.exe", "size": "118 MB",
      "urls": ["https://example.com/MyApp-arm64.exe"] }
  ],
  "page": "https://example.com/download",
  "tip": "安装注意事项"
}
```

字段完整说明见 [MAINTAINER.md](MAINTAINER.md)。

### 3. 关键约束

| 约束 | 原因 |
|---|---|
| `dir` 必须是纯 ASCII，不能带斜杠 | 它是文件夹名，中文在某些解压工具下会乱码 |
| `file` 必须与官方文件名完全一致 | 启动器靠文件名匹配本地离线包 |
| `format` 只填 `msi` / `setup` / `store` / `portable` / `zip` | 决定排序和标签；`.7z` 也填 `zip` |
| **不要给不存在的格式编 variant** | 官方没发 portable 就别写，否则 404 |
| 验证 JSON 语法 | `Get-Content sources.json -Raw \| ConvertFrom-Json` |

### 4. 提交前自检

```powershell
# JSON 语法
$j = Get-Content sources.json -Raw | ConvertFrom-Json; $j.apps.Count

# 脚本语法（必须输出 0）
$e = @(); [void][System.Management.Automation.Language.Parser]::ParseFile("$PWD\launcher.ps1", [ref]$null, [ref]$e); $e.Count

# 目录结构
powershell -ExecutionPolicy Bypass -File .\scripts\gen-dirs.ps1 -Force

# 列表是否正常
powershell -ExecutionPolicy Bypass -File .\launcher.ps1 -Check
```

## 修改脚本

### 编码铁律

| 文件 | 要求 | 违反后果 |
|---|---|---|
| `*.ps1` | **UTF-8 with BOM** | PowerShell 5.1 按 ANSI 解析，中文报 `意外的标记 }` |
| `*.bat` | 文件名纯 ASCII | cmd 代码页问题会导致找不到文件 |

改完验证：

```powershell
$e = @(); [void][System.Management.Automation.Language.Parser]::ParseFile("$PWD\launcher.ps1", [ref]$null, [ref]$e); $e.Count
```

### 不要写裸双横线参数

```powershell
# 错
uv --version

# 对
& cmd @("--version")
```

## PR 检查清单

- [ ] `sources.json` 能正常解析
- [ ] 所有 `.ps1` 语法检查返回 0
- [ ] 没有提交任何安装包（`.exe` / `.msi` / `.dmg` / `.zip`）
- [ ] 新增链接实测可达（能返回 200）
- [ ] `.ps1` 仍是 UTF-8 with BOM

## 报告问题

请附上：
- 操作系统版本与架构
- 哪款软件、哪个格式
- 报错原文（截图或文字）
- `本机检测报告.txt`（如果生成了）
