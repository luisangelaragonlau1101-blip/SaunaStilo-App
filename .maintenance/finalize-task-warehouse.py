"""Apply bounded source edits to the verified feature branch, never business data."""
from pathlib import Path
import hashlib
root=Path.cwd()
expected={'lib/screens/equipo_tareas_screen.dart':'3579afb44728b23558def3f0974fbe83f9b7c727','lib/screens/modal_asignar_actividades.dart':'a8e6002cf5054ce52c6381b45a8d674b83398ca8','lib/services/actividades_service.dart':'924704fede78ecdd7782716547f181ef040a2636','lib/widgets/project_picker.dart':'ac6619c571b8c6e84683683ba8c3dd82de020dd3','lib/screens/admin_solicitudes_herramientas_screen.dart':'0adad24112cdfe5489c2b6b5f81c0a253bd0096c','lib/screens/insumo_form_screen.dart':'5c961b32008e017226c0af7b8e736f8c01fa6b8c','lib/services/inventario_service.dart':'af7f6f539e4701f33813c85ff0cd63598c7c4940'}
for name,sha in expected.items():
 b=(root/name).read_bytes()
 assert hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==sha, name+' changed'
def edit(name,fn):
 p=root/name;s=p.read_text();out=fn(s);assert out!=s,name+' unchanged';p.write_text(out)
def once(s,old,new):
 assert s.count(old)==1, repr(old[:120])+': '+str(s.count(old));return s.replace(old,new,1)

def tasks(s):
 s="import '../widgets/task_creation_choice.dart';\n"+s
 pos=s.index('  Future<void> _seleccionarProyecto')
 s=s[:pos]+'''  Future<void> _crearTarea() async {
    if (!_puedeAsignar) return;
    if (!_admin) { await _seleccionarProyecto(crear: true); return; }
    final scope = await showModalBottomSheet<String>(context: context, isScrollControlled: true,
      backgroundColor: const Color(0xFF111012), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (sheet) => TaskCreationChoice(admin: true,
        onGeneral: () => Navigator.pop(sheet, 'general'), onProject: () => Navigator.pop(sheet, 'project')));
    if (!mounted || scope == null) return;
    if (scope == 'project') { await _seleccionarProyecto(crear: true); return; }
    setState(() { _proyectoId = null; _proyectoTitulo = 'Tareas del equipo'; });
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => ModalAsignarActividad(proyectoId: '', rolUsuario: widget.usuario.rol));
  }
''' + s[pos:]
 s=s.replace('onPressed: () => _seleccionarProyecto(crear: true)', 'onPressed: _crearTarea')
 s=once(s,"subtitle: Text('${t.estatus} · ${t.totalEvidencias} evidencias", "subtitle: Text('${t.proyectoId.isEmpty ? 'General' : 'Proyecto'} · ${t.estatus} · ${t.totalEvidencias} evidencias")
 return s
edit('lib/screens/equipo_tareas_screen.dart',tasks)

def form(s):
 start=s.index("      final project = await db.collection('proyectos')")
 end=s.index('      final entries =',start)
 s=s[:start]+'''      final admin = widget.rolUsuario == 'admin';
      var members = <String>[];
      if (widget.proyectoId.isNotEmpty) {
        final project = await db.collection('proyectos').doc(widget.proyectoId).get().timeout(const Duration(seconds: 15));
        members = (project.data()?['encargados'] as List? ?? const []).whereType<String>().toList();
        if (!project.exists || (!admin && (widget.rolUsuario != 'maestro' || !members.contains(_uid)))) {
          throw StateError('Administración debe asignarte como integrante de este proyecto.');
        }
      } else if (!admin) {
        throw StateError('Las tareas generales las asigna Administración. Como maestro, elige uno de tus proyectos.');
      }
      final people = await db.collection('usuarios').get().timeout(const Duration(seconds: 15));
''' + s[end:]
 s=s.replace("'Este proyecto no tiene integrantes activos. Administración puede agregarlos desde Proyectos.'", "widget.proyectoId.isEmpty ? 'No hay personas activas disponibles. Revisa las cuentas del equipo.' : 'Este proyecto no tiene integrantes activos. Administración puede agregarlos desde Proyectos.'")
 s=once(s,"        const SizedBox(height: 15),\n        TextFormField", "        const SizedBox(height: 12),\n        Text(widget.proyectoId.isEmpty ? 'TAREA GENERAL · SIN PROYECTO' : 'TAREA VINCULADA AL PROYECTO', style: const TextStyle(color: Color(0xFFB7FF2A), fontWeight: FontWeight.w700, fontSize: 11)),\n        const SizedBox(height: 15),\n        TextFormField")
 return s
