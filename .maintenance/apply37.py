import hashlib,re,subprocess,tempfile,zlib
from pathlib import Path
packed=b''.join(Path(f'.maintenance/ops37.{i}.bin').read_bytes() for i in range(5))
assert hashlib.sha256(packed).hexdigest()=='b8a8e2de3865c5e0db044f7f373e3de3b464dd06d604e5ef02004654a6783452','Transfer integrity failed'
patch=zlib.decompress(packed)
paths=re.findall(rb'^diff --git a/(\S+) b/(\S+)$',patch,re.M)
assert len(paths)==29
for a,b in paths:
    assert a==b and b'..' not in b
    assert b.startswith((b'lib/',b'functions/',b'test/',b'tests/')) or b in [b'tools/activate-team-services.sh',b'OPERATIONS37_STATUS.md',b'OPERATIONS37_DIAGNOSTICS.json']
with tempfile.NamedTemporaryFile(suffix='.patch') as f:
    f.write(patch);f.flush();subprocess.run(['git','apply','--check',f.name],check=True);subprocess.run(['git','apply',f.name],check=True)
print('Applied 29 reviewed source files. No deployment or employee changes.')
