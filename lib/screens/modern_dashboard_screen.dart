import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/actividad_model.dart';
import '../models/user_model.dart';
import '../services/notificaciones_service.dart';
import 'admin_asistencias_screen.dart';
import 'admin_cajitas_screen.dart';
import 'admin_clientes_screen.dart';
import 'admin_rachas_screen.dart';
import 'admin_tipos_madera.dart';
import 'admin_ventas_main_screen.dart';
import 'asistente_ia_screen.dart';
import 'blog_interno_screen.dart';
import 'calendario_cumpleanos_screen.dart';
import 'configuracion_screen.dart';
import 'incubadora_ideas_screen.dart';
import 'inventario_admin_screen.dart';
import 'inventario_trabajador_screen.dart';
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

class ModernDashboardScreen extends StatefulWidget {
  final UserModel usuario;

  const ModernDashboardScreen({super.key, required this.usuario});

  @override
  State<ModernDashboardScreen> createState() => _ModernDashboardScreenState();
}

class _ModernDashboardScreenState extends State<ModernDashboardScreen> {
  static const _fondo = Color(0xFF050505);
  static const _superficie = Color(0xFF151515);
  static const _oro = Color(0xFFD6A85F);
  static const _lima = Color(0xFFDAF56A);
  final _scrollController = ScrollController();

