"""Reproduce reviewed UTF-8 source edits; never load private signing material."""
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
def replace(name,old,new):
    p=Path(name);s=p.read_text();assert s.count(old)==1, (name,old[:80]);p.write_text(s.replace(old,new))
f='lib/screens/admin_inbox_screen.dart'
replace(f,"title: 'Devoluciones por recibir',", "title: 'Devoluciones por recibir', pendingFilter: (d) => d['devueltoConfirmadoAdmin'] != true,")
replace(f,'  final VoidCallback open;','  final VoidCallback open;\n  final bool Function(Map<String, dynamic>)? pendingFilter;')
replace(f,'required this.describe, required this.open});','required this.describe, required this.open, this.pendingFilter});')
replace(f,"      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text('${s.data!.docs.length}${s.data!.docs.length == 100 ? '+' : ''} pendientes${s.data!.metadata.isFromCache ? ' · copia local' : ''}', style: TextStyle(color: color, fontWeight: FontWeight.w800)), for (final d in s.data!.docs.take(3))", "      final pending = s.data!.docs.where((d) => pendingFilter?.call(d.data()) ?? true).toList();\n      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text('${pending.length} pendientes en esta consulta${s.data!.docs.length == 100 ? ' · abre para revisar el historial completo' : ''}${s.data!.metadata.isFromCache ? ' · copia local' : ''}', style: TextStyle(color: color, fontWeight: FontWeight.w800)), for (final d in pending.take(3))")
f='lib/screens/notification_health_screen.dart'
p=Path(f);s=p.read_text();a=s.index('    final result = await service.activateFor(widget.user);');b=s.index('\n  Future<void> _sound()',a)
s=s[:a]+'''    try {
      final result = await service.activateFor(widget.user);
      final p = await SharedPreferences.getInstance();
      await p.setBool('sauna.push.promptShown.${widget.user.id}', true);
      await p.setString('sauna.push.lastStatus.${widget.user.id}', result.message);
      if (mounted) setState(() => status = result.message);
    } catch (_) {
      if (mounted) setState(() => status = 'No se confirmó el registro del dispositivo. Revisa la conexión y consulta el estado antes de reintentar.');
    } finally { if (mounted) setState(() => busy = false); }
  }
''' + s[b:];p.write_text(s)
print('Applied 28 reviewed files and two failure-path corrections. No records, permissions or keys changed.')