edit('lib/screens/modal_asignar_actividades.dart',form)

def service(s):
 start=s.index("      final project = await tx.get(_db.collection('proyectos')")
 end=s.index('      final old = await tx.get(ref);', start)
 s=s[:start]+'''      final target = await tx.get(_db.collection('usuarios').doc(actividad.asignadoATrabajadorId));
      final role = profile.data()?['rol'];
      if (!profile.exists || profile.data()?['activo'] == false) throw StateError('Tu cuenta no está activa.');
      if (!target.exists || target.data()?['activo'] == false) throw StateError('La persona no tiene una cuenta activa.');
      if (actividad.proyectoId.isNotEmpty) {
        final project = await tx.get(_db.collection('proyectos').doc(actividad.proyectoId));
        final members = (project.data()?['encargados'] as List? ?? const []).whereType<String>().toList();
        if (!project.exists) throw StateError('El proyecto ya no existe.');
        if (role != 'admin' && (role != 'maestro' || !members.contains(uid) || !members.contains(target.id))) {
          throw StateError('El maestro debe estar asignado al proyecto y elegir a uno de sus integrantes.');
        }
      } else if (role != 'admin') {
        throw StateError('Solo Administración puede asignar tareas generales sin proyecto.');
      }
      if (actividad.titulo.trim().length < 3 || actividad.titulo.length > 150 || actividad.descripcion.length > 2000 || !actividad.fechaTermino.isAfter(actividad.fechaInicio)) {
        throw StateError('Revisa el título, las indicaciones y la fecha de entrega.');
      }
''' + s[end:]
 return s
edit('lib/services/actividades_service.dart',service)

def picker(s):
 s=s.replace('stream: query.snapshots()', 'stream: query.snapshots(includeMetadataChanges: true)')
 s=once(s,"if (docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Todavía no tienes proyectos asignados. Administración puede agregarte a uno.')));", "if (docs.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.folder_off_outlined, size: 40, color: Colors.white38), const SizedBox(height: 15), Text(snapshot.data!.metadata.isFromCache ? 'No hay proyectos descargados. Conecta a Internet para consultar la lista actual.' : usuario.rol == AppRoles.admin ? 'No hay proyectos registrados todavía. Para organizar el trabajo diario, vuelve y elige Tarea general.' : 'Todavía no tienes proyectos asignados. Administración debe agregarte a los proyectos que tienes a cargo.', textAlign: TextAlign.center), const SizedBox(height: 16), OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Volver'))])));")
 return s
edit('lib/widgets/project_picker.dart',picker)

