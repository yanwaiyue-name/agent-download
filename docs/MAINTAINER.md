# 维护说明（给你自己看，不要随包发给使用者）

> 当前版本 **v3.0**（2026-10-23）。相对 v2.2 的三处大改：
> 1. **Hermes 有桌面版了** —— 官方现在提供 Windows `.exe` 和 macOS `.dmg`，不再只有 CLI。
> 2. **同一软件支持多种格式** —— 安装版 / MSI / 免安装 / 压缩包 / 商店版，启动器让使用者自己选。
> 3. **安装包已全部下好** —— 12 个软件的 Windows 全格式包都在 `安装包/` 里，macOS 包在 `安装包/<应用>/mac/`。

## 一、目录结构

```
desktop-agent-installer/
├── 双击启动.bat        ← 使用者点这个下载/安装（内容纯 ASCII，不要加中文进去）
├── 双击检测.bat        ← 使用者点这个查本机架构和可装版本
├── launcher.ps1        ← 安装主逻辑（UTF-8 带 BOM，改完必须保持 BOM）
├── check-pc.ps1        ← 系统检测逻辑（同上，文件名保持 ASCII）
├── sources.json        ← 应用清单、格式、官方下载源（唯一数据源）
├── 使用说明.txt        ← 给使用者看的操作说明
├── 软件推荐与官方下载地址.txt ← 给使用者看的推荐表和官网直链
├── 打包.ps1            ← 【给你用】生成 买家版/ 并压成 ZIP，不删任何现有文件
├── gen-dirs.ps1        ← 【给你用】按 sources.json 重建安装包子目录 + 放这里.txt
├── 补全安装包.ps1      ← 【给你用】按 sources.json 把每种格式都下全（含 -Mac）
├── 维护说明.md         ← 本文件
├── 下载地址总表.md     ← 【核心】官方直链 + 镜像 + 校验方法（不发货）
├── 买家版/             ← 交付产物（自动生成，可直接发给使用者）
├── AI桌面下载中心_买家版_v*.zip ← 交付产物（自动生成）
├── 安装包/             ← 离线安装包（真实文件）
│   ├── <应用>/*.exe|*.msi|*.zip        ← Windows 全格式
│   └── <应用>/mac/*.dmg                ← macOS 包（默认不进发布包）
├── 下载/               ← 启动器运行时下载的缓存（结构同上）
├── 日志.txt            ← 启动器运行记录，含 SHA256（自动生成）
├── 下载日志.txt        ← 补全安装包.ps1 的记录（自动生成）
└── 本机检测报告.txt    ← 检测结果（自动生成，使用者会回传给你）
```

旧版 `官方下载地址.txt` 已由 `软件推荐与官方下载地址.txt` 取代；v2.1 旧快照在 `_scratch/backups/`。
打包白名单不会带这些目录，也不要手压整个文件夹发货。

**为什么按应用分子目录**：同一个软件常有 x64 / arm64 两套、还分安装版和免安装，
堆在一起容易拿错；使用者看到一堆 exe 也不知道点哪个。分开放之后，
更新某个软件只需要替换它自己文件夹里的文件，不影响别的。

`launcher.ps1` 的查找顺序是：**应用子目录 → 根目录 → 全递归兜底**，
所以使用者自己建了别的文件夹结构也能找到，老版本（文件直接堆在 `安装包/` 根目录）也照样能用。

⚠️ **两个 .ps1 必须保持 ASCII 文件名**。`.bat` 里用 `%~dp0xxx.ps1` 引用，
中文文件名在 cmd 里可能因代码页问题找不到文件。`.bat` 本身可以叫中文名。
`补全安装包.ps1` 也是中文名，但它只给你自己在 PowerShell 里跑，不经过 .bat，所以没问题。

## 二、这个包的真实价值在哪

工具本身的"自动下载"功能，对 Claude / Hermes 这类被墙的应用是**救不了的**——安装包在国外 CDN 上，没有国内镜像。

**真正值钱的是「离线包」模式**：

1. 你自己用代理把所有安装包下好（`补全安装包.ps1` 一键下全格式）
2. 丢进 `安装包/` 对应文件夹
3. 整个文件夹压成 zip 分发
4. 使用者双击 → 全部显示「已就绪」→ 点一下就装，**全程不联网**

