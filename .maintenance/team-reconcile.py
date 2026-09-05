from pathlib import Path

def replace(path, old, new):
 p=Path(path);s=p.read_text()
 if s.count(old)!=1:raise SystemExit('Unexpected source '+path+' '+old[:65])
 p.write_text(s.replace(old,new))

# Keep the separately-added people search, private previews and project workspace.
replace('lib/screens/operations_shell.dart',"import 'project_workspace_screen.dart';", "import 'project_workspace_screen.dart';\nimport 'equipo_tareas_screen.dart';")
replace('lib/screens/operations_shell.dart',"  NavigationDestination(icon: Icon(Icons.workspaces_outline), selectedIcon: Icon(Icons.workspaces_rounded), label: 'Proyectos'),\n",'')
replace('lib/screens/operations_shell.dart',"  NavigationDestination(icon: Icon(Icons.person_outline_rounded)","  NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment_rounded), label: 'Tareas'),\n  NavigationDestination(icon: Icon(Icons.person_outline_rounded)")
replace('lib/screens/operations_shell.dart',"    1 => ProjectWorkspaceScreen(usuario: widget.usuario),\n    2 => BlogInternoScreen(usuario: widget.usuario),\n    3 => MensajesEquipoScreen(usuario: widget.usuario),","    1 => BlogInternoScreen(usuario: widget.usuario),\n    2 => MensajesEquipoScreen(usuario: widget.usuario),\n    3 => EquipoTareasScreen(usuario: widget.usuario),")
replace('lib/screens/operations_shell.dart',"    if (action.id == 'proyectos') { widget.onTab(1); return; }\n    if (action.id == 'comunidad') { widget.onTab(2); return; }\n    if (action.id == 'mensajes') { widget.onTab(3); return; }", "    if (action.id == 'proyectos') { Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProjectWorkspaceScreen(usuario: widget.usuario))); return; }\n    if (action.id == 'comunidad') { widget.onTab(1); return; }\n    if (action.id == 'mensajes') { widget.onTab(2); return; }\n    if (action.id == 'tareas') { widget.onTab(3); return; }")
replace('lib/screens/operations_shell.dart',"['inventario', 'racha', 'rachas', 'ia', 'asistencias']", "['proyectos', 'asistencia', 'inventario', 'racha', 'rachas', 'ia', 'asistencias']")
replace('lib/screens/operations_shell.dart',"onPressed: () => widget.onTab(3), icon: const Icon(Icons.contact_phone_outlined)", "onPressed: () => widget.onTab(2), icon: const Icon(Icons.contact_phone_outlined)")
replace('lib/screens/operations_shell.dart',"onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Mis tareas y actividades')), body: SingleChildScrollView(padding: const EdgeInsets.all(18), child: OperationsTaskList(usuario: widget.usuario))))), child: const Text('Ver todas')", "onPressed: () => widget.onTab(3), child: const Text('Ver todas')")
replace('lib/screens/project_workspace_screen.dart',"import 'proyectos_trabajador_screen.dart';", "import 'proyectos_trabajador_screen.dart';\nimport 'modal_asignar_actividades.dart';")
replace('lib/screens/project_workspace_screen.dart',"builder: (_) => ProjectTaskComposer(usuario: usuario, proyecto: project)", "builder: (_) => ModalAsignarActividad(proyectoId: project.id, rolUsuario: usuario.rol)")
replace('lib/widgets/jornada_compacta.dart', "import '../screens/trabajador_asistencia_screen.dart';", "import '../screens/jornada_screen.dart';")
replace('lib/widgets/jornada_compacta.dart', "TrabajadorAsistenciaScreen(trabajador: widget.usuario)", "JornadaScreen(usuario: widget.usuario)")
# Only one popup/sound owner per personal notice. General alerts stay separate.
replace('lib/widgets/avisos_sonoros.dart', "aviso.creadoPor != widget.usuario.id && DateTime.now()", "aviso.tipo != 'aviso_personal' && aviso.creadoPor != widget.usuario.id && DateTime.now()")
replace('lib/widgets/personal_message_overlay.dart', "        final result = await showDialog<String>", "        if (!call) {\n          try { await _audio.setReleaseMode(ReleaseMode.release); await _audio.play(AssetSource('sounds/beep.ogg'), volume: 1); } catch (_) {}\n        }\n        final result = await showDialog<String>")
# Test the actual retained implementations, not superseded file formatting.
replace('tests/team-workflows.test.cjs',"const shell=read('lib/screens/modern_dashboard_screen.dart');", "const shell=read('lib/screens/operations_shell.dart');")
start="test('private chat updates never change existing participants and writes messages with notices atomically', () => {"
p=Path('tests/team-workflows.test.cjs');s=p.read_text();a=s.index(start);b=s.index("\ntest('attendance confirms",a)
s=s[:a]+"""test('private chats preserve members and do not lose a saved message when push fails', () => {
  const s=read('lib/services/team_contact_service.dart');
  assert.match(s,/Preserve legacy member order/);
  assert.match(s,/batch.update\\(ref, \\{'actualizadaEn'/);
  assert.match(s,/await batch.commit/);assert.match(s,/return false/);
  assert.match(s,/Abre tu conversación para leer el mensaje privado/);
});
"""+s[b:];p.write_text(s)
replace('tests/futuristic-ai-voice.test.cjs',"  assert.match(guide, /responderAvanzado/);\n  assert.match(guide, /usarInternet:\\s*true/);\n  assert.match(guide, /modo:\\s*'guia'/);", "  assert.match(guide, /OnlineSmartScreen/);\n  assert.match(guide, /SIN CONSULTA A IA/);")
replace('tests/futuristic-ai-voice.test.cjs',"['Inicio', 'Proyectos', 'Comunidad', 'Chats', 'Perfil']", "['Inicio', 'Comunidad', 'Chats', 'Tareas', 'Perfil']")
print('Reconciled home, messaging and tests while preserving project and private-message features.')
