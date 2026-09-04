import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../models/asistencia_model.dart';
import '../services/asistencia_service.dart';

import 'dart:async';
import 'package:geolocator/geolocator.dart';

class TrabajadorAsistenciaScreen extends StatefulWidget {
  final UserModel trabajador;

  const TrabajadorAsistenciaScreen({Key? key, required this.trabajador}) : super(key: key);

  @override
  State<TrabajadorAsistenciaScreen> createState() => _TrabajadorAsistenciaScreenState();
}

class _TrabajadorAsistenciaScreenState extends State<TrabajadorAsistenciaScreen> {
  final AsistenciaService _asistenciaService = AsistenciaService();
  final TextEditingController _motivoFaltaController = TextEditingController();
  
  XFile? _evidenciaFile;
  bool _isLoading = false;
  bool _isEnviandoJustificacion = false; 

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<ServiceStatus>? _serviceStatusStream;

  // VARIABLES PARA EL INDICADOR GPS
  String _mensajeGps = "Buscando señal GPS...";
  Color _colorGps = Colors.orangeAccent;
  bool _isGpsBuscando = true;
  bool _registrandoEntrada = false;
  bool _entradaConfirmada = false;
  
  // Coordenadas y configuración de la empresa
  final List<Map<String, dynamic>> _zonasEmpresa = [
    {'nombre': 'Sauna Stilo', 'lat': 19.26247565075755, 'lon': -98.89430986717343, 'radio': 35.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.26236781757325, 'lon': -98.89404650777578, 'radio': 20.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.2622796818614, 'lon': -98.89399453997612, 'radio': 20.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.262236850336194, 'lon': -98.89410702511668, 'radio': 20.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.26225529052317, 'lon': -98.89396402984858, 'radio': 20.0},
    {'nombre': 'Sauna Stilo', 'lat': 19.262421336025, 'lon': -98.89423744753003, 'radio': 10.0},
  ];

  // --- UTILIDAD PARA FORZAR LA HORA DE LA EMPRESA (GMT-6) ---
  String _formatearHoraEmpresa(DateTime? hora) {
    if (hora == null) return '--:--';
    DateTime horaUtc = hora.toUtc();
    DateTime horaRealEmpresa = horaUtc.subtract(const Duration(hours: 6));
    return DateFormat('HH:mm').format(horaRealEmpresa);
  }

  @override
  void initState() {
    super.initState();
    _verificarEstadoGPSInicial();
    _escucharEstadoGPS();
  }

  Future<void> _verificarEstadoGPSInicial() async {
    bool gpsEncendido = await Geolocator.isLocationServiceEnabled();
    if (gpsEncendido) {
      _iniciarRadarGPS();
    } else {
      if (mounted) {
        setState(() {
          _isGpsBuscando = false;
          _mensajeGps = "Ubicación apagada. Toca para encenderla.";
          _colorGps = Colors.red;
        });
      }
    }
  }

