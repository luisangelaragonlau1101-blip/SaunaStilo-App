"""One-time recovery signer. Export private material ONLY encrypted to the owner's transport public key.
Never upload the keystore/password, log them, or generate a new key for future updates.
"""
import base64,hashlib,json,os,secrets,subprocess,tempfile
from pathlib import Path
from cryptography.hazmat.primitives import hashes,serialization
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

def run(args,env=None):
    return subprocess.run(args,check=True,env=env,capture_output=True,text=True).stdout

sdk=Path(os.environ.get('ANDROID_HOME') or os.environ['ANDROID_SDK_ROOT'])
tools=sorted((sdk/'build-tools').glob('*/apksigner'),key=lambda p:tuple(int(x) for x in p.parent.name.split('.') if x.isdigit()))[-1].parent
out=Path('recovery-output');out.mkdir(exist_ok=True)
report=Path('recovery-report');report.mkdir(exist_ok=True)
public=serialization.load_pem_public_key(Path('tools/android-recovery/recipient.pub.pem').read_bytes())
with tempfile.TemporaryDirectory() as tmp:
    password=secrets.token_urlsafe(48);env={**os.environ,'SAUNA_KEY_PASSWORD':password};key=Path(tmp)/'sauna-stilo.p12'
    run(['keytool','-genkeypair','-keystore',str(key),'-storetype','PKCS12','-storepass:env','SAUNA_KEY_PASSWORD','-keypass:env','SAUNA_KEY_PASSWORD','-alias','sauna-stilo','-keyalg','RSA','-keysize','3072','-validity','10950','-dname','CN=Sauna Stilo,O=Sauna Stilo,C=MX','-noprompt'],env)
    for inc,name in [(1,'Sauna-Stilo-3.5.1-Android.apk'),(2,'upgrade-test.apk')]:
        raw=Path(tmp)/f'raw-{inc}.apk';aligned=Path(tmp)/f'aligned-{inc}.apk'
        run(['python3','tools/android-recovery/package.py','legacy/Sauna-Stilo-3.5.0-Android.apk',str(raw),'--increment',str(inc)])
        run([str(tools/'zipalign'),'-P','16','-f','4',str(raw),str(aligned)])
        target=(out/name) if inc==1 else Path(name)
        run([str(tools/'apksigner'),'sign','--ks',str(key),'--ks-key-alias','sauna-stilo','--ks-pass','env:SAUNA_KEY_PASSWORD','--key-pass','env:SAUNA_KEY_PASSWORD','--v1-signing-enabled','true','--v2-signing-enabled','true','--v3-signing-enabled','true','--out',str(target),str(aligned)],env)
        signature=run([str(tools/'apksigner'),'verify','--verbose','--print-certs',str(target)])
        run([str(tools/'zipalign'),'-c','-P','16','4',str(target)])
        (report/f'signature-{inc}.txt').write_text(signature)
        (report/f'manifest-{inc}.json').write_text(Path(str(raw)+'.json').read_text())
    cert=run(['keytool','-exportcert','-rfc','-keystore',str(key),'-storepass:env','SAUNA_KEY_PASSWORD','-alias','sauna-stilo'],env)
    payload=json.dumps({'version':1,'package':'com.saunastilo.personal','alias':'sauna-stilo','password':password,'keystoreBase64':base64.b64encode(key.read_bytes()).decode(),'certificatePem':cert}).encode()
    aes=AESGCM.generate_key(bit_length=256);nonce=os.urandom(12)
    encrypted=AESGCM(aes).encrypt(nonce,payload,b'sauna-stilo-signing-v1')
    wrapped=public.encrypt(aes,padding.OAEP(mgf=padding.MGF1(hashes.SHA256()),algorithm=hashes.SHA256(),label=None))
    (out/'signing-backup.encrypted.json').write_text(json.dumps({'format':'RSA-OAEP-SHA256+AES-256-GCM','wrapped':base64.b64encode(wrapped).decode(),'nonce':base64.b64encode(nonce).decode(),'ciphertext':base64.b64encode(encrypted).decode()}))
    (report/'public-certificate.pem').write_text(cert)
    (report/'sha256.txt').write_text(hashlib.sha256((out/'Sauna-Stilo-3.5.1-Android.apk').read_bytes()).hexdigest()+'  Sauna-Stilo-3.5.1-Android.apk\n')
print('Recovery APK aligned and signature verified. Backup contains only encrypted private material.')
