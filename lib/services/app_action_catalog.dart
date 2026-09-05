import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../screens/equipo_tareas_screen.dart';
import '../screens/perfiles_equipo_screen.dart';
import '../screens/prestamos_equipo_screen.dart';
import '../screens/justificar_falta_screen.dart';
import '../screens/online_smart_screen.dart';
import '../screens/jornada_screen.dart';
import '../screens/admin_alerta_general_screen.dart';
import '../screens/admin_asistencias_screen.dart';
import '../screens/admin_cajitas_screen.dart';
import '../screens/admin_clientes_screen.dart';
import '../screens/admin_rachas_screen.dart';
import '../screens/admin_tipos_madera.dart';
import '../screens/admin_ventas_main_screen.dart';
import '../screens/asistente_ia_screen.dart';
import '../screens/blog_interno_screen.dart';
import '../screens/calendario_cumpleanos_screen.dart';
import '../screens/configuracion_screen.dart';
import '../screens/guia_inteligente_screen.dart';
import '../screens/incubadora_ideas_screen.dart';
import '../screens/inventario_admin_screen.dart';
import '../screens/inventario_trabajador_screen.dart';
import '../screens/mensajes_equipo_screen.dart';
import '../screens/notificaciones_screen.dart';
import '../screens/perfil_social_screen.dart';
import '../screens/proveedores_screen.dart';
import '../screens/proyectos_admin_screen.dart';
import '../screens/proyectos_almacenista_screen.dart';
import '../screens/proyectos_trabajador_screen.dart';
import '../screens/racha_asistencias_screen.dart';
import '../screens/reconocimientos_screen.dart';
import '../screens/seguimiento_cotizaciones_screen.dart';
import '../screens/trabajador_asistencia_screen.dart';
import '../screens/trabajador_cajita_herramientas_screen.dart';
import '../screens/trabajador_tipos_madera.dart';
import '../screens/voz_administracion_screen.dart';

class AppAction {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget Function(BuildContext) builder;
  final bool primary;
  final List<String> keywords;

  const AppAction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.builder,
    this.primary = false,
    this.keywords = const <String>[],
  });

  bool matches(String query) {
    final value = _normalize(query);
    if (value.isEmpty) return true;
    final haystack = _normalize(<String>[title, subtitle, ...keywords].join(' '));
    return value.split(RegExp(r'\s+')).every(haystack.contains);
  }
}

String _normalize(String text) {
  const accented = 'áéíóúüñ';
  const plain = 'aeiouun';
  var value = text.trim().toLowerCase();
  for (var i = 0; i < accented.length; i++) {
    value = value.replaceAll(accented[i], plain[i]);
  }
  return value;
}

class AppActionCatalog {
  static const _cyan = Color(0xFFB7FF2A);
  static const _mint = Color(0xFFC6FF68);
  static const _violet = Color(0xFFC13CFF);
  static const _pink = Color(0xFFB82B55);
  static const _amber = Color(0xFFFFB347);
  static const _blue = Color(0xFFB7FF2A);

