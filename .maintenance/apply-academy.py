"""Apply exact reviewed application edits. No business data or remote credentials."""
from pathlib import Path
import base64, gzip, hashlib, json, runpy
root = Path.cwd().resolve()
encoded = ''.join((root / f'.maintenance/academy.part{i}').read_text().strip() for i in range(5))
raw = gzip.decompress(base64.b64decode(encoded, validate=True))
assert hashlib.sha256(raw).hexdigest() == '234b424eaf61b6368289587e15e86c6437ad80ac38685c0b69d14a046cf31bdd', 'Reviewed plan checksum mismatch'
outputs = {}
for entry in json.loads(raw):
    name = entry['path']; path = (root / name).resolve()
    assert path.is_relative_to(root) and '.git' not in path.parts and '.github' not in path.parts and name not in outputs, name
    data = path.read_bytes() if path.exists() else b''
    actual = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest() if path.exists() else None
    assert actual == entry['base'], f'Base changed: {name}, got {actual}'
    lines = data.decode().splitlines(keepends=True); previous = len(lines) + 1
    for start, end, text in reversed(entry['ops']):
        assert 0 <= start <= end <= len(lines) and end <= previous, name
        lines[start:end] = text.splitlines(keepends=True); previous = start
    value = ''.join(lines)
    assert hashlib.sha256(value.encode()).hexdigest() == entry['out'], f'Result mismatch: {name}'
    outputs[name] = value
for name, value in outputs.items():
    p = root / name; p.parent.mkdir(parents=True, exist_ok=True); p.write_text(value)
fix = root / '.maintenance/academy-fixes.py'
if fix.exists(): runpy.run_path(str(fix))
print(f'Applied {len(outputs)} reviewed source files, with exact base and output validation.')
