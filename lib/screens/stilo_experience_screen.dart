import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../widgets/conexion_panel.dart';
import 'operational_dashboard_screen.dart' as operation;
import 'admin_asistencias_screen.dart';
import 'admin_cajitas_screen.dart';
import 'admin_clientes_screen.dart';
import 'admin_rachas_screen.dart';
import 'admin_tipos_madera.dart';
import 'admin_ventas_main_screen.dart';
import 'blog_interno_screen.dart';
import 'calendario_cumpleanos_screen.dart';
import 'configuracion_screen.dart';
import 'incubadora_ideas_screen.dart';
import 'inventario_admin_screen.dart';
import 'inventario_trabajador_screen.dart';
import 'mensajes_equipo_screen.dart';
import 'notificaciones_screen.dart';
import 'perfil_social_screen.dart';
import 'proyectos_admin_screen.dart';
import 'proyectos_almacenista_screen.dart';
import 'proyectos_trabajador_screen.dart';
import 'proveedores_screen.dart';
import 'racha_asistencias_screen.dart';
import 'reconocimientos_screen.dart';
import 'seguimiento_cotizaciones_screen.dart';
import 'trabajador_asistencia_screen.dart';
import 'trabajador_cajita_herramientas_screen.dart';
import 'trabajador_tipos_madera.dart';
import 'stilo_intelligence_screen.dart';
import 'brand_voice_screen.dart';

class ModernDashboardScreen extends StatefulWidget {
  final UserModel usuario;
  const ModernDashboardScreen({super.key, required this.usuario});
  @override
  State<ModernDashboardScreen> createState() => _ModernDashboardScreenState();
}