  static List<AppAction> forUser(UserModel user) {
    final admin = user.rol == AppRoles.admin;
    final warehouse = user.rol == AppRoles.almacenista;
    final master = user.rol == AppRoles.maestro;

    final actions = <AppAction>[
      AppAction(id: 'equipo', title: admin ? 'Administrar perfiles' : 'Nuestro equipo', subtitle: admin ? 'Otorgar insignias y agregar lugares de instalación' : 'Personas, intereses e instalaciones', icon: Icons.groups_outlined, color: _mint, keywords: const ['insignias', 'lugares', 'instalaciones', 'personas'], builder: (_) => PerfilesEquipoScreen(usuarioActual: user)),
      AppAction(id: 'prestamos', title: 'Préstamos de herramienta', subtitle: 'Solicitar, prestar, recibir y devolver', icon: Icons.handyman_outlined, color: _mint, keywords: const ['compañero', 'cajita', 'herramientas'], builder: (_) => PrestamosEquipoScreen(usuario: user)),
      if (!admin) AppAction(id: 'justificar', title: 'Justificar una falta', subtitle: 'Enviar motivo y consultar su revisión', icon: Icons.fact_check_outlined, color: _pink, keywords: const ['ausencia', 'justificación', 'falta'], builder: (_) => JustificarFaltaScreen(usuario: user)),
      AppAction(id: 'tareas', title: 'Mis tareas', subtitle: 'Actividades, avances y evidencias', icon: Icons.assignment_outlined, color: _mint, primary: true, keywords: const ['actividades', 'jornada', 'pendientes'], builder: (_) => EquipoTareasScreen(usuario: user)),
      AppAction(
        id: 'ia',
        title: 'Online Smart',
        subtitle: 'Tu guía mexicana para Sauna Stilo',
        icon: Icons.auto_awesome_rounded,
        color: _cyan,
        primary: true,
        keywords: const ['asistente', 'internet', 'inteligencia', 'buscar'],
        builder: (_) => OnlineSmartScreen(usuario: user),
      ),
      AppAction(
        id: 'guia',
        title: 'Guía',
        subtitle: 'Te dice dónde entrar y qué hacer',
        icon: Icons.explore_rounded,
        color: _mint,
        primary: true,
        keywords: const ['ayuda', 'tutorial', 'pasos', 'cómo'],
        builder: (_) => OnlineSmartScreen(usuario: user),
      ),
      AppAction(
        id: 'mensajes',
        title: 'Mensajes',
        subtitle: 'Chats, grupos y llamadas',
        icon: Icons.forum_rounded,
        color: _violet,
        primary: true,
        keywords: const ['chat', 'llamada', 'equipo'],
        builder: (_) => MensajesEquipoScreen(usuario: user),
      ),
      AppAction(
        id: 'comunidad',
        title: 'Comunidad',
        subtitle: 'Avances, fotos y comentarios',
        icon: Icons.dynamic_feed_rounded,
        color: _pink,
        builder: (_) => BlogInternoScreen(usuario: user),
      ),
      AppAction(
        id: 'avisos',
        title: 'Avisos',
        subtitle: 'Notificaciones y alertas',
        icon: Icons.notifications_active_rounded,
        color: _amber,
        builder: (_) => NotificacionesScreen(usuario: user),
      ),
      AppAction(
        id: 'perfil',
        title: 'Mi perfil',
        subtitle: 'Avances, logros y cuenta',
        icon: Icons.account_circle_rounded,
        color: _blue,
        builder: (_) => PerfilSocialScreen(
          usuarioActual: user,
          perfilId: user.id,
        ),
      ),
      AppAction(
        id: 'configuracion',
        title: 'Configuración',
        subtitle: 'Cuenta, permisos y preferencias',
        icon: Icons.tune_rounded,
        color: const Color(0xFFD7D3D6),
        builder: (_) => ConfiguracionScreen(usuario: user),
      ),
      AppAction(
        id: 'insignias',
        title: 'Insignias',
        subtitle: 'Reconocimientos y logros',
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFFD7FF74),
        builder: (_) => ReconocimientosScreen(usuario: user),
      ),
      const AppAction(
        id: 'cumpleanos',
        title: 'Cumpleaños',
        subtitle: 'Lista de fechas, gustos y colores favoritos',
        icon: Icons.cake_rounded,
        color: Color(0xFFC94469),
        builder: _birthdays,
      ),
    ];