好处：使用者不需要任何网络条件；无需重复答疑；一次准备可分发无限份。

## 三、准备 / 更新离线包

```powershell
# 1. 建好目录结构（改了 sources.json 之后也要重跑）
powershell -ExecutionPolicy Bypass -File .\gen-dirs.ps1 -Force

# 2. 下全所有格式（Windows）
powershell -ExecutionPolicy Bypass -File .\补全安装包.ps1

#    连 macOS 的 dmg 一起下（约多 3.2 GB）
powershell -ExecutionPolicy Bypass -File .\补全安装包.ps1 -Mac

#    只补某几个（id 见 sources.json）
powershell -ExecutionPolicy Bypass -File .\补全安装包.ps1 -Only cherry,hermes

# 3. 验证状态
powershell -ExecutionPolicy Bypass -File .\launcher.ps1 -Check
```

全部显示「已就绪」就可以打包了。

`补全安装包.ps1` 的行为：
- 按 `sources.json` 的 `variants` 逐个下，**每种格式都下**（`sums` 跳过）
- 加 `-Mac` 才下 `mac` 数组里的 dmg，放到 `安装包/<dir>/mac/`
- 已有文件默认跳过；加 `-Force` 强制重下
- GitHub 直链自动套加速前缀（gh-proxy.com → ghfast.top → 直连 → gh.llkk.cc）
- **代理自动探测**：`-Proxy` 参数 > 环境变量 > 系统代理设置 > 探测本机 7897/7890/10809/1080/8080 端口。国内直连 GitHub 基本不通，探测不到代理时脚本会用黄字提醒
- 每个文件下完打 SHA256 到 `下载日志.txt`
- 失败的会在结尾列清单，附官方页面，手动补

先确认计划对不对（不下载，只列目标和来源）：

```powershell
powershell -ExecutionPolicy Bypass -File .\补全安装包.ps1 -Mac -DryRun
```

输出末尾会给「共 N 个文件：新下载 x，已有 y，失败 0」，和 `launcher.ps1 -Check` 的数量应该对得上。

### 打包发货（一键，别手动压）

```powershell
powershell -NoProfile -File .\打包.ps1                  # 只做 Windows 版（推荐日常用）
powershell -NoProfile -File .\打包.ps1 -MacOnly         # 只做 macOS 版（给 macOS 使用者）
powershell -NoProfile -File .\打包.ps1 -Mac             # 全平台混合包（Win+mac 装一个包）
powershell -NoProfile -File .\打包.ps1 -Slim            # 精简：每个架构只带默认格式
powershell -NoProfile -File .\打包.ps1 -NoZip           # 只生成目录，不压缩
```

**为什么默认拆成两个包**：Windows 使用者用不到 3.2 GB 的 dmg，macOS 使用者也用不到 2.5 GB 的 exe；
而且不少网盘单文件限制 4 GB，混成一个 5.8 GB 的包反而传不上去。
按平台各发一个，体积砍一半，上传也顺。

它做四件事：

