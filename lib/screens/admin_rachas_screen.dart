import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../models/asistencia_model.dart';

class AdminRachasScreen extends StatefulWidget {
  final UserModel adminUser;

  const AdminRachasScreen({
    Key? key,
    required this.adminUser,
  }) : super(key: key);

  @override
  State<AdminRachasScreen> createState() => _AdminRachasScreenState();
}

class _AdminRachasScreenState extends State<AdminRachasScreen> {
  static const Color colorFondo = Color(0xFF121212);
  static const Color colorSuperficie = Color(0xFF1E1E1E);
  static const Color colorFuego = Color(0xFFFF9800);
  static const Color colorFuegoOscuro = Color(0xFFFF5722);
  static const Color colorHielo = Color(0xFF00E5FF); 

  // Definición de nuestras insignias / logros
  final List<Map<String, dynamic>> _insignias = [
    {
      'dias': 7,
      'nombre': 'Bronce',
      'subtitulo': '7 días',
      'color': const Color(0xFFCD7F32), 
      'icono': Icons.star_border_rounded,
    },
    {
      'dias': 15,
      'nombre': 'Plata',
      'subtitulo': '15 días',
      'color': const Color(0xFFC0C0C0), 
      'icono': Icons.star_half_rounded,
    },
    {
      'dias': 30,
      'nombre': 'Oro',
      'subtitulo': '30 días',
      'color': const Color(0xFFFFD700), 
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
      // Omitimos a los admins en el ranking
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

  Widget _buildMiniInsignias(int rachaMaxima) {
    return Row(
      children: _insignias.map((insignia) {
        bool desbloqueada = rachaMaxima >= insignia['dias'];
        if (!desbloqueada) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.all(4),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        backgroundColor: colorFondo,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Rachas del Equipo",
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getLeaderboard(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: colorHielo));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                "No hay trabajadores registrados aún.",
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
              ),
            );
          }

          final posiciones = snapshot.data!;

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            itemCount: posiciones.length,
            itemBuilder: (context, index) {
              final data = posiciones[index];
              final UserModel user = data['user'];
              final int racha = data['racha'];
              final int rachaMaxima = data['rachaMaxima'] ?? 0;

              Color badgeColor;
              IconData badgeIcon;
              if (index == 0) {
                badgeColor = const Color(0xFFFFD700); // Oro
                badgeIcon = Icons.emoji_events_rounded;
              } else if (index == 1) {
                badgeColor = const Color(0xFFC0C0C0); // Plata
                badgeIcon = Icons.military_tech_rounded;
              } else if (index == 2) {
                badgeColor = const Color(0xFFCD7F32); // Bronce
                badgeIcon = Icons.military_tech_rounded;
              } else {
                badgeColor = Colors.white24;
                badgeIcon = Icons.person_rounded;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: colorSuperficie,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: index == 0 ? badgeColor.withOpacity(0.5) : Colors.white.withOpacity(0.05),
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
                          color: index < 3 ? badgeColor : Colors.white38,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    // --- NUEVO AVATAR CON FOTO PARA ADMIN ---
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
                        if (index < 3)
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: colorSuperficie, 
                                shape: BoxShape.circle,
                              ),
                              child: Icon(badgeIcon, color: badgeColor, size: 14),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.nombre.isNotEmpty ? user.nombre : "Sin nombre",
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.rol.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Mininsignias añadidas aquí
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
                                color: racha > 0 ? colorFuego : Colors.white38,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.local_fire_department_rounded,
                              color: racha > 0 ? colorFuegoOscuro : Colors.white24,
                              size: 26,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Récord: $rachaMaxima",
                          style: GoogleFonts.inter(
                            color: Colors.white38,
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
      ),
    );
  }
}