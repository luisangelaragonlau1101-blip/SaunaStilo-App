import '../presentation/appearance.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/asistencia_model.dart';

class RachaAsistenciasScreen extends StatefulWidget {
  final UserModel usuario;
  final bool isAdmin;

  RachaAsistenciasScreen({
    Key? key,
    required this.usuario,
    required this.isAdmin,
  }) : super(key: key);

  @override
  State<RachaAsistenciasScreen> createState() => _RachaAsistenciasScreenState();
}

class _RachaAsistenciasScreenState extends State<RachaAsistenciasScreen> with SingleTickerProviderStateMixin {
  Color get colorFondo => StiloColors.surface;
  Color get colorSuperficie => StiloColors.surface;
  Color get colorFuego => Color(0xFFFF9800);
  Color get colorFuegoOscuro => Color(0xFFFF5722);
  Color get colorHielo => Color(0xFF00E5FF);

  late TabController _tabController;
  DateTime _mesSeleccionado = DateTime.now();

  // Definición de nuestras insignias / logros
  final List<Map<String, dynamic>> _insignias = [
    {
      'dias': 7,
      'nombre': 'Bronce',
      'subtitulo': '7 días',
      'color': Color(0xFFCD7F32),
      'icono': Icons.star_border_rounded,
    },
    {
      'dias': 15,
      'nombre': 'Plata',
      'subtitulo': '15 días',
      'color': Color(0xFFC0C0C0),
      'icono': Icons.star_half_rounded,
    },
    {
      'dias': 30,
      'nombre': 'Oro',
      'subtitulo': '30 días',
      'color': Color(0xFFFFD700),
      'icono': Icons.star_rounded,
    },
    {
      'dias': 50,
      'nombre': 'Diamante',
      'subtitulo': '50 días',
      'color': colorHielo,
      'icono': Icons.diamond_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, int> _calcularRachas(List<AsistenciaModel> asistencias) {
    if (asistencias.isEmpty) return {'actual': 0, 'maxima': 0};

    int rachaActual = 0;
    int rachaMaxima = 0;
    DateTime? ultimoDiaProcesado;

    var asistenciasCronologicas = asistencias.reversed.toList();

    for (var asistencia in asistenciasCronologicas) {
      if (ultimoDiaProcesado != null &&
          asistencia.fecha.year == ultimoDiaProcesado.year &&
          asistencia.fecha.month == ultimoDiaProcesado.month &&
          asistencia.fecha.day == ultimoDiaProcesado.day) {
        continue;
      }

      String estatusLimpio = asistencia.estatus.trim().toLowerCase();

      if (estatusLimpio == 'a_tiempo') {
        rachaActual++;
        if (rachaActual > rachaMaxima) rachaMaxima = rachaActual;
        ultimoDiaProcesado = asistencia.fecha;
      } else if (estatusLimpio == 'justificada') {
        ultimoDiaProcesado = asistencia.fecha;
        continue;
      } else {
        rachaActual = 0;
        ultimoDiaProcesado = asistencia.fecha;
      }
    }

    return {'actual': rachaActual, 'maxima': rachaMaxima};
  }

  Future<List<Map<String, dynamic>>> _getLeaderboard() async {
    final usersSnap = await FirebaseFirestore.instance.collection('usuarios').get();
    List<Map<String, dynamic>> leaderboard = [];

    for (var doc in usersSnap.docs) {
      final user = UserModel.fromFirestore(doc);
      if (user.rol == 'admin') continue;

      final asisSnap = await FirebaseFirestore.instance
          .collection('asistencias')
          .where('trabajadorId', isEqualTo: user.id)
          .orderBy('fecha', descending: true)
          .get();

      List<AsistenciaModel> asistencias = asisSnap.docs
          .map((d) => AsistenciaModel.fromFirestore(d))
          .toList();

      final rachas = _calcularRachas(asistencias);

      leaderboard.add({
        'user': user,
        'racha': rachas['actual'] ?? 0,
        'rachaMaxima': rachas['maxima'] ?? 0,
      });
    }

    leaderboard.sort((a, b) => b['racha'].compareTo(a['racha']));
    return leaderboard;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        backgroundColor: colorFondo,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: StiloColors.text, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Racha",
          style: GoogleFonts.montserrat(
            color: StiloColors.text,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorHielo,
          indicatorWeight: 3,
          labelColor: colorHielo,
          unselectedLabelColor: StiloColors.text.withValues(alpha: .54),
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
          tabs: [
            Tab(text: "PERSONAL"),
            Tab(text: "EQUIPO"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: BouncingScrollPhysics(),
        children: [
          _buildPersonalTab(),
          _buildTeamTab(),
        ],
      ),
    );
  }

  Widget _buildPersonalTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('asistencias')
          .where('trabajadorId', isEqualTo: widget.usuario.id)
          .orderBy('fecha', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                "Falta Índice en Firestore:\n\nRevisa la pestaña 'Run' o 'Logcat'. Haz clic en el enlace azul para crear el índice compuesto requerido.",
                style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: colorFuego));
        }

        List<AsistenciaModel> historial = [];
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          historial = snapshot.data!.docs.map((d) => AsistenciaModel.fromFirestore(d)).toList();
        }

