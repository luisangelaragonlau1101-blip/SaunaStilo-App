"""Reproduce exact reviewed UTF-8 source edits, never private signing material."""
import hashlib,lzma,re,subprocess,tempfile
from pathlib import Path
packed=b''.join(Path(f'.maintenance/staff36.{i}.bin').read_bytes() for i in range(5))
assert hashlib.sha256(packed).hexdigest()=='534ff33803f82751bb3b1b2cba75e371fd35585534ff31ba6bcdd2121b9d0be5','Patch transfer integrity mismatch'
patch=lzma.decompress(packed)
paths=re.findall(rb'^diff --git a/(\S+) b/(\S+)$',patch,re.M)
assert len(paths)==28
for left,right in paths:
    assert left==right and (right.startswith((b'lib/',b'test/',b'tests/',b'tools/online-smart34/')) or right in [b'pubspec.yaml',b'STAFF36_RELEASE.md'])
    assert b'..' not in right and b'.git' not in right
with tempfile.NamedTemporaryFile(suffix='.patch') as f:
    f.write(patch);f.flush()
    subprocess.run(['git','apply','--check',f.name],check=True)
    subprocess.run(['git','apply',f.name],check=True)
print('Applied 28 reviewed files. No records, permissions or keys changed.')