    if (admin) {
      actions.addAll(<AppAction>[
        const AppAction(id: 'alerta_general', title: 'ALERTA GENERAL', subtitle: 'Llamar a todo el equipo ahora', icon: Icons.campaign_rounded, color: Color(0xFFFF536A), primary: true, keywords: ['alarma', 'alerta', 'todos', 'equipo', 'urgente', 'llamar a todos'], builder: _alertAll),
        const AppAction(id: 'proyectos', title: 'Proyectos', subtitle: 'Producción, avance y entregas', icon: Icons.architecture_rounded, color: _mint, primary: true, keywords: ['saunas', 'producción', 'entregas'], builder: _projectsAdmin),
        const AppAction(id: 'clientes', title: 'Clientes', subtitle: 'Directorio y seguimiento', icon: Icons.groups_2_rounded, color: _pink, builder: _clients),
        const AppAction(id: 'ventas', title: 'Ventas', subtitle: 'Operación comercial', icon: Icons.trending_up_rounded, color: _amber, builder: _sales),
        const AppAction(id: 'cotizaciones', title: 'Cotizaciones', subtitle: 'Seguimiento comercial', icon: Icons.request_quote_rounded, color: _cyan, builder: _quotes),
        const AppAction(id: 'inventario', title: 'Inventario', subtitle: 'Existencias, herramientas e insumos', icon: Icons.inventory_2_rounded, color: _blue, builder: _inventoryAdmin),
        AppAction(id: 'asistencias', title: 'Asistencias', subtitle: 'Entradas, comidas y salidas', icon: Icons.fingerprint_rounded, color: _violet, builder: (_) => AdminAsistenciasScreen(nombreAdmin: user.nombre)),
        const AppAction(id: 'proveedores', title: 'Proveedores', subtitle: 'Compras y abastecimiento', icon: Icons.local_shipping_rounded, color: Color(0xFFB82B55), builder: _providers),
        const AppAction(id: 'cajitas', title: 'Cajitas', subtitle: 'Herramientas asignadas', icon: Icons.home_repair_service_rounded, color: Color(0xFFD7FF74), builder: _boxes),
        const AppAction(id: 'maderas', title: 'Maderas', subtitle: 'Catálogo y materiales', icon: Icons.forest_rounded, color: Color(0xFFC6FF68), builder: _woodAdmin),
        const AppAction(id: 'ideas', title: 'Ideas', subtitle: 'Incubadora de innovación', icon: Icons.lightbulb_rounded, color: Color(0xFFC13CFF), builder: _ideas),
        AppAction(id: 'rachas', title: 'Rachas', subtitle: 'Constancia del equipo', icon: Icons.local_fire_department_rounded, color: const Color(0xFFFF536A), builder: (_) => AdminRachasScreen(adminUser: user)),
        AppAction(
          id: 'voz',
          title: 'Mi voz',
          subtitle: 'Haz que la IA hable con tu voz',
          icon: Icons.graphic_eq_rounded,
          color: _cyan,
          primary: true,
          keywords: const ['voz', 'audio', 'administración'],
          builder: (_) => VozAdministracionScreen(usuario: user),
        ),
      ]);
    } else if (warehouse) {
      actions.addAll(<AppAction>[
        const AppAction(id: 'inventario', title: 'Inventario', subtitle: 'Existencias y solicitudes', icon: Icons.inventory_2_rounded, color: _blue, primary: true, builder: _inventoryAdmin),
        const AppAction(id: 'proyectos', title: 'Proyectos', subtitle: 'Material por proyecto', icon: Icons.architecture_rounded, color: _mint, builder: _projectsWarehouse),
        const AppAction(id: 'cajitas', title: 'Cajitas', subtitle: 'Herramientas asignadas', icon: Icons.home_repair_service_rounded, color: Color(0xFFD7FF74), builder: _boxes),
        const AppAction(id: 'proveedores', title: 'Proveedores', subtitle: 'Abastecimiento', icon: Icons.local_shipping_rounded, color: Color(0xFFB82B55), builder: _providers),
        AppAction(id: 'asistencia', title: 'Asistencia', subtitle: 'Registra tu jornada', icon: Icons.fingerprint_rounded, color: _mint, primary: true, builder: (_) => JornadaScreen(usuario: user)),
        AppAction(id: 'racha', title: 'Mi racha', subtitle: 'Constancia de asistencia', icon: Icons.local_fire_department_rounded, color: const Color(0xFFFF536A), builder: (_) => RachaAsistenciasScreen(usuario: user, isAdmin: false)),
      ]);
    } else {
      actions.addAll(<AppAction>[
        AppAction(id: 'proyectos', title: 'Proyectos', subtitle: 'Tus proyectos y avances', icon: Icons.architecture_rounded, color: _mint, primary: true, builder: (_) => ProyectosTrabajadorScreen(esMaestro: master)),
        AppAction(id: 'asistencia', title: 'Asistencia', subtitle: 'Entrada, comida y salida', icon: Icons.fingerprint_rounded, color: _cyan, primary: true, builder: (_) => JornadaScreen(usuario: user)),
        const AppAction(id: 'inventario', title: 'Inventario', subtitle: 'Herramientas disponibles', icon: Icons.inventory_2_rounded, color: _blue, builder: _inventoryWorker),
        AppAction(id: 'cajita', title: 'Mi cajita', subtitle: 'Tus herramientas asignadas', icon: Icons.home_repair_service_rounded, color: const Color(0xFFD7FF74), builder: (_) => TrabajadorCajitaHerramientasScreen(trabajadorId: user.id)),
        const AppAction(id: 'maderas', title: 'Maderas', subtitle: 'Catálogo de materiales', icon: Icons.forest_rounded, color: Color(0xFFC6FF68), builder: _woodWorker),
        AppAction(id: 'racha', title: 'Mi racha', subtitle: 'Tu constancia', icon: Icons.local_fire_department_rounded, color: const Color(0xFFFF536A), builder: (_) => RachaAsistenciasScreen(usuario: user, isAdmin: false)),
      ]);
    }
    return actions;
  }

  static Widget _alertAll(BuildContext _) => const AdminAlertaGeneralScreen();
  static Widget _birthdays(BuildContext _) => const CalendarioCumpleanosScreen();
  static Widget _projectsAdmin(BuildContext _) => const ProyectosAdminScreen();
  static Widget _projectsWarehouse(BuildContext _) => const ProyectosAlmacenistaScreen();
  static Widget _clients(BuildContext _) => const AdminClientesScreen();
  static Widget _sales(BuildContext _) => const VentasScreen();
  static Widget _quotes(BuildContext _) => const SeguimientoCotizacionesScreen();
  static Widget _inventoryAdmin(BuildContext _) => const InventarioAdminScreen();
  static Widget _inventoryWorker(BuildContext _) => const InventarioTrabajadorScreen();
  static Widget _providers(BuildContext _) => const ProveedoresScreen();
  static Widget _boxes(BuildContext _) => const AdminCajitasScreen();
  static Widget _woodAdmin(BuildContext _) => const CatalogoSaunasScreen();
  static Widget _woodWorker(BuildContext _) => const CatalogoSaunasTrabajadorScreen();
  static Widget _ideas(BuildContext _) => const IncubadoraIdeasScreen();
}