def warehouse(s):
 s="import '../widgets/warehouse_header.dart';\nimport '../services/inventario_service.dart';\nimport 'inventario_admin_screen.dart';\nimport 'insumo_form_screen.dart';\n"+s
 s=once(s,"appBar:AppBar(title:const Text('Almacén · movimientos'),bottom:const TabBar(isScrollable:true,tabAlignment:TabAlignment.start,tabs:[Tab(text:'Solicitudes'),Tab(text:'En préstamo'),Tab(text:'Recibir'),Tab(text:'Historial'),Tab(text:'Entre compañeros')]))", "appBar:AppBar(title:const Text('Almacén'),actions:[IconButton(tooltip:'Registrar herramienta',icon:const Icon(Icons.add_circle_outline_rounded,color:Color(0xFFB7FF2A)),onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>InsumoFormScreen(inventarioService:InventarioService())))),IconButton(tooltip:'Ver inventario',icon:const Icon(Icons.inventory_2_outlined),onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>const InventarioAdminScreen())))],bottom:const TabBar(isScrollable:true,tabAlignment:TabAlignment.start,dividerColor:Colors.transparent,indicatorSize:TabBarIndicatorSize.tab,indicator:BoxDecoration(color:Color(0xFF371321),borderRadius:BorderRadius.all(Radius.circular(26))),labelColor:Color(0xFFB7FF2A),unselectedLabelColor:Colors.white60,tabs:[Tab(icon:Icon(Icons.pending_actions_rounded),text:'Solicitudes'),Tab(icon:Icon(Icons.outbox_outlined),text:'En préstamo'),Tab(icon:Icon(Icons.move_to_inbox_outlined),text:'Recibir'),Tab(icon:Icon(Icons.history_rounded),text:'Historial'),Tab(icon:Icon(Icons.swap_horiz_rounded),text:'Compañeros')]))")
 s=once(s,'body:Column(children:[', "body:Column(children:[\n    if(MediaQuery.sizeOf(context).height>650&&MediaQuery.textScalerOf(context).scale(1)<1.5)const Padding(padding:EdgeInsets.fromLTRB(16,16,16,0),child:WarehouseHeader(title:'Cada herramienta, bajo control.',subtitle:'Autoriza la salida · Confirma la devolución · Conserva el historial',compact:true)),")
 return s
edit('lib/screens/admin_solicitudes_herramientas_screen.dart',warehouse)

# Localized visual changes in warehouse modules only; no data logic is replaced.
palette={'0xFF121212':'0xFF000000','0xFF161210':'0xFF000000','0xFF1E1E1E':'0xFF111012','0xFF221A16':'0xFF111012','0xFFFFDE21':'0xFFB7FF2A','0xFF00B0FF':'0xFFC798FF','0xFFE040FB':'0xFFC798FF','0xFF9400D3':'0xFFC13CFF','0xFFFF3399':'0xFFFF729C','0xFF33CC33':'0xFF7CE3BD','0xFF8B4513':'0xFF351020','0xFF4A1504':'0xFF120C12'}
for filename in ['inventario_admin_screen.dart','inventario_trabajador_screen.dart','insumo_form_screen.dart','insumo_detalle_screen.dart','recepcion_inventario_screen.dart','admin_categorias_screen.dart','trabajador_categorias_screen.dart','admin_reparaciones_screen.dart','trabajador_control_herramientas_screen.dart','trabajador_cajita_herramientas_screen.dart']:
 p=root/'lib/screens'/filename;s=p.read_text()
 for old,new in palette.items():s=s.replace(old,new)
 if filename=='insumo_form_screen.dart':
  s=s.replace('BorderRadius.circular(10)','BorderRadius.circular(20)').replace('BorderRadius.circular(15)','BorderRadius.circular(28)')
  s="import '../widgets/warehouse_header.dart';\n"+s
  s=once(s,'                Center(child: _buildImageSelector()),', "                WarehouseHeader(title: esEdicion ? 'Actualiza tu inventario' : 'Registra una herramienta', subtitle: 'Foto, identificación y existencias en un solo lugar.'),\n                const SizedBox(height: 22),\n                Center(child: _buildImageSelector()),")
 if filename in ['inventario_admin_screen.dart','inventario_trabajador_screen.dart']:
  s="import '../widgets/warehouse_header.dart';\n"+s
  s=once(s,'          return Column(\n            children: [', "          return Column(\n            children: [\n              if (MediaQuery.sizeOf(context).height > 650 && MediaQuery.textScalerOf(context).scale(1) < 1.5) const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 8), child: WarehouseHeader(title: 'Todo en su lugar.', subtitle: 'Existencias · Herramientas · Insumos', compact: true)),")
 p.write_text(s)