  bool get _esAdmin => widget.usuario.rol == AppRoles.admin;
  bool get _esAlmacen => widget.usuario.rol == AppRoles.almacenista;
  bool get _esMaestro => widget.usuario.rol == AppRoles.maestro;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final Query<Map<String, dynamic>> actividadesQuery = _esAdmin
        ? db.collection('actividades')
        : db
              .collection('actividades')
              .where('asignadoATrabajadorId', isEqualTo: widget.usuario.id);
    return Scaffold(
      backgroundColor: _fondo,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: actividadesQuery.snapshots(),
          builder: (context, snapshot) {
            final actividades = snapshot.data?.docs
                    .map((doc) => ActividadModel.fromJson(doc.data(), doc.id))
                    .toList(growable: true) ??
                <ActividadModel>[];
            actividades.sort(_ordenarActividades);
            return RefreshIndicator(
              color: _oro,
              backgroundColor: _superficie,
              onRefresh: () async {
                await Future<void>.delayed(const Duration(milliseconds: 500));
                if (mounted) setState(() {});
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _cabecera()),
                  SliverToBoxAdapter(child: _saludo()),
                  SliverToBoxAdapter(child: _resumen(actividades)),
                  if (!_esAdmin) SliverToBoxAdapter(child: _controlJornada()),
                  SliverToBoxAdapter(child: _semana()),
                  SliverToBoxAdapter(child: _agenda(actividades)),
                  SliverToBoxAdapter(child: _llamadaAsistente()),
                  SliverToBoxAdapter(child: _accesos()),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _barraInferior(),
    );
  }

  Widget _cabecera() {
    final notificaciones = NotificacionesService();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
      child: Row(
        children: [
          SizedBox(
            width: 126,
            height: 38,
            child: Image.asset(
              'assets/logo_saunastilo.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (_, __, ___) => Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: _oro),
                  const SizedBox(width: 7),
                  Text(
                    'SAUNA STILO',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          StreamBuilder<int>(
            stream: notificaciones.noLeidosPara(
              usuarioId: widget.usuario.id,
              rol: widget.usuario.rol,
            ),
            builder: (context, snapshot) {
              final total = snapshot.data ?? 0;
              return _BotonCabecera(
                icono: Icons.notifications_none_rounded,
                contador: total,
                onTap: () => _abrir(
                  NotificacionesScreen(usuario: widget.usuario),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          _BotonCabecera(
            icono: Icons.tune_rounded,
            onTap: () => _abrir(ConfiguracionScreen(usuario: widget.usuario)),
          ),
        ],
      ),
    );
  }

  Widget _saludo() {
    final nombreCompleto = widget.usuario.nombre.trim().isEmpty
        ? 'Equipo'
        : widget.usuario.nombre.trim();
    final primerNombre = nombreCompleto.split(RegExp(r'\s+')).first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFD6A85F), Color(0xFF493620)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white12, width: 1.5),
              image: widget.usuario.fotoUrl?.isNotEmpty == true
                  ? DecorationImage(
                      image: NetworkImage(widget.usuario.fotoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: widget.usuario.fotoUrl?.isNotEmpty == true
                ? null
                : Text(
                    primerNombre[0].toUpperCase(),
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, $primerNombre',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 27,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: _lima,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      _etiquetaRol(),
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumen(List<ActividadModel> actividades) {
    final abiertas = actividades
        .where((actividad) => actividad.estatus != 'completado')
        .length;
    final hoy = actividades.where((actividad) {
      return actividad.estatus != 'completado' &&
          _mismoDia(actividad.fechaAsignada, DateTime.now());
    }).length;
    final vencidas = actividades.where((actividad) {
      return actividad.estatus != 'completado' &&
          actividad.fechaTermino.isBefore(_inicioDeHoy());
    }).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'OPERACIÓN DE HOY',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              const Icon(Icons.circle, color: _lima, size: 7),
              Text(
                ' EN VIVO',
                style: GoogleFonts.inter(
                  color: _lima,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DatoResumen(
                  valor: '$hoy',
                  etiqueta: 'Para hoy',
                  color: _lima,
                ),
              ),
              const _DivisorResumen(),
              Expanded(
                child: _DatoResumen(
                  valor: '$abiertas',
                  etiqueta: 'Abiertas',
                  color: const Color(0xFF72D6FF),
                ),
              ),
              const _DivisorResumen(),
              Expanded(
                child: _DatoResumen(
                  valor: '$vencidas',
                  etiqueta: 'Urgentes',
                  color: const Color(0xFFFF8E8E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Colors.white12),
        ],
      ),
    );
  }

  Widget _controlJornada() {
    final ahora = DateTime.now();
    final asistenciaId =
        '${widget.usuario.id}_${DateFormat('yyyyMMdd').format(ahora)}';
    final stream = FirebaseFirestore.instance
        .collection('asistencias')
        .doc(asistenciaId)
        .snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final entrada = _horaAsistencia(data['horaEntrada']);
        final salida = _horaAsistencia(data['horaSalida']);
        final salidaComida = _horaAsistencia(data['salidaComidaReal']);
        final regresoComida = _horaAsistencia(data['regresoComidaReal']);
        final comidaEstado = data['estatusComida']?.toString() ?? 'ninguna';
        final entradaLista = entrada != null;
        final salidaLista = salida != null;
        final comidaLista = regresoComida != null;
        String accion = 'REGISTRAR ENTRADA';
        String ayuda = 'El registro valida hora y ubicación.';
        if (salidaLista) {
          accion = 'VER MI JORNADA';
          ayuda = 'Tu jornada de hoy quedó finalizada.';
        } else if (comidaEstado == 'pendiente_aprobacion') {
          accion = 'COMIDA PENDIENTE';
          ayuda = 'Administración debe autorizar tu salida.';
        } else if (comidaEstado == 'comiendo' ||
            (salidaComida != null && regresoComida == null)) {
          accion = 'REGISTRAR REGRESO';
          ayuda = 'Registra tu regreso al terminar de comer.';
        } else if (entradaLista && !comidaLista) {
          accion = 'COMIDA Y SALIDA';
          ayuda = 'No olvides registrar comida y fin de jornada.';
        } else if (entradaLista) {
          accion = 'REGISTRAR SALIDA';
          ayuda = 'Registra tu salida antes de retirarte.';
        }
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF101B19),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: const Color(0xFF70E1D0).withOpacity(.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF70E1D0).withOpacity(.13),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      color: Color(0xFF70E1D0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONTROL DE JORNADA',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .8,
                          ),
                        ),
                        Text(
                          ayuda,
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  Expanded(
                    child: _JornadaPaso(
                      icono: Icons.login_rounded,
                      titulo: 'Entrada',
                      detalle: entrada ?? 'Pendiente',
                      completado: entradaLista,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _JornadaPaso(
                      icono: Icons.restaurant_rounded,
                      titulo: 'Comida',
                      detalle: regresoComida ??
                          (salidaComida != null
                              ? 'Fuera $salidaComida'
                              : 'Pendiente'),
                      completado: comidaLista,
                      activo: comidaEstado == 'comiendo' ||
                          comidaEstado == 'pendiente_aprobacion',
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _JornadaPaso(
                      icono: Icons.logout_rounded,
                      titulo: 'Salida',
                      detalle: salida ?? 'Pendiente',
                      completado: salidaLista,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF70E1D0),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _abrir(
                    TrabajadorAsistenciaScreen(trabajador: widget.usuario),
                  ),
                  icon: Icon(
                    salidaLista
                        ? Icons.receipt_long_rounded
                        : Icons.touch_app_rounded,
                  ),
                  label: Text(
                    accion,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String? _horaAsistencia(dynamic value) {
    if (value is! Timestamp) return null;
    return DateFormat('HH:mm').format(value.toDate());
  }

  Widget _semana() {
    final hoy = DateTime.now();
    final lunes = hoy.subtract(Duration(days: hoy.weekday - 1));
    const iniciales = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Esta semana',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: List.generate(7, (index) {
              final fecha = lunes.add(Duration(days: index));
              final seleccionado = _mismoDia(fecha, hoy);
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: seleccionado ? _lima : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Text(
                        iniciales[index],
                        style: GoogleFonts.inter(
                          color: seleccionado ? Colors.black : Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${fecha.day}',
                        style: GoogleFonts.montserrat(
                          color: seleccionado ? Colors.black : Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _agenda(List<ActividadModel> actividades) {
    final abiertas = actividades
        .where((actividad) => actividad.estatus != 'completado')
        .take(4)
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _esAdmin ? 'Prioridades del equipo' : 'Tu agenda',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _abrir(_pantallaTrabajo()),
                child: const Text('VER TODO'),
              ),
            ],
          ),
          if (abiertas.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _superficie,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: _lima),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No hay tareas abiertas en este momento.',
                      style: GoogleFonts.inter(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            )
          else
            ...abiertas.map(_tarjetaActividad),
        ],
      ),
    );
  }

  Widget _tarjetaActividad(ActividadModel actividad) {
    final vencida = actividad.fechaTermino.isBefore(DateTime.now());
    final esHoy = _mismoDia(actividad.fechaAsignada, DateTime.now());
    final color = vencida
        ? const Color(0xFFFF8E8E)
        : esHoy
        ? _lima
        : const Color(0xFF8F9CF4);
    final estado = vencida
        ? 'URGENTE'
        : esHoy
        ? 'HOY'
        : 'EN CURSO';
    return GestureDetector(
      onTap: () => _abrir(_pantallaTrabajo()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _superficie,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    actividad.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Límite ${DateFormat('dd MMM · HH:mm', 'es').format(actividad.fechaTermino)} · ${actividad.totalEvidencias} evidencias',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                estado,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _llamadaAsistente() {
    return GestureDetector(
      onTap: () => _abrir(AsistenteIaScreen(usuario: widget.usuario)),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(27),
          gradient: const LinearGradient(
            colors: [Color(0xFF30271D), Color(0xFF121212)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: _oro.withOpacity(.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                border: Border.all(color: _oro, width: 1.5),
                boxShadow: [
                  BoxShadow(color: _oro.withOpacity(.2), blurRadius: 16),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: _oro),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SAUNA IA · VOZ ACTIVA',
                    style: GoogleFonts.inter(
                      color: _oro,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _esAdmin
                        ? 'Pregunta por proyectos, clientes, cotizaciones o estadísticas.'
                        : 'Pregunta por tus tareas o solicita una herramienta hablando.',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _accesos() {
    final acciones = _acciones();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Explorar',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  'DESLIZA',
                  style: GoogleFonts.inter(
                    color: Colors.white30,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 102,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: acciones.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final accion = acciones[index];
                return InkWell(
                  onTap: () => _abrir(accion.destino),
                  borderRadius: BorderRadius.circular(42),
                  child: SizedBox(
                    width: 76,
                    child: Column(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [accion.color, _oro, Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: _fondo,
                              shape: BoxShape.circle,
                            ),
                            margin: const EdgeInsets.all(2.5),
                            child: Icon(
                              accion.icono,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          accion.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraInferior() {
    final items = <_NavItem>[
      const _NavItem('Inicio', Icons.home_rounded),
      const _NavItem('Trabajo', Icons.construction_rounded),
      const _NavItem('Comunidad', Icons.add_box_outlined),
      const _NavItem('IA', Icons.auto_awesome_rounded),
      const _NavItem('Perfil', Icons.person_rounded),
    ];
    return SafeArea(
      top: false,
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final seleccionado = index == 0;
            return Expanded(
              child: InkWell(
                onTap: () => _navegarInferior(index),
                customBorder: const CircleBorder(),
                child: Center(
                  child: index == 4
                      ? Container(
                          width: 29,
                          height: 29,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: seleccionado ? Colors.white : Colors.white54,
                              width: seleccionado ? 2 : 1,
                            ),
                            image: widget.usuario.fotoUrl?.isNotEmpty == true
                                ? DecorationImage(
                                    image: NetworkImage(widget.usuario.fotoUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: widget.usuario.fotoUrl?.isNotEmpty == true
                              ? null
                              : Icon(
                                  item.icono,
                                  color: Colors.white,
                                  size: 21,
                                ),
                        )
                      : Icon(
                          item.icono,
                          color: Colors.white,
                          size: seleccionado ? 29 : 27,
                        ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  List<_AccionDashboard> _acciones() {
    if (_esAdmin) {
      return <_AccionDashboard>[
        const _AccionDashboard('Inventario', Icons.inventory_2_rounded, Color(0xFF72D6FF), InventarioAdminScreen()),
        const _AccionDashboard('Clientes', Icons.groups_rounded, Color(0xFFFF8FAB), AdminClientesScreen()),
        const _AccionDashboard('Ventas', Icons.point_of_sale_rounded, Color(0xFFFFD166), VentasScreen()),
        const _AccionDashboard('Proyectos', Icons.construction_rounded, Color(0xFFB9F56A), ProyectosAdminScreen()),
        const _AccionDashboard('Cotizaciones', Icons.request_quote_rounded, Color(0xFF70E1D0), SeguimientoCotizacionesScreen()),
        _AccionDashboard('Asistencias', Icons.fact_check_rounded, const Color(0xFFA78BFA), AdminAsistenciasScreen(nombreAdmin: widget.usuario.nombre)),
        const _AccionDashboard('Proveedores', Icons.local_shipping_rounded, Color(0xFFFFA45B), ProveedoresScreen()),
        const _AccionDashboard('Cajitas', Icons.home_repair_service_rounded, Color(0xFFFFA45B), AdminCajitasScreen()),
        const _AccionDashboard('Maderas', Icons.forest_rounded, Color(0xFF74D99F), CatalogoSaunasScreen()),
        const _AccionDashboard('Ideas', Icons.lightbulb_rounded, Color(0xFFE7C6FF), IncubadoraIdeasScreen()),
        _AccionDashboard('Rachas', Icons.local_fire_department_rounded, const Color(0xFFFF8A65), AdminRachasScreen(adminUser: widget.usuario)),
        _AccionDashboard('Reconocimientos', Icons.workspace_premium_rounded, const Color(0xFFFFD166), ReconocimientosScreen(usuario: widget.usuario)),
        const _AccionDashboard('Cumpleaños', Icons.cake_rounded, Color(0xFFFF8FAB), CalendarioCumpleanosScreen()),
      ];
    }
    if (_esAlmacen) {
      return <_AccionDashboard>[
        const _AccionDashboard('Inventario', Icons.inventory_2_rounded, Color(0xFF72D6FF), InventarioAdminScreen()),
        const _AccionDashboard('Proyectos', Icons.construction_rounded, Color(0xFFB9F56A), ProyectosAlmacenistaScreen()),
        const _AccionDashboard('Cajitas', Icons.home_repair_service_rounded, Color(0xFFFFA45B), AdminCajitasScreen()),
        const _AccionDashboard('Proveedores', Icons.local_shipping_rounded, Color(0xFFFFA45B), ProveedoresScreen()),
        const _AccionDashboard('Maderas', Icons.forest_rounded, Color(0xFF74D99F), CatalogoSaunasScreen()),
        _AccionDashboard('Asistencia', Icons.fingerprint_rounded, const Color(0xFF70E1D0), TrabajadorAsistenciaScreen(trabajador: widget.usuario)),
        _AccionDashboard('Mi racha', Icons.local_fire_department_rounded, const Color(0xFFFF8A65), RachaAsistenciasScreen(usuario: widget.usuario, isAdmin: false)),
        _AccionDashboard('Insignias', Icons.workspace_premium_rounded, const Color(0xFFFFD166), ReconocimientosScreen(usuario: widget.usuario)),
      ];
    }
    return <_AccionDashboard>[
      _AccionDashboard('Proyectos', Icons.construction_rounded, const Color(0xFFB9F56A), ProyectosTrabajadorScreen(esMaestro: _esMaestro)),
      _AccionDashboard('Asistencia', Icons.fingerprint_rounded, const Color(0xFF70E1D0), TrabajadorAsistenciaScreen(trabajador: widget.usuario)),
      const _AccionDashboard('Inventario', Icons.inventory_2_rounded, Color(0xFF72D6FF), InventarioTrabajadorScreen()),
      _AccionDashboard('Mi cajita', Icons.home_repair_service_rounded, const Color(0xFFFFA45B), TrabajadorCajitaHerramientasScreen(trabajadorId: widget.usuario.id)),
      const _AccionDashboard('Maderas', Icons.forest_rounded, Color(0xFF74D99F), CatalogoSaunasTrabajadorScreen()),
      _AccionDashboard('Mi racha', Icons.local_fire_department_rounded, const Color(0xFFFF8A65), RachaAsistenciasScreen(usuario: widget.usuario, isAdmin: false)),
      _AccionDashboard('Insignias', Icons.workspace_premium_rounded, const Color(0xFFFFD166), ReconocimientosScreen(usuario: widget.usuario)),
      const _AccionDashboard('Cumpleaños', Icons.cake_rounded, Color(0xFFFF8FAB), CalendarioCumpleanosScreen()),
    ];
  }

  Widget _pantallaTrabajo() {
    if (_esAdmin) return const ProyectosAdminScreen();
    if (_esAlmacen) return const ProyectosAlmacenistaScreen();
    return ProyectosTrabajadorScreen(esMaestro: _esMaestro);
  }

  void _navegarInferior(int index) {
    switch (index) {
      case 0:
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
        return;
      case 1:
        _abrir(_pantallaTrabajo());
        return;
      case 2:
        _abrir(BlogInternoScreen(usuario: widget.usuario));
        return;
      case 3:
        _abrir(AsistenteIaScreen(usuario: widget.usuario));
        return;
      case 4:
        _abrir(
          PerfilSocialScreen(
            usuarioActual: widget.usuario,
            perfilId: widget.usuario.id,
          ),
        );
        return;
    }
  }

  void _abrir(Widget destino) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => destino));
  }

  String _etiquetaRol() {
    if (_esAdmin) return 'Administración · control completo';
    if (_esAlmacen) return 'Almacén · operación en vivo';
    if (_esMaestro) return 'Maestro · proyectos y equipo';
    return 'Trabajador · tareas y avances';
  }

  int _ordenarActividades(ActividadModel a, ActividadModel b) {
    final aTerminada = a.estatus == 'completado';
    final bTerminada = b.estatus == 'completado';
    if (aTerminada != bTerminada) return aTerminada ? 1 : -1;
    return a.fechaTermino.compareTo(b.fechaTermino);
  }

  bool _mismoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _inicioDeHoy() {
    final hoy = DateTime.now();
    return DateTime(hoy.year, hoy.month, hoy.day);
  }
}

class _JornadaPaso extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final bool completado;
  final bool activo;

  const _JornadaPaso({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.completado,
    this.activo = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = completado
        ? const Color(0xFF70E1D0)
        : activo
            ? const Color(0xFFFFD166)
            : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.035),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(.22)),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(height: 5),
          Text(
            titulo,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detalle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _DatoResumen extends StatelessWidget {
  final String valor;
  final String etiqueta;
  final Color color;

  const _DatoResumen({
    required this.valor,
    required this.etiqueta,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          valor,
          style: GoogleFonts.montserrat(
            color: color,
            fontSize: 28,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          etiqueta,
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DivisorResumen extends StatelessWidget {
  const _DivisorResumen();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 11),
      color: Colors.white10,
    );
  }
}

class _BotonCabecera extends StatelessWidget {
  final IconData icono;
  final int contador;
  final VoidCallback onTap;

  const _BotonCabecera({
    required this.icono,
    required this.onTap,
    this.contador = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF171717),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: Icon(icono, color: Colors.white70, size: 21),
          ),
        ),
        if (contador > 0)
          Positioned(
            right: -2,
            top: -3,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: Color(0xFFFF5D6C),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                contador > 9 ? '9+' : '$contador',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AccionDashboard {
  final String titulo;
  final IconData icono;
  final Color color;
  final Widget destino;

  const _AccionDashboard(this.titulo, this.icono, this.color, this.destino);
}

class _NavItem {
  final String etiqueta;
  final IconData icono;

  const _NavItem(this.etiqueta, this.icono);
}
