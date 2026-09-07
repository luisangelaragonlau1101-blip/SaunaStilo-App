"""Apply exact reviewed source edits, checking original Git blob and final SHA-256."""
import json,hashlib,re
from pathlib import Path
root=Path.cwd().resolve()
outputs={}
for entry in json.loads(Path('.maintenance/company34-plan.json').read_text()):
 p=(root/entry['path']).resolve()
 if not p.is_relative_to(root) or '.git' in p.parts:raise ValueError('Unsafe source path')
 data=p.read_bytes() if p.exists() else None
 actual=None if data is None else hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
 if actual!=entry['base']:raise ValueError(f"Base changed: {entry['path']}")
 lines=(data or b'').decode().splitlines(keepends=True)
 last=len(lines)+1
 for start,end,text in reversed(entry['ops']):
  if not 0<=start<=end<=len(lines) or end>last:raise ValueError('Invalid source edit')
  lines[start:end]=text.splitlines(keepends=True);last=start
 out=''.join(lines)
 if hashlib.sha256(out.encode()).hexdigest()!=entry['sha256']:raise ValueError(f"Final source hash differs: {entry['path']}")
 outputs[p]=out
for p,out in outputs.items():p.parent.mkdir(parents=True,exist_ok=True);p.write_text(out)
# Lock the alarm button before its confirmation opens: two taps must not open two dialogs.
p=Path('lib/screens/admin_alerta_general_screen.dart');s=p.read_text();anchor='  try{\n   final payloads='
assert s.count(anchor)==1
p.write_text(s.replace(anchor,'  setState(()=>_sending=true);\n  try{\n   final payloads='))
# Reuse the exact existing course vocabulary rather than duplicating a second curriculum.
s=Path('lib/academy/lesson_catalog.dart').read_text();raw=re.search(r"const _catalog = r'''(.*?)''';",s,re.S).group(1)
lessons=json.loads(raw);courses={l:[{'id':x['id'],'pairs':x['pairs']} for x in lessons if x['language']==l]for l in ['en','fr']}
Path('tools/online-smart34/courses.mjs').write_text('export const courses = '+json.dumps(courses,ensure_ascii=False,separators=(',',':'))+';\n')
print('Applied verified 3.4 source; no user records or permissions were changed.')