# Inventory images must work in Safari/Chrome as well as native Android.
def image_form(s):
 s=once(s,"import 'dart:io';", "import 'dart:typed_data';")
 s=once(s,'  File? _imagenSeleccionada;', '  Uint8List? _imagenBytes;')
 s=s.replace('_imagenSeleccionada != null','_imagenBytes != null')
 s=once(s,'Image.file(_imagenSeleccionada!, fit: BoxFit.cover)','Image.memory(_imagenBytes!, fit: BoxFit.cover)')
 for source in ['camera','gallery']:
  old=f"final pickedFile = await ImagePicker().pickImage(source: ImageSource.{source}, imageQuality: 80);\n                  if (pickedFile != null) setState(() => _imagenSeleccionada = File(pickedFile.path));"
  s=once(s,old,f'await _pickInventoryPhoto(ImageSource.{source});')
 start=s.index('          // Si estamos editando y había una imagen vieja')
 end=s.index('\n        }',start)
 s=s[:start]+'''          // Preserve the previous photo until the new record is saved.
          urlFinal = await widget.inventarioService.subirImagenInsumoBytes(_imagenBytes!, nombreIngresado);
''' .rstrip()+s[end:]
 pos=s.index('  void _mostrarOpcionesImagen()')
 s=s[:pos]+'''  Future<void> _pickInventoryPhoto(ImageSource source) async {
    if (_isSaving) return;
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) throw StateError('Usa una foto de menos de 8 MB.');
      if (mounted) setState(() => _imagenBytes = bytes);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo leer la foto. Revisa el permiso y elige una imagen de menos de 8 MB.')));
    }
  }
''' + s[pos:]
 return s
edit('lib/screens/insumo_form_screen.dart',image_form)

def upload(s):
 s="import 'dart:typed_data';\n"+s
 pos=s.index('  /// Elimina una imagen')
 s=s[:pos]+'''  Future<String> subirImagenInsumoBytes(Uint8List bytes, String nombreInsumo) async {
    if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) throw StateError('La foto debe pesar menos de 8 MB.');
    final png = bytes.length > 8 && bytes[0] == 137 && bytes[1] == 80 && bytes[2] == 78;
    final jpg = bytes.length > 3 && bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255;
    final webp = bytes.length > 12 && bytes[0] == 82 && bytes[1] == 73 && bytes[8] == 87 && bytes[9] == 69;
    if (!png && !jpg && !webp) throw StateError('Usa una foto JPG, PNG o WebP.');
    final ext = png ? 'png' : webp ? 'webp' : 'jpg';
    final name = nombreInsumo.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final ref = _storage.ref('insumos_inventario/${DateTime.now().microsecondsSinceEpoch}_$name.$ext');
    await ref.putData(bytes, SettableMetadata(contentType: png ? 'image/png' : webp ? 'image/webp' : 'image/jpeg'));
    return ref.getDownloadURL();
  }

''' + s[pos:]
 return s
edit('lib/services/inventario_service.dart',upload)
# Explanatory notes accompany the app, not promises of provider activation.
p=root/'OPERATIONS_RELEASE.md'
p.write_text(p.read_text()+'''\n## Corrección de la captura enviada (3.1.1)\nAdministración puede elegir Tarea general y asignarla a una persona sin crear ni seleccionar un proyecto. La tarea se almacena en actividades con proyectoId vacío; no se fabrica un proyecto ni se cambia membresía. Maestros conservan asignaciones dentro de sus proyectos. Las tareas generales aparecen en el panel del responsable y admiten avances/evidencia.\nAlmacén, catálogo, registro con foto, categorías y recepción comparten negro, vino y acentos redondeados. Las fotos nuevas se leen y suben como bytes compatibles con navegador/Android y no se borra la foto anterior antes de confirmar el cambio.\nLas reglas y funciones de producción no se despliegan con esta publicación. Las asignaciones del maestro, aprobaciones, historial estricto y juegos necesitan las reglas revisadas activas. No se han probado movimientos con cuentas reales ni el APK en un teléfono físico.\n''')
print('Task scope, inventory image handling and localized warehouse presentation updated.')
