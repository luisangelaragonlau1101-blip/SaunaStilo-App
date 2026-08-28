import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../services/actividades_service.dart';
import '../models/actividad_model.dart';

class ModalAsignarActividad extends StatefulWidget {
  final String proyectoId;
  final String rolUsuario; // <-- Agregamos el rol aquí
  final ActividadModel? actividadAEditar; 

  const ModalAsignarActividad({
    Key? key, 
    required this.proyectoId,
    required this.rolUsuario, // <-- Y lo pedimos como obligatorio
    this.actividadAEditar,
  }) : super(key: key);

  @override
  State<ModalAsignarActividad> createState() => _ModalAsignarActividadState();
}

class _ModalAsignarActividadState extends State<ModalAsignarActividad> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController(); 
  
  String? _trabajadorSeleccionadoId;
  DateTime? _fechaLimite; 
  TimeOfDay? _horaLimite; 

  List<Map<String, dynamic>> _trabajadores = [];
  bool _cargandoTrabajadores = true;

  @override
  void initState() {
    super.initState();
    _cargarTrabajadores();

    // Si recibimos una actividad, rellenamos los datos para editar
    if (widget.actividadAEditar != null) {
      _tituloController.text = widget.actividadAEditar!.titulo;
      _descripcionController.text = widget.actividadAEditar!.descripcion;
      _trabajadorSeleccionadoId = widget.actividadAEditar!.asignadoATrabajadorId;
      _fechaLimite = widget.actividadAEditar!.fechaTermino;
      _horaLimite = TimeOfDay.fromDateTime(widget.actividadAEditar!.fechaTermino);
    }
  }

  Future<void> _cargarTrabajadores() async {
    try {
      // Preparamos la consulta base
      Query query = FirebaseFirestore.instance.collection('usuarios');

      // Si es admin, traemos maestros y trabajadores. Si no, solo trabajadores.
      if (widget.rolUsuario == 'admin') {
        query = query.where('rol', whereIn: ['trabajador', 'maestro']);
      } else {
        query = query.where('rol', isEqualTo: 'trabajador');
      }

      var snapshot = await query.get();

      List<Map<String, dynamic>> temp = [];
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String nombre = data['Nombre'] ?? data['nombre'] ?? 'Sin nombre';
        String rolUsuarioBD = data['rol'] ?? 'trabajador';

        // Si es admin, le agregamos visualmente el rol al lado del nombre en el dropdown
        String textoMostrar = widget.rolUsuario == 'admin' && rolUsuarioBD == 'maestro'
            ? '$nombre (MAESTRO)' 
            : nombre;

        temp.add({
          'id': doc.id,
          'nombre': textoMostrar,
        });
      }

      setState(() {
        _trabajadores = temp;
        _cargandoTrabajadores = false;
      });
    } catch (e) {
      print("Error al cargar trabajadores: $e");
      setState(() {
        _cargandoTrabajadores = false;
      });
    }
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? seleccion = await showDatePicker(
      context: context,
      initialDate: _fechaLimite ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)), // Permitimos un margen mínimo por si la fecha era de ayer
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFDE21),
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (seleccion != null) {
      setState(() {
        _fechaLimite = seleccion;
      });
    }
  }

  Future<void> _seleccionarHora(BuildContext context) async {
    final TimeOfDay? seleccion = await showTimePicker(
      context: context,
      initialTime: _horaLimite ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFDE21),
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (seleccion != null) {
      setState(() {
        _horaLimite = seleccion;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Variables para cambiar textos dependiendo de si estamos editando o creando
    final bool esEdicion = widget.actividadAEditar != null;
    final String tituloModal = esEdicion ? 'EDITAR ACTIVIDAD' : 'ASIGNAR ACTIVIDAD';
    final String textoBoton = esEdicion ? 'ACTUALIZAR ACTIVIDAD' : 'GUARDAR ACTIVIDAD';

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 15,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                tituloModal,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _tituloController,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Título de la actividad',
                  labelStyle: GoogleFonts.inter(color: Colors.white54),
                  prefixIcon: const Icon(Icons.work_outline, color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF121212),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFFDE21))),
                ),
                validator: (value) => value!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _descripcionController,
                maxLines: 3, 
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Descripción detallada',
                  labelStyle: GoogleFonts.inter(color: Colors.white54),
                  prefixIcon: const Icon(Icons.description_outlined, color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF121212),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFFDE21))),
                ),
                validator: (value) => value!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 15),

              _cargandoTrabajadores
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFDE21)))
                  : DropdownButtonFormField<String>(
                      value: _trabajadores.any((t) => t['id'] == _trabajadorSeleccionadoId) ? _trabajadorSeleccionadoId : null,
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: _trabajadores.isEmpty ? 'No hay trabajadores registrados' : 'Asignar a',
                        labelStyle: GoogleFonts.inter(color: Colors.white54),
                        prefixIcon: const Icon(Icons.person_outline, color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF121212),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFFDE21))),
                      ),
                      items: _trabajadores.isEmpty 
                          ? null 
                          : _trabajadores.map((trabajador) {
                              return DropdownMenuItem<String>(
                                value: trabajador['id'], 
                                child: Text(trabajador['nombre']), 
                              );
                            }).toList(),
                      onChanged: _trabajadores.isEmpty ? null : (value) => setState(() => _trabajadorSeleccionadoId = value),
                      validator: (value) => value == null ? 'Selecciona un trabajador' : null,
                    ),
              const SizedBox(height: 20),

              Text("FECHA LÍMITE DE ENTREGA", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _seleccionarFecha(context),
                      icon: const Icon(Icons.calendar_today, size: 18, color: Color(0xFFFFDE21)),
                      label: Text(_fechaLimite == null
                          ? 'Fecha Límite'
                          : DateFormat('dd MMM yyyy').format(_fechaLimite!),
                          style: GoogleFonts.inter(color: Colors.white70)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: Colors.white10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _seleccionarHora(context),
                      icon: const Icon(Icons.access_time, size: 18, color: Color(0xFFFFDE21)),
                      label: Text(_horaLimite == null
                          ? 'Hora Límite'
                          : _horaLimite!.format(context),
                          style: GoogleFonts.inter(color: Colors.white70)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: Colors.white10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFDE21),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (_formKey.currentState!.validate() && _fechaLimite != null && _horaLimite != null) {
                      
                      // Mostramos la alerta de carga
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFFFDE21))),
                      );

                      // Combinamos la fecha y hora
                      final fechaHoraLimiteCompleta = DateTime(
                        _fechaLimite!.year, _fechaLimite!.month, _fechaLimite!.day,
                        _horaLimite!.hour, _horaLimite!.minute,
                      );

                      if (esEdicion) {
                        // --- FLUJO DE EDICIÓN ---
                        ActividadModel actividadActualizada = ActividadModel(
                          id: widget.actividadAEditar!.id, 
                          proyectoId: widget.actividadAEditar!.proyectoId,
                          titulo: _tituloController.text.trim(),
                          descripcion: _descripcionController.text.trim(), 
                          asignadoATrabajadorId: _trabajadorSeleccionadoId!,
                          fechaInicio: widget.actividadAEditar!.fechaInicio, // Mantenemos la original
                          fechaTermino: fechaHoraLimiteCompleta, 
                          estatus: widget.actividadAEditar!.estatus,
                          observacionesAdmin: widget.actividadAEditar!.observacionesAdmin,
                          comentariosTrabajador: widget.actividadAEditar!.comentariosTrabajador,
                          evidenciaFotos: widget.actividadAEditar!.evidenciaFotos,
                          historialEventos: widget.actividadAEditar!.historialEventos,
                        );

                        try {
                          await ActividadesService().actualizarActividad(actividadActualizada);
                          
                          if (mounted) {
                            Navigator.pop(context); // Cierra loader
                            Navigator.pop(context); // Cierra modal
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actividad actualizada con éxito'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          if (mounted) {
                            Navigator.pop(context); // Cierra loader
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.redAccent));
                          }
                        }

                      } else {
                        // --- FLUJO DE CREACIÓN (ORIGINAL) ---
                        ActividadModel nuevaActividad = ActividadModel(
                          id: '', 
                          proyectoId: widget.proyectoId,
                          titulo: _tituloController.text.trim(),
                          descripcion: _descripcionController.text.trim(), 
                          asignadoATrabajadorId: _trabajadorSeleccionadoId!,
                          fechaInicio: DateTime.now(), 
                          fechaTermino: fechaHoraLimiteCompleta, 
                        );

                        bool actividadGuardada = false;

                        try {
                          await ActividadesService().crearActividad(nuevaActividad);
                          actividadGuardada = true;
                        } catch (e) {
                          if (mounted) {
                            Navigator.pop(context); // Cierra loader
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar actividad: $e'), backgroundColor: Colors.redAccent));
                          }
                          return;
                        }

                        if (actividadGuardada) {
                          try {
                            await FirebaseFirestore.instance
                                .collection('proyectos')
                                .doc(widget.proyectoId)
                                .update({'estatus': 'en_proceso'})
                                .timeout(const Duration(seconds: 5), onTimeout: () {
                                  throw Exception("Firebase no responde.");
                                });
                                
                            if (mounted) {
                              Navigator.pop(context); // Cierra loader
                              Navigator.pop(context); // Cierra modal
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actividad asignada y proyecto EN PROCESO'), backgroundColor: Colors.green));
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.pop(context); // Cierra loader
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1E1E),
                                  title: const Text("Error Detectado", style: TextStyle(color: Colors.redAccent)),
                                  content: Text("Detalle:\n$e", style: const TextStyle(color: Colors.white70)),
                                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK", style: TextStyle(color: Color(0xFFFFDE21))))],
                                )
                              );
                            }
                          }
                        }
                      } // Fin else (creación)
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Por favor, completa los campos requeridos'), backgroundColor: Colors.redAccent),
                      );
                    }
                  },
                  child: Text(textoBoton, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}