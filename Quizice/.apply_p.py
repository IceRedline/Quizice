import difflib,json,re
from pathlib import Path
facts=undefined
for rel in ('data.json','ru.lproj/data.json'):
 p=Path(__file__).parent/rel; b=p.read_text(); d=json.loads(b); s=next(x for x in d if x['id']=='politics_business'); vals=iter([f"**{s['questions'][i]['correctAnswer']}** — {facts[i-54]}" for i in range(54,81)]); dec,pos=json.JSONDecoder(),b.index('[')+1
 while 1:
  pos=len(b)-len(b[pos:].lstrip()); o,e=dec.raw_decode(b,pos)
  if o.get('id')=='politics_business': a,z=pos,e;break
  pos=b.index(',',e)+1
 n=[0]
 def f(m):
  n[0]+=1; return m.group(1)+(json.dumps(next(vals),ensure_ascii=False) if 55<=n[0]<=81 else m.group(0)[len(m.group(1)):])
 x=re.sub(r'("explanation"\s*:\s*)"(?:\\\\.|[^"\\\\])*"',f,b[a:z]); out=b[:a]+x+b[z:]; print(''.join(difflib.unified_diff(b.splitlines(True),out.splitlines(True),fromfile=str(p),tofile=str(p))),end='')
