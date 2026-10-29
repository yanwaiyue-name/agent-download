
import json, pathlib, subprocess, os, hashlib, tempfile, time

ROOT = pathlib.Path('.')
src = json.loads((ROOT/'sources.json').read_text(encoding='utf-8'))
ENV = dict(os.environ); ENV['HTTPS_PROXY']='http://127.0.0.1:7897'; ENV['HTTP_PROXY']='http://127.0.0.1:7897'
UA='agent-download-hash/1.0'
CURL=['curl','-sS','-L','--retry','2','--retry-delay','1','--retry-all-errors','-A',UA,'--connect-timeout','20']

todo=[]
for app in src['apps']:
    for key in ('variants','mac'):
        for v in app.get(key) or []:
            u=(v.get('urls') or [None])[0]
            if u and not v.get('sha256'):
                todo.append((app['id'], v, u))

def mb(s):
    try: return float(str(s).replace('MB','').strip())
    except Exception: return 9999.0
todo.sort(key=lambda t: mb(t[1].get('size','')))
print('remaining:', len(todo), flush=True)

end = time.time() + 1500   # 25 分钟
for aid, v, u in todo:
    if time.time() > end:
        print('BUDGET OUT', flush=True); break
    fd,tmp = tempfile.mkstemp(); os.close(fd)
    try:
        r = subprocess.run(CURL+['--max-time','180','-o',tmp,u], capture_output=True, timeout=220, env=ENV)
        if r.returncode==0 and os.path.getsize(tmp)>0:
            h=hashlib.sha256()
            with open(tmp,'rb') as f:
                for c in iter(lambda: f.read(1<<20), b''): h.update(c)
            v['sha256']=h.hexdigest()
            print('HASH', aid, v['file'], v['sha256'][:12], flush=True)
            (ROOT/'sources.json').write_text(json.dumps(src,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        else:
            print('fail', aid, v['file'], r.returncode, flush=True)
    except Exception as e:
        print('err', aid, str(e)[:40], flush=True)
    finally:
        try: os.remove(tmp)
        except Exception: pass

p=sum(1 for a in src['apps'] for k in ('variants','mac') for v in (a.get(k) or []) if v.get('sha256'))
print('FINAL pinned:', p, flush=True)
