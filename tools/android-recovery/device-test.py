"""Only an isolated emulator: no staff accounts, attendance, alarms, or real-device deletion."""
import json,subprocess,time
from pathlib import Path
old='com.saunastylo.saunastylo';new='com.saunastilo.personal'
def adb(*args):return subprocess.run(['adb',*args],check=True,capture_output=True,text=True).stdout
report={}
try:
    assert 'emulator-' in adb('get-serialno'),'Refuse to touch a physical device.'
    adb('root');adb('wait-for-device')
    report['legacyInstall']=adb('install','legacy/Sauna-Stilo-3.5.0-Android.apk').strip()
    adb('shell','mkdir','-p',f'/data/data/{old}/files')
    adb('shell',f"echo legacy-data-preserved > /data/data/{old}/files/sauna-recovery-test.txt")
    report['sideBySideInstall']=adb('install','recovery-output/Sauna-Stilo-3.5.1-Android.apk').strip()
    adb('logcat','-c')
    report['launch']=adb('shell','am','start','-W','-n',new+'/'+old+'.MainActivity')
    time.sleep(14)
    assert 'Status: ok' in report['launch']
    logs=adb('logcat','-d')
    assert 'FATAL EXCEPTION' not in logs,'Runtime crash in emulator.'
    assert new in adb('shell','dumpsys','activity','activities'),'New application not running.'
    report['firebaseErrors']=[line[:500] for line in logs.splitlines() if 'E/Firebase' in line or 'FIS_AUTH_ERROR' in line or 'API_KEY_ANDROID_APP_BLOCKED' in line]
    assert not any('FIS_AUTH_ERROR' in s or 'API_KEY_ANDROID_APP_BLOCKED' in s for s in report['firebaseErrors']), 'Firebase rejected the installation identity.'
    assert 'legacy-data-preserved' in adb('shell','cat',f'/data/data/{old}/files/sauna-recovery-test.txt')
    report['legacyDataPreserved']=True
    adb('shell','mkdir','-p',f'/data/data/{new}/files')
    adb('shell',f"echo new-data-preserved > /data/data/{new}/files/sauna-recovery-test.txt")
    report['sameSignerUpgrade']=adb('install','-r','upgrade-test.apk').strip()
    assert 'new-data-preserved' in adb('shell','cat',f'/data/data/{new}/files/sauna-recovery-test.txt')
    report['newDataPreservedAfterUpgrade']=True
    report['packages']=adb('shell','pm','list','packages','sauna').strip().splitlines()
    report['success']=True
finally:
    Path('recovery-report/device-test.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