1. **检查运行文件** —— 7 个运行/说明文件必须都在，缺一个就报错停止（`-MacOnly` 跳过，因为 macOS 包不需要 Windows 启动器）
2. **新建交付目录** —— 目标已存在时默认报错（不覆盖、不删除旧交付物）；加 `-Force` 会自动把旧目录改名归档为 `<目录名>_旧_<时间戳>` 再重新生成
3. **按需复制离线包** —— `安装包\` 里只有真实 `.exe`/`.msi`/`.zip`/`.dmg`（>200KB）时才复制，**只复制安装程序本体**（`放这里.txt` 这类维护者说明不会进包）。
   - 默认**跳过 `mac\` 子目录**；`-Mac` / `-MacOnly` 才带，且会实际数一遍 dmg，**一个都没复制到就直接报错**
   - `-MacOnly` 会把 dmg **摊平**到 `安装包\<应用>\`（不再有 `mac\` 子目录），并额外生成 `使用说明_macOS.txt`（芯片怎么选、怎么拖进应用程序、被 Gatekeeper 拦了怎么办）
   - `-Slim` 每个应用每个架构只留默认格式（`msi`>`dmg`>`setup`>`store`>`portable`>`zip`），实测 Windows 包 2884 MB → 2131 MB
4. **生成校验清单 + 安全检查 + 压缩** —— 给每个安装包算 SHA256 写进 `校验清单.txt`；扫描内部信息关键词（报价/价格/定价/货源/策略等），确认无泄露后压成带时间戳的 ZIP

产出文件名自带平台和精简标签，不会发错货：

| 命令 | 产出 | 体积（实测） |
|---|---|---|
| `.\打包.ps1` | `..._v3.0_Windows版_<时间>.zip` | 2884 MB（`-Slim` 后 2131 MB） |
| `.\打包.ps1 -MacOnly` | `..._v3.0_macOS版_<时间>.zip` | 3259 MB |
| `.\打包.ps1 -Mac` | `..._v3.0_全平台_<时间>.zip` | 6143 MB |

### 使用者侧自检（`launcher.ps1 -Verify`）

包里带 `校验清单.txt` 后，使用者可以在启动器里输 `V`，或直接：

```powershell
powershell -NoProfile -File .\launcher.ps1 -Verify
```

逐个核对 SHA256，输出「完好 N / 缺失 N / 损坏 N」，损坏的会明确列出文件名。
用途：网盘或 QQ 传大文件偶尔截断，装到一半才报错；先校验能提前发现。实测 2.9 GB 约 4 秒。

`买家版\` 里只有这 7 个文件（+ `安装包\`、`校验清单.txt`）：

```
双击启动.bat
双击检测.bat
launcher.ps1
check-pc.ps1
sources.json
使用说明.txt
软件推荐与官方下载地址.txt
校验清单.txt          （有离线包时才生成）
```

**维护者专用、绝不会进包**：`维护说明.md`、`下载地址总表.md`、`gen-dirs.ps1`、`补全安装包.ps1`、`打包.ps1`、`日志.txt`、`下载日志.txt`、`本机检测报告.txt`、`下载/`。

⚠️ **不要手动右键压整个文件夹** —— 那样会把 `维护说明.md`（含内部定价信息）和 `下载地址总表.md`（含内部来源信息）一起发给使用者。

## 四、增删应用 / 增删格式

只改 `sources.json` 的 `apps` 数组。v3.0 起每个应用用 `variants` 列出**每种架构的每种格式**：

| 字段 | 层级 | 说明 |
|---|---|---|
| `id` | app | 唯一标识，也是模糊匹配本地安装包文件名的关键词（匹配时忽略大小写和符号） |
| `name` | app | 列表里显示的名字 |
| `desc` | app | 一句话用途 |
| `group` | app | 列表分组：`基础桌面使用者端` / `Agent 管理与工作台` |
| `audience` | app | **适合谁**，显示在列表和检测报告里 |
| `recommend` | app | `true` 时列表显示"推荐"标记 |
| `reason` | app | 推荐理由/用途说明，显示在检测报告里 |
| `dir` | app | **安装包子文件夹名**，如 `"OpenCode"`。纯 ASCII，不要带斜杠 |
| `arch` | app | 该应用支持的架构概览：`x64` / `arm64` / `both` / `any` |
| `github` | app | 形如 `owner/repo`，自动查最新 release |
| `page` | app | 官方页面，失败时兜底打开 |
| `tip` | app | 失败时显示的提示 |
| `variants` | app | 数组，**每个元素是一种架构的一种格式** |
| `variants[].arch` | variant | `x64` / `arm64` / `any` |
| `variants[].format` | variant | `msi` / `setup` / `store` / `portable` / `zip`（`sums`、`dmg` 不会被当成安装程序）。**`.7z` 文件也填 `zip`**：格式值只决定排序和标签，真正判断怎么处理看文件扩展名 |
| `variants[].file` | variant | 本地保存文件名（放 `安装包/` 时必须叫这个） |
| `variants[].size` | variant | 显示用的大小，如 `"296.4 MB"` |
| `variants[].assetPattern` | variant | 正则，从 release 资产里筛对应文件；**匹配不上就放弃 API 结果，转用 urls** |
| `variants[].urls` | variant | 静态直链候选，按顺序尝试 |
| `mac` | app | 数组，macOS 包（`arch` / `format` / `file` / `size` / `urls`），放 `安装包/<dir>/mac/`，Windows 启动器不读 |
| `runtimeCheck` | app | 可选。`webview2` / `vcredist` / `netfx`。有这个字段的条目会被 `check-pc.ps1` 当成**运行环境**，用注册表实际检测结果判断「已装/缺失」，而不是去「已安装程序」列表里找 |

**格式优先级（launcher.ps1 / check-pc.ps1 里的 $FormatRank）**：

```
msi(1) → dmg(1) → setup(2) → store(3) → portable(4) → zip(5)
```

数字越小越优先，**默认选最小的那个**。使用者可以在列表里手动换格式。

### 运行环境分组（`runtimeCheck`）

`安装包/运行环境/` 下有三个运行库，`sources.json` 里是三个独立 app，但**共用一个 `dir`**：

| id | 文件 | 用途 |
|---|---|---|
| `webview2-online` | `MicrosoftEdgeWebview2Setup.exe` | 1.8 MB 引导器，Tauri 应用（CC Switch 等）白屏时用，装时需联网 |
| `webview2-offline` | `MicrosoftEdgeWebView2RuntimeInstallerX64.exe` | 204.9 MB 离线完整包，使用者电脑不能上网时用 |
| `vcredist` | `VC_redist.x64.exe` | VC++ 2015-2022 运行库，报「缺少 VCRUNTIME140.dll」时装 |

注意两点：

1. **多个 app 共用 `dir` 时，`gen-dirs.ps1` 会自动改用合并版说明**（`Build-ReadmeMulti`），把所有应用列进同一份 `放这里.txt`；否则后写的会覆盖先写的。
2. `check-pc.ps1` 会把 `runtimeCheck` 的条目**排除在「能装 N 个软件」之外**，避免结论虚高。

### 开发环境分组

`安装包/开发环境/` 里是 4 个开发环境、共 8 个安装包（每个都有 x64 + ARM64），同样**共用一个 `dir`**：

| id | 版本 | 文件 | 定位 |
|---|---|---|---|
| `python` | 3.13.10 | `python-3.13.10-amd64.exe` / `-arm64.exe` | 跑 .py 脚本、pip 装包 |
| `nodejs` | 24.22.1 LTS | `node-v24.22.1-x64.msi` / `-arm64.msi` | Claude Code、opencode CLI 等 npm 工具 |
| `git` | 2.56.0.3 | `Git-2.56.0.3-64-bit.exe` / `-arm64.exe` | 克隆仓库、git 命令 |
| `7zip` | 25.01 | `7z2501-x64.exe` / `-arm64.exe` | 解 `.7z`（Watt 免安装版需要） |

**和「运行环境」的区别**：运行环境是桌面软件**缺了就打不开**的底层库（WebView2/VC++）；开发环境是**可选**的，桌面软件自带运行时，只有要用命令行工具才装。`使用说明.txt` 里已按这个逻辑分开写。

**镜像优先**：`python.org` 国内实测 11 KB/s，`nodejs.org` 约 200 KB/s，所以 `urls` 里把镜像放第一个、官方源兜底：

```
Python  -> https://mirrors.huaweicloud.com/python/3.13.10/      （实测 1.8 MB/s）
Node    -> https://registry.npmmirror.com/-/binary/node/v24.22.1/（实测 2.1 MB/s）
Git     -> github.com/git-for-windows/git/releases + 加速前缀
7-Zip   -> github.com/ip7z/7zip/releases + 加速前缀
```

**两个坑**：

1. **Git 的 tag 与资产名不一致**：tag 是 `v2.56.0.windows.3`，资产名却是 `Git-2.56.0.3-64-bit.exe`。按资产名拼 tag 会 404
2. **Python 安装器默认不勾 PATH**：`Add python.exe to PATH` 必须手动勾，否则命令行找不到 `python`。这条已写进 `使用说明.txt`

**故意没收的**：Java / Go / Rust / .NET SDK / Docker / WSL —— 本清单没有任何软件需要它们，体积大且装完可能要重启。链接在 `下载地址总表.md` 里。

**本清单的 12 个桌面软件都不需要 Python / Node.js** —— 它们自带运行环境。Python 只在维护者侧用（`_scratch/fetch-packs.py` 批量下载），Node 只在用 opencode / hermes 的**命令行版**时才需要。

**架构选择规则**：

1. 本机 `x64` → 只用 `arch=x64` 的 variant
2. 本机 `arm64` → 优先 `arch=arm64`，没有则退回 `arch=x64`（标记为「模拟运行」）
3. 本机 `x86`（32 位）→ 一律不匹配，全部标「装不了」
4. 一个 variant 都没有 → 标「无桌面版」

**新增一个多格式应用**（照抄 Cherry Studio 那一段最省事）：

```json
{
  "id": "myapp",
  "name": "My App",
  "vendor": "Vendor",
  "desc": "一句话说明",
  "dir": "My App",
  "arch": "both",
  "github": "owner/repo",
  "variants": [
    { "arch": "x64",   "format": "setup", "file": "MyApp-x64-setup.exe",  "size": "100 MB", "assetPattern": "win-x64-setup\\.exe$",  "urls": [] },
    { "arch": "x64",   "format": "portable","file": "MyApp-x64-portable.exe","size": "99 MB", "assetPattern": "win-x64-portable\\.exe$", "urls": [] },
    { "arch": "arm64", "format": "setup", "file": "MyApp-arm64-setup.exe","size": "95 MB", "assetPattern": "win-arm64-setup\\.exe$", "urls": [] }
  ],
  "mac": [
    { "arch": "arm64", "format": "dmg", "file": "MyApp-arm64.dmg", "size": "110 MB", "urls": [] }
  ],
  "page": "https://github.com/owner/repo/releases",
  "tip": "GitHub release 可走加速站"
}
```

加完跑一次 `gen-dirs.ps1 -Force`，新应用的文件夹和 `放这里.txt` 才会建出来。

⚠️ **不要给不存在的架构/格式编 variant**。官方没发 portable 就别写 portable，写上去只会让使用者 404。

## 五、改 launcher.ps1 的注意事项

1. **必须保存为 UTF-8 with BOM**。否则 Windows PowerShell 5.1 按 ANSI 解析，中文会报 `意外的标记 }`。
2. **不要写 `uv --version` 这种裸双横线参数**，`--` 会被当运算符；用 `& cmd @("--version")`。
3. 改完验证语法：

```powershell
$e = @(); [void][System.Management.Automation.Language.Parser]::ParseFile("$PWD\launcher.ps1", [ref]$null, [ref]$e); $e.Count
# 输出 0 表示没问题
```

4. 改完跑一次 `-Check` 看列表是否正常。

## 六、已知限制（如实说明，不要过度承诺）

| 限制 | 说明 |
|---|---|
| 三家直链带版本号 | WorkBuddy / Claude / ChatGPT 的直链含版本哈希，新版发布后旧链接失效，需按「下载地址总表.md」第八节刷新 |
| Claude / Hermes 需要代理 | `downloads.claude.ai`、`hermes-assets.nousresearch.com` 国内直连不稳，本机是走代理下好的 |
| Codex 的 exe 只有 813KB | 是微软商店引导器，双击后还要联网拉主程序；要纯离线需自备 msixbundle |
| Hermes 的 exe 只有 7.6MB | 同样是引导器，首次启动联网拉运行时；**但它确实有桌面版了**，别再写"只有 CLI" |
| GitHub 走加速站 | `/releases/latest/download/` 形式永不过期；gh-proxy.com、ghfast.top、gh.llkk.cc 可用，ghproxy.net、hub.gitmirror.com 已失效 |
| 安装包无微软签名 | 使用者会看到 SmartScreen 警告，属正常，说明书里已解释 |
| MSI 文件头不是 MZ | MSI 是 OLE 复合文档（`D0 CF 11 E0`）。v2.2 的 `Test-InstallerMagic` 只认 MZ，会把所有 MSI 判成"下载失败"——v3.0 已修 |

## 七、合规提醒

- 分发的必须是**官方原版安装包**，不要改包、不要夹带
- 不要打"破解""免费无限用"的旗号 —— 这些软件本身免费，本工具提供的是打包与安装便利
- 建议在说明书里注明"安装包来源为各厂商官方渠道，本工具仅提供下载与安装便利"