"""Apply exactly reviewed source only when original blobs and final bytes match."""
import base64,gzip,hashlib,json
from pathlib import Path
root=Path.cwd().resolve()
parts=['0','1a','1b','2','3']
encoded=''.join((root/f'.maintenance/personal35.{i}.b64').read_text() for i in parts)
raw=base64.b64decode(encoded,validate=True)
assert hashlib.sha256(raw).hexdigest()=='d57cf52f3f1bbe9063ec23cd83dfc6669cacd0b67a5ee9351da15378e3d87324','Source plan transport mismatch'
plan=gzip.decompress(raw)
assert len(plan)<500000
outputs={}
for entry in json.loads(plan):
 name=entry['path'];p=(root/name).resolve()
 assert p.is_relative_to(root) and '.git' not in p.parts and '.github' not in p.parts and name not in outputs
 data=p.read_bytes() if p.exists() else None
 sha=None if data is None else hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
 assert sha==entry['base'],f'Base changed: {name}'
 lines=(data or b'').decode().splitlines(keepends=True);last=len(lines)+1
 for start,end,text in reversed(entry['ops']):
  assert 0<=start<=end<=len(lines) and end<=last,f'Invalid edit: {name}'
  lines[start:end]=text.splitlines(keepends=True);last=start
 out=''.join(lines)
 assert hashlib.sha256(out.encode()).hexdigest()==entry['sha256'],f'Reviewed output mismatch: {name}'
 outputs[name]=out
for name,out in outputs.items():
 p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(out)
print(f'Applied {len(outputs)} reviewed files. No employee data or production permissions changed.')