  void _escucharEstadoGPS() {
    _serviceStatusStream = Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
      if (status == ServiceStatus.enabled) {
        if (mounted) {
          setState(() {
            _isGpsBuscando = true;
            _mensajeGps = "Buscando señal GPS...";
            _colorGps = Colors.orangeAccent;
          });
        }
        _iniciarRadarGPS();
      } else {
        _positionStream?.cancel();
        if (mounted) {
          setState(() {
            _isGpsBuscando = false;
            _mensajeGps = "Ubicación apagada. Toca para encenderla.";
            _colorGps = Colors.red;
          });
        }
      }
    });
  }

  void _iniciarRadarGPS() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5, 
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      
      if (position.accuracy <= 60.0) {
        bool estaAdentro = false;
        String nombreDeLaZona = ""; 
        double distanciaMinima = double.infinity;

        for (var zona in _zonasEmpresa) {
          double distanciaActual = Geolocator.distanceBetween(
            position.latitude, position.longitude, 
            zona['lat'], zona['lon']
          );

          if (distanciaActual <= zona['radio']) {
            if (distanciaActual < distanciaMinima) {
              estaAdentro = true;
              distanciaMinima = distanciaActual;
              nombreDeLaZona = zona['nombre'];
            }
          }
        }
  
        String coordsActuales = "${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}";
        
        if (mounted) {
          setState(() {
            _isGpsBuscando = false;
            if (estaAdentro) {
              _mensajeGps = "$nombreDeLaZona\n$coordsActuales"; 
              _colorGps = Colors.greenAccent;
            } else {
              _mensajeGps = "Fuera de rango\n$coordsActuales";
              _colorGps = Colors.redAccent;
            }
          });
        }

        if (estaAdentro && !_registrandoEntrada && !_entradaConfirmada) {
          _registrandoEntrada = true;
          _asistenciaService.registrarEntradaAutomatica(
            trabajadorId: widget.trabajador.id,
            zonasPermitidas: _zonasEmpresa,
            horaEntradaConfig: widget.trabajador.horaEntrada ?? '08:00',
            toleranciaMinutos: widget.trabajador.toleranciaMinutos ?? 15,
          ).then((_) {
            _entradaConfirmada = true;
          }).catchError((_) {
            // El radar continúa mostrando la ubicación aunque falle la red.
          }).whenComplete(() {
            _registrandoEntrada = false;
          });
        }
      }
    });
  }

  Future<void> _forzarLecturaGPS() async {
    bool gpsEncendido = await Geolocator.isLocationServiceEnabled();
    
    if (!gpsEncendido) {
      await Geolocator.openLocationSettings();
      return; 
    }

    setState(() {
      _isGpsBuscando = true;
      _mensajeGps = "Obteniendo coordenadas...";
      _colorGps = Colors.orangeAccent;
    });
    
   try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      
      String coordsActuales = "${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}";

      bool estaAdentro = false;
      String nombreDeLaZona = "";
      double distanciaMinima = double.infinity;

      for (var zona in _zonasEmpresa) {
        double distanciaActual = Geolocator.distanceBetween(
          position.latitude, position.longitude, 
          zona['lat'], zona['lon']
        );

        if (distanciaActual <= zona['radio']) {
          if (distanciaActual < distanciaMinima) {
            estaAdentro = true;
            distanciaMinima = distanciaActual;
            nombreDeLaZona = zona['nombre'];
          }
        }
      }

      if (mounted) {
        setState(() {
          _isGpsBuscando = false;
          if (estaAdentro) {
            _mensajeGps = "$nombreDeLaZona\n$coordsActuales"; 
            _colorGps = Colors.greenAccent;
          } else {
            _mensajeGps = "Fuera de rango\n$coordsActuales";
            _colorGps = Colors.redAccent;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGpsBuscando = false;
          _mensajeGps = "Error al leer GPS.\nRevisa tus permisos.";
          _colorGps = Colors.red;
        });
      }
    }
  }

  Future<void> _seleccionarFoto(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
    if (image != null) {
      setState(() {
        _evidenciaFile = image;
      });
    }
  }

  void _mostrarOpcionesEvidencia() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.white),
              title: Text('Tomar Foto', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _seleccionarFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.white),
              title: Text('Elegir de la Galería', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _seleccionarFoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _verImagenCompleta() {
    if (_evidenciaFile == null) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(_evidenciaFile!.path), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _serviceStatusStream?.cancel();
    _motivoFaltaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    DateTime ahora = DateTime.now();
    String docId = "${widget.trabajador.id}_${DateFormat('yyyyMMdd').format(ahora)}";

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("Mi Panel de Asistencia", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Color(0xFF00B0FF)),
            onPressed: () => _mostrarMiHistorial(context),
            tooltip: 'Ver mi historial',
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('asistencias').doc(docId).snapshots(),
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }

          AsistenciaModel? asistencia;
          if (snapshot.hasData && snapshot.data!.exists) {
            asistencia = AsistenciaModel.fromFirestore(snapshot.data!);
          }

          // --- CÁLCULO DE MÚLTIPLES BONOS Y MULTAS PARA LA VISTA PRINCIPAL ---
          double bonoTotal = (asistencia?.listaBonos ?? []).fold(0.0, (sum, item) => sum + (item['monto'] as num? ?? 0.0).toDouble());
          double multaTotal = (asistencia?.listaMultas ?? []).fold(0.0, (sum, item) => sum + (item['monto'] as num? ?? 0.0).toDouble());
          bool tieneBono = bonoTotal > 0;
          bool tieneMulta = multaTotal > 0;
          String motivosBono = (asistencia?.listaBonos ?? []).map((e) => e['motivo'].toString()).where((e) => e.isNotEmpty).join(' • ');
          String motivosMulta = (asistencia?.listaMultas ?? []).map((e) => e['motivo'].toString()).where((e) => e.isNotEmpty).join(' • ');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                // --- 1. INDICADOR GPS EN TIEMPO REAL ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _colorGps.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _colorGps.withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      _isGpsBuscando 
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent))
                          : Icon(Icons.my_location_rounded, color: _colorGps, size: 20),
                      
                      const SizedBox(width: 12),
                      
                      Expanded(
                        child: Text(
                          _mensajeGps, 
                          style: GoogleFonts.inter(color: _colorGps, fontWeight: FontWeight.w600, fontSize: 13)
                        ),
                      ),
                      
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                          onPressed: _isGpsBuscando ? null : _forzarLecturaGPS,
                          tooltip: 'Recargar ubicación',
                          padding: const EdgeInsets.all(8),
                        ),
                      )
                    ],
                  ),
                ),

                // --- 2. TARJETA DE ESTATUS DE ENTRADA Y SALIDA ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("ESTATUS DE HOY", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF00B0FF), letterSpacing: 1)),
                          Icon(
                            asistencia?.ubicacionValida == true ? Icons.location_on_rounded : Icons.location_off_rounded,
                            color: asistencia?.ubicacionValida == true ? Colors.greenAccent : Colors.redAccent,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        asistencia != null ? "Asistencia Registrada" : "Sin registro de entrada",
                        style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      
                      Text(
                        asistencia?.horaEntrada != null 
                            ? "Entrada: ${_formatearHoraEmpresa(asistencia!.horaEntrada)} (${asistencia.estatus.toUpperCase()})"
                            : "Acércate a la empresa para registrar tu asistencia automáticamente.",
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                      ),

                      if (asistencia?.horaEntrada != null) ...[
                        const SizedBox(height: 16),
                        if (asistencia?.horaSalida != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  "Salida registrada: ${_formatearHoraEmpresa(asistencia!.horaSalida)}",
                                  style: GoogleFonts.inter(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            ),
                            onPressed: _isLoading ? null : () async {
                              bool? confirmar = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1E1E),
                                  title: Text("¿Registrar Salida?", style: GoogleFonts.montserrat(color: Colors.white)),
                                  content: Text("¿Estás seguro de que deseas registrar tu salida de la empresa en este momento?", style: GoogleFonts.inter(color: Colors.white70)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text("Cancelar", style: GoogleFonts.inter(color: Colors.white54)),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                      onPressed: () => Navigator.pop(context, true),
                                      child: Text("Sí, salir", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmar != true) return;

                              setState(() => _isLoading = true);
                              try {
                                Map<String, dynamic> resultado = await _asistenciaService.registrarSalida(
                                  trabajadorId: widget.trabajador.id,
                                  zonasPermitidas: _zonasEmpresa,
                                  horaSalidaOficial: widget.trabajador.horaSalida,
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(resultado['mensaje']?.toString() ?? 'Salida registrada.'),
                                      backgroundColor: resultado['exito'] == true ? Colors.green : Colors.redAccent,
                                    ),
                                  );
                                }
                              } catch (error) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.toString()), backgroundColor: Colors.redAccent),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _isLoading = false);
                              }
                            },
                            icon: _isLoading 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.logout_rounded, size: 18),
                            label: Text("Registrar Salida", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          ),
                      ],

                      if (asistencia?.historialModificaciones != null && asistencia!.historialModificaciones!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF1E1E1E),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Text("Historial de Cambios", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: asistencia!.historialModificaciones!.map((nota) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Text(nota, style: GoogleFonts.inter(color: Colors.orangeAccent, fontSize: 13)),
                                  )).toList(),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text("Cerrar", style: GoogleFonts.inter(color: Colors.white54)),
                                  )
                                ],
                              )
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orangeAccent.withOpacity(0.3))
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.manage_history_rounded, color: Colors.orangeAccent, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  "Ver modificaciones de mi horario", 
                                  style: GoogleFonts.inter(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- 3. TARJETA DE HORA DE COMIDA ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("HORA DE COMIDA", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFFF9800), letterSpacing: 1)),
                      const SizedBox(height: 14),
                      Text(
                        "Estatus: ${(asistencia?.estatusComida ?? 'NINGUNA').toUpperCase()}",
                        style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF9800),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: (asistencia?.estatusComida == 'ninguna' || asistencia?.estatusComida == null)
                                  ? () async {
                                      try {
                                        await _asistenciaService.solicitarSalidaComida(widget.trabajador.id);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Solicitud de comida enviada al administrador")));
                                        }
                                      } catch (error) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(error.toString()), backgroundColor: Colors.redAccent),
                                          );
                                        }
                                      }
                                    }
                                  : null,
                              icon: const Icon(Icons.restaurant_rounded, size: 18),
                              label: Text("A COMER", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00E676),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: asistencia?.estatusComida == 'comiendo'
                                  ? () async {
                                      try {
                                        Map<String, dynamic> resultado = await _asistenciaService.registrarRegresoComida(
                                          trabajadorId: widget.trabajador.id,
                                          zonasPermitidas: _zonasEmpresa,
                                        );
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(resultado['mensaje']?.toString() ?? 'Regreso registrado.'),
                                              backgroundColor: resultado['exito'] == true ? Colors.green : Colors.redAccent,
                                            ),
                                          );
                                        }
                                      } catch (error) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(error.toString()), backgroundColor: Colors.redAccent),
                                          );
                                        }
                                      }
                                    }
                                  : null,
                              icon: const Icon(Icons.login_rounded, size: 18),
                              label: Text("Regresar", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- 4. APARTADO DE JUSTIFICACIÓN DE FALTAS ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("JUSTIFICAR FALTA / RETARDO", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.redAccent, letterSpacing: 1)),
                      const SizedBox(height: 14),

                      if (asistencia?.estatusJustificacion != null && asistencia!.estatusJustificacion != 'ninguna') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: asistencia.estatusJustificacion == 'aprobada'
                                ? Colors.greenAccent.withOpacity(0.1)
                                : asistencia.estatusJustificacion == 'rechazada'
                                    ? Colors.redAccent.withOpacity(0.1)
                                    : Colors.orangeAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: asistencia.estatusJustificacion == 'aprobada'
                                  ? Colors.greenAccent.withOpacity(0.3)
                                  : asistencia.estatusJustificacion == 'rechazada'
                                      ? Colors.redAccent.withOpacity(0.3)
                                      : Colors.orangeAccent.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    asistencia.estatusJustificacion == 'aprobada'
                                        ? Icons.check_circle_rounded
                                        : asistencia.estatusJustificacion == 'rechazada'
                                            ? Icons.cancel_rounded
                                            : Icons.hourglass_top_rounded,
                                    color: asistencia.estatusJustificacion == 'aprobada'
                                        ? Colors.greenAccent
                                        : asistencia.estatusJustificacion == 'rechazada'
                                            ? Colors.redAccent
                                            : Colors.orangeAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "ESTATUS: ${asistencia.estatusJustificacion.replaceAll('_', ' ').toUpperCase()}",
                                    style: GoogleFonts.inter(
                                      color: asistencia.estatusJustificacion == 'aprobada'
                                          ? Colors.greenAccent
                                          : asistencia.estatusJustificacion == 'rechazada'
                                              ? Colors.redAccent
                                              : Colors.orangeAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text("Tu motivo:", style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(asistencia.motivoFalta ?? 'Sin motivo especificado', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                              
                              if (asistencia.observacionesAdmin != null && asistencia.observacionesAdmin.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text("Nota del administrador:", style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 2),
                                Text(asistencia.observacionesAdmin, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                              ],

                              if (asistencia.evidenciaJustificacionUrl != null && asistencia.evidenciaJustificacionUrl!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text("Evidencia enviada:", style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    asistencia.evidenciaJustificacionUrl!,
                                    height: 100,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Text("No se pudo cargar la imagen", style: TextStyle(color: Colors.white54)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else ...[
                        TextField(
                          controller: _motivoFaltaController,
                          style: GoogleFonts.inter(color: Colors.white),
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: "Escribe el motivo de tu falta o retardo...",
                            hintStyle: GoogleFonts.inter(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.black,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        if (_evidenciaFile != null) ...[
                          Text("Evidencia adjuntada (toca para ver):", style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 8),
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: _verImagenCompleta,
                                child: Container(
                                  height: 120,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.greenAccent.withOpacity(0.3), width: 2),
                                    image: DecorationImage(
                                      image: FileImage(File(_evidenciaFile!.path)),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => setState(() => _evidenciaFile = null),
                                  child: Container(
                                  padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white10,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _mostrarOpcionesEvidencia,
                            icon: const Icon(Icons.add_a_photo_rounded, size: 20),
                            label: Text("Adjuntar Evidencia", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 16),
                        ],

                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isEnviandoJustificacion ? null : () async {
                            if (_motivoFaltaController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Por favor escribe el motivo"), backgroundColor: Colors.redAccent));
                              return;
                            }
                            if (_evidenciaFile == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Falta adjuntar una foto de evidencia"), backgroundColor: Colors.redAccent));
                              return;
                            }
                            
                            setState(() => _isEnviandoJustificacion = true);

                            try {
                              await _asistenciaService.enviarJustificacion(
                                trabajadorId: widget.trabajador.id,
                                fechaAsistencia: ahora,
                                motivo: _motivoFaltaController.text,
                                evidenciaUrl: _evidenciaFile!.path, 
                              );
                              
                              _motivoFaltaController.clear();
                              setState(() {
                                _evidenciaFile = null;
                                _isEnviandoJustificacion = false;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Justificación enviada para revisión"), backgroundColor: Colors.green)
                              );
                            } catch (e) {
                              setState(() => _isEnviandoJustificacion = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error al enviar: $e"), backgroundColor: Colors.redAccent)
                              );
                            }
                          },
                          icon: _isEnviandoJustificacion 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_rounded, size: 20),
                          label: Text("Enviar Justificación", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

 void _mostrarMiHistorial(BuildContext context) {
    final Color bgDark = const Color(0xFF09090B);
    final Color cardDark = const Color(0xFF18181B);
    final Color primaryPurple = const Color(0xFF8B5CF6);
    final Color textMuted = const Color(0xFFA1A1AA);

    // --- CÁLCULO DEL PAGO BASE ---
    double sueldoBase = widget.trabajador.sueldoBaseSemanal ?? 0.0;
    bool trabajaSabados = widget.trabajador.trabajaSabados ?? false;
    double horasPorDia = 8.0;

    try {
      if (widget.trabajador.horaEntrada != null && widget.trabajador.horaSalida != null) {
        DateTime entrada = DateFormat('HH:mm').parse(widget.trabajador.horaEntrada!);
        DateTime salida = DateFormat('HH:mm').parse(widget.trabajador.horaSalida!);
        horasPorDia = salida.difference(entrada).inMinutes / 60.0;
        if (horasPorDia < 0) horasPorDia += 24.0;
      }
    } catch (e) {
      debugPrint("Error parseando horario: $e");
    }

    int diasBase = trabajaSabados ? 6 : 5;
    double horasBaseSemana = diasBase * horasPorDia;
    double precioPorHora = horasBaseSemana > 0 ? sueldoBase / horasBaseSemana : 0.0;

    DateTime semanaSeleccionada = DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: bgDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            
            DateTime inicioSemana = semanaSeleccionada.subtract(Duration(days: semanaSeleccionada.weekday - 1));
            inicioSemana = DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day);
            DateTime finSemana = inicioSemana.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

            void _cambiarSemana(int offset) {
              setStateModal(() {
                semanaSeleccionada = semanaSeleccionada.add(Duration(days: 7 * offset));
              });
            }

            // Widget para Entrada/Salida (Solo lectura)
            Widget _buildReadonlyHoraBox({required IconData icono, required String titulo, required DateTime? hora}) {
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icono, color: textMuted, size: 16),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titulo.toUpperCase(), style: GoogleFonts.inter(color: textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                          Text(
                            _formatearHoraEmpresa(hora),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              );
            }

            // Widget para los detalles de la hora de comida
            Widget _buildInfoHora({required IconData icono, required String titulo, required DateTime? hora}) {
              return Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icono, color: Colors.white70, size: 14),
                    ),
                    const SizedBox(width: 6), 
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo, 
                            style: GoogleFonts.inter(color: textMuted, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatearHoraEmpresa(hora),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85, 
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 50, height: 6, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 24),
                    
                    // --- CABECERA ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: primaryPurple.withOpacity(0.15), shape: BoxShape.circle),
                            child: Icon(Icons.history_rounded, color: primaryPurple, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text("Mi Historial y Nómina", style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- SELECTOR DE SEMANA ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => _cambiarSemana(-1),
                            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                            style: IconButton.styleFrom(backgroundColor: cardDark),
                          ),
                          Column(
                            children: [
                              Text(
                                "SEMANA DEL",
                                style: GoogleFonts.inter(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                              Text(
                                "${DateFormat('d MMM', 'es').format(inicioSemana)} - ${DateFormat('d MMM yyyy', 'es').format(finSemana)}".toUpperCase(),
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => _cambiarSemana(1),
                            icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                            style: IconButton.styleFrom(backgroundColor: cardDark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- LISTA Y CÁLCULOS ---
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('asistencias')
                            .where('trabajadorId', isEqualTo: widget.trabajador.id)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator(color: primaryPurple));
                          }

                          var allDocs = snapshot.data?.docs ?? [];
                          
                          var docsSemana = allDocs.where((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            if (data['fecha'] == null) return false;
                            DateTime fecha = (data['fecha'] as Timestamp).toDate();
                            return fecha.isAfter(inicioSemana.subtract(const Duration(seconds: 1))) && 
                                   fecha.isBefore(finSemana.add(const Duration(seconds: 1)));
                          }).toList();

                          docsSemana.sort((a, b) {
                            Timestamp tA = (a.data() as Map)['fecha'] ?? Timestamp.now();
                            Timestamp tB = (b.data() as Map)['fecha'] ?? Timestamp.now();
                            return tB.compareTo(tA); 
                          });

                          Duration totalHorasSemana = Duration.zero;
                          int diasConRetardo = 0; 
                          double totalBonosSemana = 0.0;
                          double totalMultasSemana = 0.0;

                          for (var doc in docsSemana) {
                            AsistenciaModel asis = AsistenciaModel.fromFirestore(doc);
                            
                            // Acumular los bonos y multas de la semana
                            if (asis.listaBonos != null) {
                              for(var b in asis.listaBonos!) {
                                totalBonosSemana += (b['monto'] as num? ?? 0.0).toDouble();
                              }
                            }
                            if (asis.listaMultas != null) {
                              for(var m in asis.listaMultas!) {
                                totalMultasSemana += (m['monto'] as num? ?? 0.0).toDouble();
                              }
                            }

                            // --- LÓGICA DE INCAPACIDAD ---
                            if (asis.estatus == 'incapacidad_pagada') {
                              int horas = horasPorDia.toInt();
                              int minutos = ((horasPorDia - horas) * 60).toInt();
                              totalHorasSemana += Duration(hours: horas, minutes: minutos);
                              continue;
                            }
                            
                            if (asis.fecha != null && asis.horaEntrada != null && asis.horaSalida != null) {
                              
                              DateTime entradaReal = asis.horaEntrada!;

                              // 1. Lógica de Retardo: Redondear a la siguiente hora
                              if (asis.estatus.toLowerCase() == 'retardo') {
                                diasConRetardo++;
                                
                                // RETARDOS
                                entradaReal = DateTime(
                                  entradaReal.year,
                                  entradaReal.month,
                                  entradaReal.day,
                                  entradaReal.hour + 1, // Brinca a la siguiente hora
                                  0, // Minutos en 0
                                );
                              }

                              // 2. Tiempo total del día (usando la entrada penalizada si hubo retardo)
                              Duration horasDelDia = asis.horaSalida!.difference(entradaReal);
                              
                              // Evitamos números negativos si por alguna razón salió antes de la hora castigada
                              if (horasDelDia.isNegative) horasDelDia = Duration.zero; 

                              totalHorasSemana += horasDelDia;
                            }
                          }

                          int horas = totalHorasSemana.inHours;
                          int minutos = totalHorasSemana.inMinutes.remainder(60);

                          // --- 4. CÁLCULO DE NÓMINA ---
                          
                          // Las horas totales ya traen el castigo aplicado desde el cálculo diario
                          double horasPagables = totalHorasSemana.inMinutes / 60.0;

                          // Calculamos el pago final, sumamos bonos ganados y restamos multas
                          double pagoTotal = (horasPagables * precioPorHora) + totalBonosSemana - totalMultasSemana;

                          // Protección de negocio: evitar saldos negativos
                          if (pagoTotal < 0) pagoTotal = 0.0;

                          return Column(
                            children: [
                              // --- TARJETA RESUMEN DE NÓMINA ---
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [primaryPurple.withOpacity(0.2), cardDark],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: primaryPurple.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("TOTAL TRABAJADO", style: GoogleFonts.inter(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text(
                                                "${horas}h ${minutos}m",
                                                style: GoogleFonts.montserrat(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          if (diasConRetardo > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                              ),
                                              child: Text(
                                                "-$diasConRetardo HR\nPOR RETARDO",
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Divider(color: Colors.white10, height: 1),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("PAGO ESTIMADO", style: GoogleFonts.inter(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text(
                                                "\$${pagoTotal.toStringAsFixed(2)}",
                                                style: GoogleFonts.montserrat(color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text("Base: \$${sueldoBase.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
                                              const SizedBox(height: 2),
                                              Text("Hora: \$${precioPorHora.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
                                              if (totalBonosSemana > 0) ...[
                                                const SizedBox(height: 2),
                                                Text("Bonos: +\$${totalBonosSemana.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ],
                                              if (totalMultasSemana > 0) ...[
                                                const SizedBox(height: 2),
                                                Text("Multas: -\$${totalMultasSemana.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ]
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              if (docsSemana.isEmpty)
                                Expanded(
                                  child: Center(
                                    child: Text("Sin registros para esta semana.", style: GoogleFonts.inter(color: textMuted)),
                                  ),
                                )
                              else
                                Expanded(
                                  child: ListView.builder(
                                    controller: scrollController,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                    itemCount: docsSemana.length,
                                    itemBuilder: (context, index) {
                                      AsistenciaModel asistencia = AsistenciaModel.fromFirestore(docsSemana[index]);
                                      
                                      bool tieneComida = asistencia.salidaComidaSolicitada != null || 
                                                         asistencia.salidaComidaReal != null || 
                                                         (asistencia.estatusComida != 'ninguna' && asistencia.estatusComida.isNotEmpty);

                                      bool solicitudPendiente = asistencia.estatusComida.toUpperCase() == 'PENDIENTE_APROBACION';
                                      
                                      double bonoTotal = (asistencia.listaBonos ?? []).fold(0.0, (sum, item) => sum + (item['monto'] as num? ?? 0.0).toDouble());
                                      double multaTotal = (asistencia.listaMultas ?? []).fold(0.0, (sum, item) => sum + (item['monto'] as num? ?? 0.0).toDouble());
                                      bool tieneBono = bonoTotal > 0;
                                      bool tieneMulta = multaTotal > 0;
                                      String motivosBono = (asistencia.listaBonos ?? []).map((e) => e['motivo'].toString()).where((e) => e.isNotEmpty).join(' • ');
                                      String motivosMulta = (asistencia.listaMultas ?? []).map((e) => e['motivo'].toString()).where((e) => e.isNotEmpty).join(' • ');

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: cardDark,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white.withOpacity(0.03)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // --- FECHA Y ESTATUS GENERAL ---
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    DateFormat('EEEE, d MMM yyyy', 'es').format(asistencia.fecha ?? DateTime.now()).toUpperCase(), 
                                                    style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: asistencia.estatus == 'a_tiempo' ? Colors.green.withOpacity(0.15) : (asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent.withOpacity(0.15) : Colors.orange.withOpacity(0.15)),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: asistencia.estatus == 'a_tiempo' ? Colors.green.withOpacity(0.3) : (asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent.withOpacity(0.3) : Colors.orange.withOpacity(0.3))),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        asistencia.estatus == 'a_tiempo' ? Icons.check_circle_rounded : (asistencia.estatus == 'incapacidad_pagada' ? Icons.healing_rounded : Icons.schedule_rounded), 
                                                        color: asistencia.estatus == 'a_tiempo' ? Colors.greenAccent : (asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent : Colors.orangeAccent), 
                                                        size: 12
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        asistencia.estatus == 'incapacidad_pagada' ? 'INCAPACIDAD' : asistencia.estatus.toUpperCase(), 
                                                        style: GoogleFonts.inter(
                                                          color: asistencia.estatus == 'a_tiempo' ? Colors.greenAccent : (asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent : Colors.orangeAccent), 
                                                          fontSize: 10, 
                                                          fontWeight: FontWeight.bold
                                                        )
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Padding(
                                              padding: EdgeInsets.symmetric(vertical: 16),
                                              child: Divider(color: Colors.white10, height: 1, thickness: 1),
                                            ),
                                            
                                            // --- ENTRADA, SALIDA O INCAPACIDAD/FALTA (VISUAL TRABAJADOR) ---
                                            if (asistencia.estatus == 'incapacidad_pagada' || asistencia.estatus == 'falta') ...[
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: asistencia.estatus == 'incapacidad_pagada' 
                                                      ? Colors.blueAccent.withOpacity(0.05) 
                                                      : Colors.redAccent.withOpacity(0.05),
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: asistencia.estatus == 'incapacidad_pagada' 
                                                        ? Colors.blueAccent.withOpacity(0.3) 
                                                        : Colors.redAccent.withOpacity(0.3)
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          asistencia.estatus == 'incapacidad_pagada' ? Icons.healing_rounded : Icons.warning_rounded, 
                                                          color: asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent : Colors.redAccent, 
                                                          size: 20
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            asistencia.estatus == 'incapacidad_pagada' ? "RECUPERACIÓN / INCAPACIDAD PAGADA" : "FALTA / AUSENCIA",
                                                            style: GoogleFonts.inter(
                                                              color: asistencia.estatus == 'incapacidad_pagada' ? Colors.blueAccent : Colors.redAccent, 
                                                              fontWeight: FontWeight.bold, 
                                                              fontSize: 13
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (asistencia.motivoFalta != null && asistencia.motivoFalta!.isNotEmpty) ...[
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        "Motivo de ausencia: ${asistencia.motivoFalta}",
                                                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),

                                              // Estatus de justificación si es que el trabajador mandó una
                                              if (asistencia.estatus == 'falta' && asistencia.estatusJustificacion != 'ninguna' && asistencia.estatusJustificacion != 'sin_enviar') ...[
                                                const SizedBox(height: 12),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: asistencia.estatusJustificacion == 'aprobada'
                                                        ? Colors.greenAccent.withOpacity(0.1)
                                                        : asistencia.estatusJustificacion == 'rechazada'
                                                            ? Colors.redAccent.withOpacity(0.1)
                                                            : Colors.orangeAccent.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: asistencia.estatusJustificacion == 'aprobada'
                                                          ? Colors.greenAccent.withOpacity(0.5)
                                                          : asistencia.estatusJustificacion == 'rechazada'
                                                              ? Colors.redAccent.withOpacity(0.5)
                                                              : Colors.orangeAccent.withOpacity(0.5),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        asistencia.estatusJustificacion == 'aprobada'
                                                            ? Icons.check_circle_rounded
                                                            : asistencia.estatusJustificacion == 'rechazada'
                                                                ? Icons.cancel_rounded
                                                                : Icons.hourglass_top_rounded,
                                                        color: asistencia.estatusJustificacion == 'aprobada'
                                                            ? Colors.greenAccent
                                                            : asistencia.estatusJustificacion == 'rechazada'
                                                                ? Colors.redAccent
                                                                : Colors.orangeAccent,
                                                        size: 16,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          "Estado de justificación: ${asistencia.estatusJustificacion.replaceAll('_', ' ').toUpperCase()}",
                                                          style: GoogleFonts.inter(
                                                            color: Colors.white,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ] else ...[
                                              // --- ENTRADA Y SALIDA NORMALES (SOLO LECTURA) ---
                                              Row(
                                                children: [
                                                  _buildReadonlyHoraBox(icono: Icons.login_rounded, titulo: "Entrada", hora: asistencia.horaEntrada),
                                                  const SizedBox(width: 12),
                                                  _buildReadonlyHoraBox(icono: Icons.logout_rounded, titulo: "Salida", hora: asistencia.horaSalida),
                                                ],
                                              ),
                                            ],

                                            // --- BONOS ---
                                            if (tieneBono) ...[
                                              const SizedBox(height: 12),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.greenAccent.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.monetization_on_rounded, color: Colors.greenAccent, size: 20),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text("Bonos extra asignados", style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                                                if (motivosBono.isNotEmpty)
                                                                  Text(motivosBono, style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 10)),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Text("+\$${bonoTotal.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                                                  ],
                                                ),
                                              ),
                                            ],

                                            // --- MULTAS ---
                                            if (tieneMulta) ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.money_off_rounded, color: Colors.redAccent, size: 20),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text("Multas / Penalizaciones", style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                                                if (motivosMulta.isNotEmpty)
                                                                  Text(motivosMulta, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 10)),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Text("-\$${multaTotal.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                                                  ],
                                                ),
                                              ),
                                            ],

                                            // --- HORARIO DE COMIDA ---
                                            if (tieneComida) ...[
                                              const SizedBox(height: 16),
                                              Container(
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: solicitudPendiente ? Colors.orangeAccent.withOpacity(0.05) : Colors.white.withOpacity(0.02),
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: solicitudPendiente ? Colors.orangeAccent.withOpacity(0.5) : Colors.white.withOpacity(0.05)),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Row(
                                                            children: [
                                                              Icon(Icons.fastfood_rounded, color: solicitudPendiente ? Colors.orangeAccent : Colors.white70, size: 18),
                                                              const SizedBox(width: 8),
                                                              Expanded( 
                                                                child: Text(
                                                                  "Horario de Comida", 
                                                                  style: GoogleFonts.inter(color: solicitudPendiente ? Colors.orangeAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (solicitudPendiente) ...[
                                                          const SizedBox(width: 8),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(6)),
                                                            child: Text("NUEVA SOLICITUD", style: GoogleFonts.inter(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Row(
                                                      children: [
                                                        _buildInfoHora(icono: Icons.access_time_rounded, titulo: "Solicitó", hora: asistencia.salidaComidaSolicitada),
                                                        _buildInfoHora(icono: Icons.restaurant_rounded, titulo: "Salió", hora: asistencia.salidaComidaReal),
                                                        _buildInfoHora(icono: Icons.assignment_return_rounded, titulo: "Regresó", hora: asistencia.regresoComidaReal),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],

                                            // --- HISTORIAL DE MODIFICACIONES ---
                                            if (asistencia.historialModificaciones != null && asistencia.historialModificaciones!.isNotEmpty) ...[
                                              const SizedBox(height: 16),
                                              InkWell(
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      backgroundColor: cardDark,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.05))),
                                                      title: Row(
                                                        children: [
                                                          Icon(Icons.history_edu_rounded, color: primaryPurple),
                                                          const SizedBox(width: 10),
                                                          Expanded(
                                                            child: Text(
                                                              "Notas del Administrador", 
                                                              style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                                              overflow: TextOverflow.ellipsis, 
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      content: SizedBox(
                                                        width: double.maxFinite,
                                                        child: ListView.separated(
                                                          shrinkWrap: true,
                                                          itemCount: asistencia.historialModificaciones!.length,
                                                          separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                                                          itemBuilder: (context, index) {
                                                            return Padding(
                                                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                              child: Text(asistencia.historialModificaciones![index], style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.4)),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context),
                                                          child: Text("Cerrar", style: GoogleFonts.inter(color: textMuted, fontWeight: FontWeight.bold)),
                                                        )
                                                      ],
                                                    )
                                                  );
                                                },
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.manage_history_rounded, color: textMuted, size: 16),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      "Ver modificaciones (${asistencia.historialModificaciones!.length})", 
                                                      style: GoogleFonts.inter(color: textMuted, fontSize: 12, fontWeight: FontWeight.w500, decoration: TextDecoration.underline)
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                )
                            ],
                          );  
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