class _ModernDashboardScreenState extends State<ModernDashboardScreen> {
  final _search = TextEditingController();
  String _section = 'Todo';
  bool get _admin => widget.usuario.rol == AppRoles.admin;
  bool get _warehouse => widget.usuario.rol == AppRoles.almacenista;
  bool get _master => widget.usuario.rol == AppRoles.maestro;
  static const _surface = Color(0xFF141518);
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  void _open(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  Widget get _projects => _admin ? const ProyectosAdminScreen() : _warehouse ? const ProyectosAlmacenistaScreen() : ProyectosTrabajadorScreen(esMaestro: _master);
  Widget get _attendance => _admin ? AdminAsistenciasScreen(nombreAdmin: widget.usuario.nombre) : TrabajadorAsistenciaScreen(trabajador: widget.usuario);
  String _normalize(String value) => value.toLowerCase().replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u');
  List<_Module> get _modules => [
    _Module('Mi jornada', 'Entrada, comida, salida y pendientes.', Icons.fingerprint_rounded, 'Trabajo', () => _attendance, 'Abre el registro de asistencia. Registra tu entrada; solicita la comida y registra tu regreso y salida. Comprueba la confirmación antes de cerrar.'),
    _Module('Proyectos', 'Avances y evidencias del trabajo.', Icons.construction_rounded, 'Trabajo', () => _projects, 'Abre el proyecto que tienes asignado. Entra en su actividad, revisa las instrucciones y agrega la evidencia antes de marcar el avance.'),
    _Module('Mensajes', 'Conversaciones privadas y equipo.', Icons.chat_bubble_outline_rounded, 'Equipo', () => MensajesEquipoScreen(usuario: widget.usuario), 'Elige a una persona o un grupo. Escribe o adjunta un archivo y revisa que aparezca enviado. Comprueba los destinatarios antes de compartir información.'),
    _Module('Inventario', 'Herramientas y materiales.', Icons.inventory_2_outlined, 'Trabajo', () => _admin || _warehouse ? const InventarioAdminScreen() : const InventarioTrabajadorScreen(), 'Busca la herramienta o material por nombre. Revisa disponibilidad y usa la opción de solicitud correspondiente; una consulta no equivale a una autorización.'),
    _Module('Herramientas', 'Préstamos y cajitas asignadas.', Icons.home_repair_service_outlined, 'Trabajo', () => _admin || _warehouse ? const AdminCajitasScreen() : TrabajadorCajitaHerramientasScreen(trabajadorId: widget.usuario.id), 'Consulta tu cajita y las herramientas asignadas. Registra las solicitudes y devoluciones desde el módulo para mantener el control del almacén.'),
    _Module('Comunidad', 'Fotos, publicaciones y comentarios.', Icons.dynamic_feed_rounded, 'Equipo', () => BlogInternoScreen(usuario: widget.usuario), 'Abre la comunidad, crea una publicación y agrega tus fotos. Revisa el contenido antes de publicar para todo el equipo.'),
    if (_admin) ...[
      _Module('Clientes', 'Relaciones y datos comerciales.', Icons.people_outline_rounded, 'Administración', () => const AdminClientesScreen(), 'Busca al cliente y abre su ficha. La información comercial es privada para Administración.'),
      _Module('Cotizaciones', 'Propuestas y seguimiento.', Icons.request_quote_outlined, 'Administración', () => const SeguimientoCotizacionesScreen(), 'Busca la cotización por cliente o proyecto. Revisa los importes, vigencia y estado antes de actualizar el seguimiento.'),
      _Module('Ventas', 'Operación comercial.', Icons.point_of_sale_rounded, 'Administración', () => const VentasScreen(), 'Consulta las ventas y entra en el registro correspondiente para revisar su detalle.'),
      _Module('Voz de la marca', 'Graba y escucha tu propia voz.', Icons.graphic_eq_rounded, 'Administración', () => BrandVoiceScreen(usuario: widget.usuario), 'Graba tu propia voz, escúchala y confirma tu consentimiento. Activar la voz sintética requiere el servicio de voz configurado; grabar una muestra no la activa por sí solo.'),
      _Module('Ideas', 'Mejoras para Sauna Stilo.', Icons.lightbulb_outline_rounded, 'Administración', () => const IncubadoraIdeasScreen(), 'Registra propuestas y revisa las ideas de mejora del equipo.'),
    ],
    if (_admin || _warehouse) _Module('Proveedores', 'Suministros y contactos.', Icons.local_shipping_outlined, _admin ? 'Administración' : 'Trabajo', () => const ProveedoresScreen(), 'Busca el proveedor y verifica sus datos antes de coordinar un suministro.'),
    _Module('Maderas', 'Catálogo de materiales.', Icons.forest_outlined, 'Trabajo', () => _admin || _warehouse ? const CatalogoSaunasScreen() : const CatalogoSaunasTrabajadorScreen(), 'Consulta las maderas del catálogo y sus características para tu proyecto.'),
    _Module('Reconocimientos', 'Logros e insignias del equipo.', Icons.workspace_premium_outlined, 'Equipo', () => ReconocimientosScreen(usuario: widget.usuario), 'Revisa los reconocimientos y logros disponibles para tu cuenta.'),
    _Module('Rachas', 'Constancia en la asistencia.', Icons.local_fire_department_outlined, 'Equipo', () => _admin ? AdminRachasScreen(adminUser: widget.usuario) : RachaAsistenciasScreen(usuario: widget.usuario, isAdmin: false), 'Consulta la continuidad de tus registros de asistencia.'),
    _Module('Cumpleaños', 'Fechas del equipo.', Icons.cake_outlined, 'Equipo', () => const CalendarioCumpleanosScreen(), 'Abre el calendario y consulta los cumpleaños registrados.'),
    _Module('Panel operativo', 'Agenda, alertas y control detallado.', Icons.space_dashboard_outlined, 'Trabajo', () => operation.ModernDashboardScreen(usuario: widget.usuario), 'Abre el panel detallado para consultar agenda, pendientes y controles existentes. Administración conserva aquí el llamado al equipo.'),
    _Module('Configuración', 'Tu cuenta y preferencias.', Icons.tune_rounded, 'Cuenta', () => ConfiguracionScreen(usuario: widget.usuario), 'Revisa los datos de tu cuenta y las opciones disponibles para tu perfil.'),
    _Module('Perfil', 'Tu información y publicaciones.', Icons.person_outline_rounded, 'Cuenta', () => PerfilSocialScreen(usuarioActual: widget.usuario, perfilId: widget.usuario.id), 'Consulta tu perfil, logros y publicaciones.'),
  ];

  void _guide() => _open(_GuideScreen(modules: _modules, open: _open));
  @override
  Widget build(BuildContext context) {
    final name = widget.usuario.nombre.trim().isEmpty ? 'Equipo' : widget.usuario.nombre.trim().split(' ').first;
    final modules = _modules.where((m) => (_section == 'Todo' || m.section == _section) && _normalize('${m.name} ${m.subtitle}').contains(_normalize(_search.text))).toList();
    final groups = ['Todo', 'Trabajo', 'Equipo', if (_admin) 'Administración', 'Cuenta'];
    return Scaffold(
      backgroundColor: const Color(0xFF08090B),
      body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1180), child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(22, 18, 16, 16), child: Row(children: [
          Expanded(child: Align(alignment: Alignment.centerLeft, child: Image.asset('assets/logo_saunastilo.png', width: 145, height: 46, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Text('SAUNA STILO', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900))))),
          IconButton(tooltip: 'Guía de uso', onPressed: _guide, icon: const Icon(Icons.help_outline_rounded)),
          IconButton(tooltip: 'Notificaciones', onPressed: () => _open(NotificacionesScreen(usuario: widget.usuario)), icon: const Icon(Icons.notifications_none_rounded)),
          IconButton(tooltip: 'Configuración', onPressed: () => _open(ConfiguracionScreen(usuario: widget.usuario)), icon: const Icon(Icons.tune_rounded)),
        ]))),
        SliverToBoxAdapter(child: Container(margin: const EdgeInsets.symmetric(horizontal: 20), padding: const EdgeInsets.all(26), decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFF484A50)), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2C2E34), Color(0xFF111215), Color(0xFF08090B)])), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SAUNA STILO  /  ESPACIO DE TRABAJO', style: TextStyle(color: Colors.grey.shade300, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.6)),
          const SizedBox(height: 20),
          Text('Hola, $name.', style: const TextStyle(fontSize: 36, height: 1.1, letterSpacing: -1.4, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Text('Todo tu equipo. Un solo lugar.', style: TextStyle(fontSize: 18, color: Color(0xFFD5D6D9))),
          const SizedBox(height: 10),
          Text('${DateFormat('EEEE d MMMM', 'es').format(DateTime.now())} · ${_admin ? 'Administración' : _warehouse ? 'Almacén' : _master ? 'Maestro' : 'Operación'}', style: const TextStyle(color: Color(0xFFB4B6BE), height: 1.4)),
          const SizedBox(height: 24),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, minimumSize: const Size(0, 50)), onPressed: () => _open(_attendance), icon: const Icon(Icons.fingerprint_rounded), label: Text(_admin ? 'Ver asistencias' : 'Registrar mis tiempos')),
            OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(0, 50)), onPressed: () => _open(StiloIntelligenceScreen(usuario: widget.usuario)), icon: const Icon(Icons.auto_awesome_outlined), label: const Text('Abrir Sauna IA')),
            TextButton.icon(style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(0, 48)), onPressed: _guide, icon: const Icon(Icons.explore_outlined), label: const Text('Guía paso a paso')),
          ]),
        ]))),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(22, 28, 22, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('¿Qué necesitas hacer?', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700, letterSpacing: -.6)),
          const SizedBox(height: 16),
          TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: 'Buscar: proyectos, herramientas, mensajes…', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: _search.text.isEmpty ? null : IconButton(tooltip: 'Limpiar búsqueda', onPressed: () { _search.clear(); setState(() {}); }, icon: const Icon(Icons.close_rounded)), filled: true, fillColor: _surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.white24)))),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: groups.map((group) => ChoiceChip(label: Text(group), selected: _section == group, selectedColor: Colors.white, backgroundColor: _surface, labelStyle: TextStyle(color: _section == group ? Colors.black : Colors.white), onSelected: (_) => setState(() => _section = group))).toList()),
        ]))),
        if (modules.isEmpty) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(26), child: Text('No hay coincidencias. Prueba otro nombre o selecciona Todo.'))),
        SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 20), sliver: SliverList.builder(itemCount: modules.length, itemBuilder: (context, index) {
          final module = modules[index];
          return Padding(padding: const EdgeInsets.only(bottom: 9), child: Material(color: _surface, borderRadius: BorderRadius.circular(19), child: ListTile(minVerticalPadding: 16, contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19), side: const BorderSide(color: Color(0xFF292B30))), leading: Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFF25272D), borderRadius: BorderRadius.circular(14)), child: Icon(module.icon, color: Colors.white)), title: Text(module.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(module.subtitle, style: const TextStyle(color: Color(0xFFB6B8C0), height: 1.3))), trailing: const Icon(Icons.arrow_outward_rounded, size: 20, color: Color(0xFFBCC0C9)), onTap: () => _open(module.page()))));
        })),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 20), child: ConexionPanel(usuario: widget.usuario))),
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(22, 0, 22, 24), child: Text('SAUNA STILO · EXPERIENCE 2.0\nTus accesos dependen de los permisos de tu cuenta.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFB4B6BE), fontSize: 11, height: 1.7)))),
      ])))),
      bottomNavigationBar: NavigationBar(backgroundColor: const Color(0xFF101114), indicatorColor: const Color(0xFF373940), selectedIndex: 0, onDestinationSelected: (index) { if (index == 1) _open(_projects); if (index == 2) _open(StiloIntelligenceScreen(usuario: widget.usuario)); if (index == 3) _open(MensajesEquipoScreen(usuario: widget.usuario)); if (index == 4) _guide(); }, destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'), NavigationDestination(icon: Icon(Icons.construction_rounded), label: 'Trabajo'), NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), label: 'Sauna IA'), NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), label: 'Mensajes'), NavigationDestination(icon: Icon(Icons.help_outline_rounded), label: 'Guía')]),
    );
  }
}
class _Module {
  final String name, subtitle, section, guide;
  final IconData icon;
  final Widget Function() page;
  const _Module(this.name, this.subtitle, this.icon, this.section, this.page, this.guide);
}
class _GuideScreen extends StatefulWidget {
  final List<_Module> modules;
  final void Function(Widget) open;
  const _GuideScreen({required this.modules, required this.open});
  @override
  State<_GuideScreen> createState() => _GuideScreenState();
}
class _GuideScreenState extends State<_GuideScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Guía de Sauna Stilo')), body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 850), child: ListView(padding: const EdgeInsets.all(22), children: [
    const Text('Aprende. Abre. Hazlo.', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
    const SizedBox(height: 12),
    const Text('Esta guía no depende de la IA. Las acciones abren los módulos de tu cuenta; consultar datos o guardarlos sí requiere conexión.', style: TextStyle(color: Color(0xFFC6C8CE), height: 1.5)),
    const SizedBox(height: 20),
    TextField(decoration: const InputDecoration(labelText: 'Buscar ayuda', prefixIcon: Icon(Icons.search_rounded), border: OutlineInputBorder()), onChanged: (value) => setState(() => query = value.toLowerCase())),
    const SizedBox(height: 20),
    ...widget.modules.where((m) => '${m.name} ${m.guide}'.toLowerCase().contains(query)).map((module) => Card(color: const Color(0xFF18191D), margin: const EdgeInsets.only(bottom: 12), child: ExpansionTile(leading: Icon(module.icon), title: Text(module.name, style: const TextStyle(fontWeight: FontWeight.w700)), childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18), expandedCrossAxisAlignment: CrossAxisAlignment.start, children: [Text(module.guide, style: const TextStyle(height: 1.6, color: Color(0xFFD0D2D8))), const SizedBox(height: 14), FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => module.page())), icon: const Icon(Icons.arrow_forward_rounded), label: Text('Abrir ${module.name}'))]))),
  ]))));
}
