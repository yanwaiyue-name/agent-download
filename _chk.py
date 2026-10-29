
import json, pathlib, re

ROOT = pathlib.Path('.')
src = json.loads((ROOT/'sources.json').read_text(encoding='utf-8'))

# 从日志恢复所有已成功的哈希（12位前缀无法还原完整值，需重新用官方清单补全）
p = ROOT/'sources.json'
n = 0
for a in src['apps']:
    for k in ('variants','mac'):
        for v in a.get(k) or []:
            if v.get('sha256'): n += 1
print('sha256 in json:', n)
