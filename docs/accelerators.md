# 加速站说明

本文件公开 `launcher.ps1` 对 GitHub 直链实际使用的加速前缀，便于使用者判断额外信任面。

## 当前使用的加速站

顺序即实际回退顺序，配置在 `sources.json` 顶层 `mirrors` 字段（空串代表直连）：

| 顺序 | 前缀 | 说明 |
|---|---|---|
| 1 | `https://gh-proxy.com/` | 第三方 GitHub 加速代理 |
| 2 | `https://ghfast.top/` | 第三方 GitHub 加速代理 |
| 3 | （直连） | 不使用加速站，直接访问 `github.com` / `api.github.com` |
| 4 | `https://gh.llkk.cc/` | 第三方 GitHub 加速代理（兜底） |

脚本会按这个顺序依次尝试；任意一个成功即停止。修改 `sources.json` 的 `mirrors` 数组即可调整，不需要改脚本。

## 风险说明

- 加速站是**第三方服务**，它与 GitHub 之间可看到下载请求，属于额外信任面。
- 本项目通过 `sources.json` 里记录的 SHA256 对下载文件做完整性校验：哈希不符会删除文件并换下一个源重试，不会把可疑文件交给使用者。
- 只想走 GitHub 官方链路、完全不经过第三方加速站时：

```powershell
pwsh -File .\launcher.ps1 -NoMirror
```

## 哈希校验

```powershell
# 校验已下载文件
pwsh -File .\launcher.ps1 -Verify

# 或直接算单个文件的 SHA256
Get-FileHash -Algorithm SHA256 ".\下载\某文件.exe"
```

哈希来源分两类：上游官方校验清单（如 `SHA256SUMS.txt` / `SHASUMS256.txt`）与维护者下载后自行计算。`scripts/update-hashes.ps1` 会标注来源。

## 加速站失效时

加速站会不定期失效。若多个加速站同时不可用：

1. 优先尝试 `-NoMirror`（需要本机能直连 GitHub）；
2. 或自行在 `sources.json` 的 `mirrors` 数组里替换为可用的加速前缀；
3. 也可使用 Release 中已打包的安装包，避免实时下载。

## 相关文件

- `launcher.ps1` — 加速与下载逻辑（`$script:Mirrors`）
- `sources.json` — `mirrors` 顶层字段
- `scripts/update-hashes.ps1` — 更新 SHA256
