import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/actividad_model.dart';
import '../models/user_model.dart';
import '../services/app_action_catalog.dart';
import '../services/notificaciones_service.dart';
import '../widgets/conexion_panel.dart';
import 'configuracion_screen.dart';
import 'notificaciones_screen.dart';

class FuturisticDashboardScreen extends StatefulWidget {
  final UserModel usuario;

  const FuturisticDashboardScreen({super.key, required this.usuario});

  @override
  State<FuturisticDashboardScreen> createState() =>
      _FuturisticDashboardScreenState();
}

class _FuturisticDashboardScreenState
    extends State<FuturisticDashboardScreen> {
  static const _bg = Color(0xFF050506);
  static const _panel = Color(0xFF111012);
  static const _cyan = Color(0xFFB7FF2A);
  static const _mint = Color(0xFFC6FF68);
  static const _violet = Color(0xFFC13CFF);

  final _search = TextEditingController();
  String _query = '';

  bool get _admin => widget.usuario.rol == AppRoles.admin;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final Query<Map<String, dynamic>> query = _admin
        ? db.collection('actividades')
        : db.collection('actividades').where(
              'asignadoATrabajadorId',
              isEqualTo: widget.usuario.id,
            );

    return Scaffold(
      backgroundColor: _bg,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (_, snapshot) {
            final activities = snapshot.data?.docs
                    .map(
                      (doc) => ActividadModel.fromJson(doc.data(), doc.id),
                    )
                    .toList(growable: true) ??
                <ActividadModel>[];
            activities.sort((a, b) => a.fechaTermino.compareTo(b.fechaTermino));
            final all = AppActionCatalog.forUser(widget.usuario);
            final visible = all
                .where((action) => action.matches(_query))
                .toList(growable: false);
            final featured = all
                .where((action) => action.primary)
                .take(6)
                .toList(growable: false);

            return RefreshIndicator(
              color: _cyan,
              backgroundColor: _panel,
              onRefresh: () async {
                await Future<void>.delayed(
                  const Duration(milliseconds: 350),
                );
                if (mounted) setState(() {});
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  _topBar(),
                  _identity(),
                  _searchBar(all),
                  if (_query.isEmpty) ...[
                    _aiHero(all),
                    _sectionTitle('Acciones inmediatas', '1 toque'),
                    _grid(featured),
                    if (snapshot.hasError)
                      const Padding(padding: EdgeInsets.all(18), child: Text(
                        'No pudimos consultar las actividades. Los accesos siguen disponibles; revisa la conexión y tus permisos.',
                        style: TextStyle(color: Colors.orangeAccent)))
                    else if (snapshot.connectionState == ConnectionState.waiting)
                      const Padding(padding: EdgeInsets.all(18), child: LinearProgressIndicator())
                    else _pulse(activities),
                    if (!_admin) _workCard(all),
                    if (snapshot.hasData && !snapshot.hasError) _today(activities),
                    ConexionPanel(usuario: widget.usuario),
                  ],
                  _sectionTitle(
                    _query.isEmpty ? 'Todo tu espacio' : 'Resultados',
                    '${visible.length} accesos',
                  ),
                  _grid(visible),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _topBar() {
    final notifications = NotificacionesService();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 14, 3),
      child: Row(
        children: [
          SizedBox(
            width: 128,
            height: 40,
            child: Image.asset(
              'assets/logo_saunastilo.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (_, __, ___) => Row(
                children: [
                  const Icon(
                    Icons.blur_on_rounded,
                    color: _cyan,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SAUNA STILO',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          _live(),
          const SizedBox(width: 7),
          StreamBuilder<int>(
            stream: notifications.noLeidosPara(
              usuarioId: widget.usuario.id,
              rol: widget.usuario.rol,
            ),
            builder: (_, snapshot) => _RoundButton(
              icon: Icons.notifications_none_rounded,
              badge: snapshot.data ?? 0,
              onTap: () => _open(
                NotificacionesScreen(usuario: widget.usuario),
              ),
            ),
          ),
          const SizedBox(width: 7),
          _RoundButton(
            icon: Icons.tune_rounded,
            onTap: () => _open(
              ConfiguracionScreen(usuario: widget.usuario),
            ),
          ),
        ],
      ),
    );
  }

  Widget _live() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: _mint.withOpacity(.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _mint.withOpacity(.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: _mint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'STILO',
            style: GoogleFonts.inter(
              color: _mint,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _identity() {
    final first = widget.usuario.nombre.trim().split(' ').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SAUNA INTELLIGENCE / ${_roleLabel().toUpperCase()}',
            style: GoogleFonts.inter(
              color: _cyan,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Hola, $first',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _admin
                ? 'Toda la operación, más fácil de encontrar y controlar.'
                : 'Tu trabajo de hoy, sin perderte entre pantallas.',
            style: GoogleFonts.inter(
              color: const Color(0x7AFFFFFF),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar(List<AppAction> actions) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 5),
      child: TextField(
        controller: _search,
        onChanged: (value) => setState(() => _query = value),
        onSubmitted: (value) {
          final matches = actions.where((action) => action.matches(value));
          if (matches.isNotEmpty) _openBuilder(matches.first.builder);
        },
        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: '¿A dónde quieres entrar?  Proyectos, IA, inventario…',
          hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
          prefixIcon: const Icon(Icons.search_rounded, color: _cyan),
          suffixIcon: _query.isEmpty
              ? const Icon(
                  Icons.keyboard_command_key_rounded,
                  color: Colors.white24,
                  size: 18,
                )
              : IconButton(
                  tooltip: 'Limpiar',
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: _panel,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Colors.white10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: _cyan, width: 1.2),
          ),
        ),
      ),
    );
  }

  Widget _aiHero(List<AppAction> actions) {
    final ai = actions.firstWhere((item) => item.id == 'ia');
    final guide = actions.firstWhere((item) => item.id == 'guia');
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF2B0B18), Color(0xFF120C12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _cyan.withOpacity(.23)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(19),
                  gradient: const LinearGradient(colors: [_cyan, _violet]),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.black,
                  size: 27,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SAUNA INTELLIGENCE',
                      style: GoogleFonts.inter(
                        color: _cyan,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Tu empresa, hablando contigo.',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            _admin
                ? 'Pregunta por la operación o información actual de Internet. Configura tu voz desde Administración para que IA y Guía intenten responder con ella.'
                : 'Pregunta por tu trabajo y dudas. La IA conserva protegida la información que no corresponde a tu rol.',
            style: GoogleFonts.inter(
              color: Colors.white60,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openBuilder(ai.builder),
                  icon: const Icon(Icons.mic_rounded),
                  label: Text(
                    'HABLAR CON IA',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Abrir Guía',
                onPressed: () => _openBuilder(guide.builder),
                icon: const Icon(Icons.explore_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pulse(List<ActividadModel> activities) {
    final open = activities.where((item) => item.estatus != 'completado').length;
    final urgent = activities.where((item) {
      return item.estatus != 'completado' &&
          item.fechaTermino.isBefore(DateTime.now());
    }).length;
    final done = activities.where((item) => item.estatus == 'completado').length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            _admin ? 'Pulso de operación' : 'Tu pulso',
            'actividades visibles',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value: '$open',
                  label: 'Abiertas',
                  color: _cyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  value: '$urgent',
                  label: 'Urgentes',
                  color: const Color(0xFFFF8E9E),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  value: '$done',
                  label: 'Listas',
                  color: _mint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _workCard(List<AppAction> actions) {
    final attendance = actions.firstWhere(
      (item) => item.id == 'asistencia',
      orElse: () => actions.first,
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 20, 18, 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12180C),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: _mint.withOpacity(.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.fingerprint_rounded, color: _mint, size: 27),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TU JORNADA',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Entrada · comida · regreso · salida',
                  style: GoogleFonts.inter(
                    color: const Color(0x7AFFFFFF),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _openBuilder(attendance.builder),
            child: const Text('ABRIR'),
          ),
        ],
      ),
    );
  }

  Widget _today(List<ActividadModel> activities) {
    final pending = activities
        .where((item) => item.estatus != 'completado')
        .take(3)
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            _admin ? 'Prioridades' : 'Lo siguiente',
            '${pending.length} visibles',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 10),
          if (pending.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                'No hay actividades pendientes visibles en este momento.',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 11.5),
              ),
            )
          else
            ...pending.map(
              (activity) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 42,
                      decoration: BoxDecoration(
                        color: activity.fechaTermino.isBefore(DateTime.now())
                            ? const Color(0xFFFF8E9E)
                            : _cyan,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activity.estatus,
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(
    String title,
    String detail, {
    EdgeInsets padding = const EdgeInsets.fromLTRB(18, 22, 18, 8),
  }) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            detail,
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(List<AppAction> actions) {
    if (actions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Text(
          'No encontré ese acceso. Prueba con otra palabra.',
          style: GoogleFonts.inter(color: Colors.white54),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.sizeOf(context).width >= 1000 ? 4 : (MediaQuery.sizeOf(context).width >= 650 ? 3 : 2),
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
        mainAxisExtent: 125.0 + (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(0, 60).toDouble(),
      ),
      itemBuilder: (_, index) {
        final action = actions[index];
        return InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openBuilder(action.builder),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: action.color.withOpacity(.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(action.icon, color: action.color, size: 23),
                const Spacer(),
                Text(
                  action.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  action.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 9.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bottomBar() {
    final actions = AppActionCatalog.forUser(widget.usuario);
    final ia = actions.firstWhere((item) => item.id == 'ia');
    final guide = actions.firstWhere((item) => item.id == 'guia');
    final messages = actions.firstWhere((item) => item.id == 'mensajes');
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xF20D1116),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Expanded(
              child: _BottomItem(
                icon: Icons.home_filled,
                label: 'Inicio',
                selected: true,
              ),
            ),
            Expanded(
              child: _BottomItem(
                icon: Icons.explore_rounded,
                label: 'Guía',
                onTap: () => _openBuilder(guide.builder),
              ),
            ),
            Expanded(
              child: _BottomItem(
                icon: Icons.auto_awesome_rounded,
                label: 'IA',
                accent: _cyan,
                onTap: () => _openBuilder(ia.builder),
              ),
            ),
            Expanded(
              child: _BottomItem(
                icon: Icons.forum_rounded,
                label: 'Chat',
                onTap: () => _openBuilder(messages.builder),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel() {
    return switch (widget.usuario.rol) {
      AppRoles.admin => 'Administración',
      AppRoles.almacenista => 'Almacén',
      AppRoles.maestro => 'Maestro',
      _ => 'Equipo',
    };
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _openBuilder(Widget Function(BuildContext) builder) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  const _RoundButton({
    required this.icon,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton.filledTonal(onPressed: onTap, icon: Icon(icon)),
        if (badge > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: Color(0xFFFF8E9E),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  badge > 99 ? '99' : '$badge',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _Metric({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111012),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.17)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.montserrat(
              color: color,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.inter(color: const Color(0x7AFFFFFF), fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color? accent;
  final VoidCallback? onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? (selected ? const Color(0xFFB7FF2A) : Colors.white54);
    return InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
