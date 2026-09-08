"""Prepare an unsigned update to the existing recovery edition for private retained-key signing."""
import hashlib,importlib.util,json,re,zipfile
from pathlib import Path
p=Path('build/app/outputs/flutter-apk')
files=list(p.glob('*.apk'))
assert len(files)==1, [str(x) for x in files]
spec=importlib.util.spec_from_file_location('recovery','tools/android-recovery/package.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
Path('android-report').mkdir(exist_ok=True)
with zipfile.ZipFile(files[0]) as src:
    data,report=m.manifest(src.read('AndroidManifest.xml'),increment=1)
    assert report['newVersionCode']>1788810000
    with zipfile.ZipFile('android-report/un-aligned.apk','w') as dst:
        for e in src.infolist():
            if re.match(r'^META-INF/(?:[^/]+\.(?:SF|RSA|DSA|EC)|MANIFEST\.MF)$',e.filename,re.I):continue
            content=data if e.filename=='AndroidManifest.xml' else src.read(e.filename)
            dst.writestr(e,content)
    with zipfile.ZipFile('android-report/un-aligned.apk') as out:
        assert out.testzip() is None
        for e in src.infolist():
            if e.filename=='AndroidManifest.xml' or re.match(r'^META-INF/(?:[^/]+\.(?:SF|RSA|DSA|EC)|MANIFEST\.MF)$',e.filename,re.I):continue
            assert out.read(e.filename)==src.read(e.filename)
report.update({'version':'3.6.0','package':'com.saunastilo.personal','signing':'unsigned, requires retained certificate 716e331c62be7c4055e8217ebf771da716ed13c87e10bf55bb98f608625b80bf','sourceApkSha256':hashlib.sha256(files[0].read_bytes()).hexdigest()})
Path('android-report/manifest-patch.json').write_text(json.dumps(report,indent=2))
