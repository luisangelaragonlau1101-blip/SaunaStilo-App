import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/actividad_model.dart';
import '../models/user_model.dart';

class ReconocimientosScreen extends StatelessWidget {
  final UserModel usuario;

  const ReconocimientosScreen({super.key, required this.usuario});

  static const _fondo = Color(0xFF050505);
  static const _oro = Color(0xFFFFDE21);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _fondo,
        title: Text(
          'RECONOCIMIENTOS',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
        builder: (context, usuariosSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: usuario.rol == AppRoles.admin
                ? FirebaseFirestore.instance.collection('actividades').snapshots()
                : FirebaseFirestore.instance
                      .collection('actividades')
                      .where(
                        'asignadoATrabajadorId',
                        isEqualTo: usuario.id,
                      )
                      .snapshots(),
            builder: (context, actividadesSnapshot) {
              if (usuariosSnapshot.hasError || actividadesSnapshot.hasError) {
                return const Center(
                  child: Text(
                    'No se pudieron cargar los reconocimientos.',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }
              if (!usuariosSnapshot.hasData || !actividadesSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: _oro));
              }
              final nombres = <String, String>{
                for (final doc in usuariosSnapshot.data!.docs)
                  doc.id: doc.data()['nombre']?.toString() ?? 'Trabajador',
              };
              final actividades = actividadesSnapshot.data!.docs
                  .map((doc) => ActividadModel.fromJson(doc.data(), doc.id))
                  .toList(growable: false);
              final resultados = _calcular(actividades, nombres);
              final visibles = usuario.rol == AppRoles.admin
                  ? resultados
                  : resultados
                        .where((resultado) => resultado.usuarioId == usuario.id)
                        .toList(growable: false);
              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                children: [
                  _encabezado(resultados),
                  const SizedBox(height: 20),
                  Text(
                    usuario.rol == AppRoles.admin
                        ? 'TABLERO DEL EQUIPO'
                        : 'MIS INSIGNIAS',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visibles.isEmpty)
                    _vacio()
                  else
                    ...visibles.asMap().entries.map(
                      (entry) => _TarjetaTrabajador(
                        posicion: entry.key + 1,
                        resultado: entry.value,
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _encabezado(List<_ResultadoTrabajador> resultados) {
    final lider = resultados.isEmpty ? null : resultados.first;
    final mes = DateFormat('MMMM yyyy', 'es').format(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFC400), Color(0xFFFF6D00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, size: 62, color: Colors.black),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DESEMPEÑO · ${mes.toUpperCase()}',
                  style: GoogleFonts.inter(
                    color: Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  lider == null ? 'Aún sin resultados' : lider.nombre,
                  style: GoogleFonts.montserrat(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  lider == null
                      ? 'Las insignias aparecerán al completar actividades.'
                      : '${lider.completadasMes} tareas terminadas este mes',
                  style: GoogleFonts.inter(color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vacio() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Completa tus primeras tareas con evidencia para desbloquear insignias.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(color: Colors.white54, height: 1.4),
      ),
    );
  }

  List<_ResultadoTrabajador> _calcular(
    List<ActividadModel> actividades,
    Map<String, String> nombres,
  ) {
    final ids = <String>{
      ...actividades.map((actividad) => actividad.asignadoATrabajadorId),
    }..removeWhere((id) => id.isEmpty);
    final ahora = DateTime.now();
    final resultados = ids.map((id) {
      final delTrabajador = actividades
          .where((actividad) => actividad.asignadoATrabajadorId == id)
          .toList(growable: false);
      final completadas = delTrabajador
          .where((actividad) => actividad.estatus == 'completado')
          .toList(growable: false);
      final completadasMes = completadas.where((actividad) {
        final fecha = actividad.completadoEn ?? actividad.ultimoAvance;
        return fecha != null && fecha.year == ahora.year && fecha.month == ahora.month;
      }).length;
      final evidencias = delTrabajador.fold<int>(
        0,
        (total, actividad) => total + actividad.totalEvidencias,
      );
      final puntuales = completadas
          .where(
            (actividad) =>
                actividad.completadoEn != null &&
                !actividad.completadoEn!.isAfter(actividad.fechaTermino),
          )
          .length;
      return _ResultadoTrabajador(
        usuarioId: id,
        nombre: nombres[id] ?? 'Trabajador',
        completadas: completadas.length,
        completadasMes: completadasMes,
        evidencias: evidencias,
        puntuales: puntuales,
      );
    }).toList(growable: true);
    resultados.sort((a, b) {
      final porMes = b.completadasMes.compareTo(a.completadasMes);
      if (porMes != 0) return porMes;
      return b.puntos.compareTo(a.puntos);
    });
    return resultados;
  }
}

class _TarjetaTrabajador extends StatelessWidget {
  final int posicion;
  final _ResultadoTrabajador resultado;

  const _TarjetaTrabajador({required this.posicion, required this.resultado});

  @override
  Widget build(BuildContext context) {
    final insignias = resultado.insignias;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: posicion == 1
              ? const Color(0xFFFFDE21).withOpacity(.5)
              : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: posicion == 1
                    ? const Color(0xFFFFDE21)
                    : Colors.white12,
                foregroundColor: posicion == 1 ? Colors.black : Colors.white,
                child: Text(
                  '$posicion',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resultado.nombre,
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${resultado.completadas} terminadas · ${resultado.evidencias} evidencias · ${resultado.puntos} pts',
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (insignias.isEmpty)
            Text(
              'Siguiente meta: completar la primera tarea con evidencia.',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: insignias
                  .map(
                    (insignia) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: insignia.color.withOpacity(.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: insignia.color.withOpacity(.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(insignia.icono, color: insignia.color, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            insignia.nombre,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _ResultadoTrabajador {
  final String usuarioId;
  final String nombre;
  final int completadas;
  final int completadasMes;
  final int evidencias;
  final int puntuales;

  const _ResultadoTrabajador({
    required this.usuarioId,
    required this.nombre,
    required this.completadas,
    required this.completadasMes,
    required this.evidencias,
    required this.puntuales,
  });

  int get puntos => completadas * 10 + evidencias * 2 + puntuales * 5;

  List<_Insignia> get insignias {
    final resultado = <_Insignia>[];
    if (completadas >= 1) {
      resultado.add(
        const _Insignia('Primera misión', Icons.flag_rounded, Color(0xFF00E676)),
      );
    }
    if (completadas >= 5) {
      resultado.add(
        const _Insignia('Cumplidor', Icons.task_alt_rounded, Color(0xFF00B0FF)),
      );
    }
    if (evidencias >= 10) {
      resultado.add(
        const _Insignia('Evidencia impecable', Icons.verified_rounded, Color(0xFF8B5CF6)),
      );
    }
    if (puntuales >= 5) {
      resultado.add(
        const _Insignia('Siempre a tiempo', Icons.timer_rounded, Color(0xFFFF9800)),
      );
    }
    if (completadasMes >= 10) {
      resultado.add(
        const _Insignia('Estrella del mes', Icons.star_rounded, Color(0xFFFFDE21)),
      );
    }
    return resultado;
  }
}

class _Insignia {
  final String nombre;
  final IconData icono;
  final Color color;

  const _Insignia(this.nombre, this.icono, this.color);
}
