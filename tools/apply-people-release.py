"""Apply reviewed plain-text source edits only to exactly matching base files."""
import hashlib
import json
from pathlib import Path
import subprocess

root = Path.cwd().resolve()
outputs = {}
expected = {'.github/workflows/team-release-review.yml':'95726606844dc48602abafa724dbfa3197a5c27c83a5c066a77e9463553e907c','PEOPLE_RELEASE.md':'9467c26ed88bbf97d3610269b655840255535a402a684a098aab90a0720648d0','firestore.rules':'d13eddf480090fae630c3098c9a6a3648866d4d74999ba76682e2d7e3788f4a5','lib/screens/calendario_cumpleanos_screen.dart':'b4c4909787d9c7af3c50b251a7d2c464e281d2717d26f43b5cbf0c2a7ecdfcae','lib/screens/futuristic_dashboard_screen.dart':'d70cd161cd16108aa039a2fe29ae61867320b4dbc4ab9feb982342c2bef1c2c0','lib/screens/justificar_falta_screen.dart':'c618a0f67a032bf1016ad1af75c3259ccd4b48a3b1f134ef65f862c26c02a497','lib/screens/operations_shell.dart':'dfc82d66e9ccd17a0ecf8352e12fa3aae0a2ad679b7f9ca80752697024ac54c7','lib/screens/perfil_social_screen.dart':'80f79dcedd4dddb058a16f393744c45b9eb371779d24aa980dcf5abb54628b5c','lib/screens/perfiles_equipo_screen.dart':'7d93f348564c046bb2cf57f2894804e7169a1a81623ea8e8b5aa742e5f933c34'}
for i in range(4):
    entries = json.loads((root / f'.maintenance/people-plan-{i}.json').read_text())
    for entry in entries:
        name = entry['path']
        path = (root / name).resolve()
        if not path.is_relative_to(root) or '.git' in path.parts or name in outputs:
            raise ValueError(f'Invalid or duplicate source path: {name}')
        data = path.read_bytes() if path.exists() else b''
        actual = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest() if path.exists() else None
        if actual != entry['base']:
            raise ValueError(f'Base changed: {name}; expected {entry["base"]}, got {actual}')
        lines = data.decode('utf-8').splitlines(keepends=True)
        previous = len(lines) + 1
        for start, end, text in reversed(entry['ops']):
            if not 0 <= start <= end <= len(lines) or end > previous:
                raise ValueError(f'Invalid edit range: {name}')
            lines[start:end] = text.splitlines(keepends=True)
            previous = start
        outputs[name] = ''.join(lines)

mismatches = [name for name, value in outputs.items() if name in expected and hashlib.sha256(value.encode()).hexdigest() != expected[name]]
if mismatches:
    Path('smoke-results').mkdir(exist_ok=True)
    Path('smoke-results/apply-output-diagnostic.json').write_text(json.dumps({name:outputs[name] for name in mismatches}, ensure_ascii=False, indent=2))
    raise ValueError(f'Reviewed output mismatch: {mismatches}')
for name, value in outputs.items():
    path = root / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding='utf-8')
subprocess.run(['git','add','--',*outputs.keys()],check=True)
print(f'Applied and staged {len(outputs)} verified source files; no business records changed.')
