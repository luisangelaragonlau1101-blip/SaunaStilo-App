"""Build a side-by-side recovery edition without decompiling or changing application code.
The legacy signing keys were not retained. This is NOT an in-place migration.
All original DEX, Flutter libraries, assets and Firebase configuration stay byte-identical.
"""
import argparse, hashlib, json, re, struct, zipfile
from pathlib import Path
OLD = 'com.saunastylo.saunastylo'
NEW = 'com.saunastilo.personal'
EXPECTED = '7374296c4b4a2474d64a10bf156a2a80e6442b7cb49d17d67fbc684a66153be3'

def manifest(data, increment=1):
    assert struct.unpack_from('<HH', data) == (3, 8)
    chunks=[]; p=8; strings=None; report={}
    while p<len(data):
        typ, header, size=struct.unpack_from('<HHI',data,p)
        assert size>=header and p+size<=len(data)
        c=bytearray(data[p:p+size])
        if typ==1:
            count,styles,flags,start,style_start=struct.unpack_from('<5I',c,8)
            assert styles==0 and style_start==0 and flags&0x100==0, 'Unexpected string-pool encoding; do not guess.'
            offsets=struct.unpack_from('<%dI'%count,c,header)
            strings=[]
            for offset in offsets:
                q=start+offset;length=struct.unpack_from('<H',c,q)[0];q+=2
                if length&0x8000:
                    length=((length&0x7fff)<<16)|struct.unpack_from('<H',c,q)[0];q+=2
                strings.append(bytes(c[q:q+length*2]).decode('utf-16le'))
            assert OLD in strings and OLD+'.MainActivity' in strings and 'Sauna Stilo' in strings
            updated=[];renamed=[]
            for value in strings:
                replacement=value
                if value==OLD: replacement=NEW
                elif value.startswith(OLD+'.') and value!=OLD+'.MainActivity': replacement=NEW+value[len(OLD):]
                elif value=='Sauna Stilo': replacement='Sauna Stilo Nueva'
                elif value=='3.5.0': replacement='3.5.'+str(increment)
                if replacement!=value:renamed.append([value,replacement])
                updated.append(replacement)
            blocks=bytearray();new_offsets=[]
            for value in updated:
                raw=value.encode('utf-16le');n=len(raw)//2;assert n<0x8000
                new_offsets.append(len(blocks));blocks+=struct.pack('<H',n)+raw+b'\0\0'
            blocks+=b'\0'*((-len(blocks))%4)
            begin=28+4*count
            c=bytearray(struct.pack('<HHI5I',1,28,begin+len(blocks),count,0,0,begin,0)+struct.pack('<%dI'%count,*new_offsets)+blocks)
            report['manifestStringsChanged']=renamed
        elif typ==0x102:
            assert strings is not None
            _,name,attr_start,attr_size,attr_count=struct.unpack_from('<IIHHH',c,16)
            if strings[name]=='manifest':
                for i in range(attr_count):
                    a=16+attr_start+i*attr_size
                    attr_name=struct.unpack_from('<I',c,a+4)[0]
                    if strings[attr_name]=='versionCode':
                        assert c[a+15]==0x10
                        previous=struct.unpack_from('<I',c,a+16)[0]
                        struct.pack_into('<I',c,a+16,previous+increment)
                        report['oldVersionCode']=previous;report['newVersionCode']=previous+increment
        chunks.append(bytes(c));p+=size
    result=b''.join(chunks)
    assert report.get('newVersionCode') and report.get('manifestStringsChanged')
    return struct.pack('<HHI',3,8,len(result)+8)+result,report

def build(source,destination,increment):
    raw=Path(source).read_bytes();assert hashlib.sha256(raw).hexdigest()==EXPECTED,'Source is not the reviewed APK 3.5.0.'
    with zipfile.ZipFile(source) as src:
        patched,report=manifest(src.read('AndroidManifest.xml'),increment)
        with zipfile.ZipFile(destination,'w') as dst:
            for entry in src.infolist():
                if re.match(r'^META-INF/(?:[^/]+\.(?:SF|RSA|DSA|EC)|MANIFEST\.MF)$',entry.filename,re.I):continue
                content=patched if entry.filename=='AndroidManifest.xml' else src.read(entry.filename)
                item=zipfile.ZipInfo(entry.filename,entry.date_time);item.compress_type=entry.compress_type;item.external_attr=entry.external_attr
                dst.writestr(item,content)
        with zipfile.ZipFile(destination) as out:
            unchanged=0
            for entry in src.infolist():
                if entry.filename=='AndroidManifest.xml' or re.match(r'^META-INF/(?:[^/]+\.(?:SF|RSA|DSA|EC)|MANIFEST\.MF)$',entry.filename,re.I):continue
                assert out.read(entry.filename)==src.read(entry.filename),entry.filename
                unchanged+=1
            assert out.testzip() is None
    report.update({'sourceSha256':EXPECTED,'package':NEW,'oldPackage':OLD,'label':'Sauna Stilo Nueva','unchangedPayloadFiles':unchanged,'migration':'side-by-side; legacy data is not copied or deleted','version':'3.5.'+str(increment)})
    Path(str(destination)+'.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('source');p.add_argument('destination');p.add_argument('--increment',type=int,default=1)
    a=p.parse_args();assert a.increment in (1,2);build(a.source,a.destination,a.increment)