        final rachas = _calcularRachas(historial);
        final int rachaActual = rachas['actual'] ?? 0;
        final int rachaMaxima = rachas['maxima'] ?? 0;

        return SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$rachaActual",
                        style: GoogleFonts.montserrat(
                          color: rachaActual > 0 ? colorFuego : StiloColors.text.withValues(alpha: .24),
                          fontSize: 72,
                          height: 1.0,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        "días seguidos!",
                        style: GoogleFonts.inter(
                          color: StiloColors.text.withValues(alpha: .54),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 12),
                      if (rachaMaxima > 0)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFD700).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color(0xFFFFD700).withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 16),
                              SizedBox(width: 6),
                              Text(
                                "Récord: $rachaMaxima días",
                                style: GoogleFonts.inter(
                                  color: Color(0xFFFFD700),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 110,
                    color: rachaActual > 0 ? colorFuego.withOpacity(0.8) : StiloColors.text.withValues(alpha: .10),
                  ),
                ],
              ),
              SizedBox(height: 30),

              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorSuperficie,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: StiloColors.text.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorHielo.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.ac_unit_rounded, color: colorHielo, size: 28),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "¡Sin faltas justificadas!",
                            style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Llega a tiempo para mantener tu racha viva.",
                            style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30),

              _buildSeccionInsignias(rachaMaxima),
              SizedBox(height: 30),

              Text(
                "Calendario de Racha",
                style: GoogleFonts.inter(
                  color: StiloColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),

              _buildCalendario(historial),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeccionInsignias(int rachaMaxima) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Tus Logros",
          style: GoogleFonts.inter(
            color: StiloColors.text,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: BouncingScrollPhysics(),
          child: Row(
            children: _insignias.map((insignia) {
              bool desbloqueada = rachaMaxima >= insignia['dias'];

              Color colorBase = desbloqueada ? insignia['color'] : StiloColors.text.withValues(alpha: .12);
              Color colorFondo = desbloqueada ? insignia['color'].withOpacity(0.15) : colorSuperficie;

              return Container(
                margin: EdgeInsets.only(right: 16),
                padding: EdgeInsets.all(16),
                width: 110,
                decoration: BoxDecoration(
                  color: colorFondo,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: desbloqueada ? insignia['color'].withOpacity(0.5) : StiloColors.text.withOpacity(0.05),
                    width: desbloqueada ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: desbloqueada ? insignia['color'].withOpacity(0.2) : StiloColors.background.withValues(alpha: .26),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        insignia['icono'],
                        color: colorBase,
                        size: 32,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      insignia['nombre'],
                      style: GoogleFonts.inter(
                        color: desbloqueada ? StiloColors.text : StiloColors.text.withValues(alpha: .38),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      insignia['subtitulo'],
                      style: GoogleFonts.inter(
                        color: desbloqueada ? insignia['color'] : StiloColors.text.withValues(alpha: .24),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendario(List<AsistenciaModel> historial) {
    int diasEnMes = DateUtils.getDaysInMonth(_mesSeleccionado.year, _mesSeleccionado.month);
    int primerDiaSemana = DateTime(_mesSeleccionado.year, _mesSeleccionado.month, 1).weekday;
    int offset = primerDiaSemana == 7 ? 0 : primerDiaSemana;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorSuperficie,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: StiloColors.text.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left_rounded, color: StiloColors.text),
                onPressed: () {
                  setState(() {
                    _mesSeleccionado = DateTime(_mesSeleccionado.year, _mesSeleccionado.month - 1, 1);
                  });
                },
              ),
              Text(
                DateFormat('MMMM yyyy', 'es').format(_mesSeleccionado).toUpperCase(),
                style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded, color: StiloColors.text),
                onPressed: () {
                  setState(() {
                    _mesSeleccionado = DateTime(_mesSeleccionado.year, _mesSeleccionado.month + 1, 1);
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ["Do", "Lu", "Ma", "Mi", "Ju", "Vi", "Sa"].map((dia) {
              return SizedBox(
                width: 30,
                child: Center(
                  child: Text(
                    dia,
                    style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: offset + diasEnMes,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 12,
              crossAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              if (index < offset) {
                return SizedBox.shrink();
              }

              int numeroDia = index - offset + 1;
              DateTime fechaActual = DateTime(_mesSeleccionado.year, _mesSeleccionado.month, numeroDia);
              DateTime hoy = DateTime.now();
              bool esHoy = fechaActual.year == hoy.year && fechaActual.month == hoy.month && fechaActual.day == hoy.day;
              bool esFuturo = fechaActual.isAfter(hoy);

              AsistenciaModel? registroDia;
              try {
                registroDia = historial.firstWhere((a) => a.fecha.year == fechaActual.year && a.fecha.month == fechaActual.month && a.fecha.day == fechaActual.day);
              } catch (e) {
                registroDia = null;
              }

              String estatusLimpio = registroDia?.estatus.trim().toLowerCase() ?? '';
              bool aTiempo = estatusLimpio == 'a_tiempo';
              bool retardoOFalta = estatusLimpio == 'retardo' || estatusLimpio == 'falta';

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: aTiempo
                        ? colorFuego.withOpacity(0.15)
                        : (esHoy ? StiloColors.text.withValues(alpha: .10) : Colors.transparent),
                      border: Border.all(
                        color: aTiempo ? colorFuego : (esHoy ? StiloColors.text.withValues(alpha: .30) : Colors.transparent),
                        width: esHoy ? 1.5 : 0,
                      )
                    ),
                    child: Center(
                      child: aTiempo
                          ? Icon(Icons.local_fire_department_rounded, color: colorFuego, size: 24)
                          : Text(
                              "$numeroDia",
                              style: GoogleFonts.inter(
                                color: esFuturo ? StiloColors.text.withValues(alpha: .24) : (retardoOFalta ? Colors.redAccent : StiloColors.text),
                                fontWeight: esHoy || aTiempo ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                  if (retardoOFalta)
                    Positioned(
                      bottom: 2,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // NUEVO: Mini insignias visibles para la tarjeta de equipo
  Widget _buildMiniInsignias(int rachaMaxima) {
    return Row(
      children: _insignias.map((insignia) {
        bool desbloqueada = rachaMaxima >= insignia['dias'];
        if (!desbloqueada) return SizedBox.shrink();
        return Container(
          margin: EdgeInsets.only(right: 6),
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: insignia['color'].withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            insignia['icono'],
            color: insignia['color'],
            size: 13,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTeamTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getLeaderboard(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: colorHielo));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              "Sin datos del equipo aún.",
              style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 16),
            ),
          );
        }

        final posiciones = snapshot.data!;

        return ListView.builder(
          physics: BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          itemCount: posiciones.length,
          itemBuilder: (context, index) {
            final data = posiciones[index];
            final UserModel user = data['user'];
            final int racha = data['racha'];
            final int rachaMaxima = data['rachaMaxima'] ?? 0;

            Color badgeColor;
            IconData badgeIcon;
            if (index == 0) {
              badgeColor = Color(0xFFFFD700);
              badgeIcon = Icons.emoji_events_rounded;
            } else if (index == 1) {
              badgeColor = Color(0xFFC0C0C0);
              badgeIcon = Icons.military_tech_rounded;
            } else if (index == 2) {
              badgeColor = Color(0xFFCD7F32);
              badgeIcon = Icons.military_tech_rounded;
            } else {
              badgeColor = StiloColors.text.withValues(alpha: .24);
              badgeIcon = Icons.person_rounded;
            }

            return Container(
              margin: EdgeInsets.only(bottom: 16),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: colorSuperficie,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: index == 0 ? badgeColor.withOpacity(0.5) : StiloColors.text.withOpacity(0.05),
                  width: index == 0 ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [

SizedBox(
                    width: 25,
                    child: Text(
                      "${index + 1}",
                      style: GoogleFonts.montserrat(
                        color: index < 3 ? badgeColor : StiloColors.text.withValues(alpha: .38),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // --- INICIO DEL NUEVO AVATAR CON FOTO ---
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        backgroundColor: badgeColor.withOpacity(0.15),
                        radius: 22,
                        backgroundImage: (user.fotoUrl != null && user.fotoUrl!.isNotEmpty)
                            ? NetworkImage(user.fotoUrl!)
                            : null,
                        child: (user.fotoUrl == null || user.fotoUrl!.isEmpty)
                            ? Icon(badgeIcon, color: badgeColor, size: 24)
                            : null,
                      ),
                      // Si está en el Top 3, agregamos su trofeo/medalla en la esquina
                      if (index < 3)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: colorSuperficie, // Usa el fondo para hacer un recorte limpio
                              shape: BoxShape.circle,
                            ),
                            child: Icon(badgeIcon, color: badgeColor, size: 14),
                          ),
                        ),
                    ],
                  ),

                  SizedBox(width: 14),


                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.nombre.isNotEmpty ? user.nombre : "Sin nombre",
                          style: GoogleFonts.inter(
                            color: StiloColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          user.rol.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: StiloColors.text.withValues(alpha: .54),
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        // Mostramos las insignias desbloqueadas por el compañero
                        _buildMiniInsignias(rachaMaxima),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Text(
                            "$racha",
                            style: GoogleFonts.montserrat(
                              color: racha > 0 ? colorFuego : StiloColors.text.withValues(alpha: .38),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.local_fire_department_rounded,
                            color: racha > 0 ? colorFuegoOscuro : StiloColors.text.withValues(alpha: .24),
                            size: 24,
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Récord: $rachaMaxima",
                        style: GoogleFonts.inter(
                          color: StiloColors.text.withValues(alpha: .38),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
