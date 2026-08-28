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
  late DateTime _fechaAsignada;
  DateTime? _fechaLimite; 
  TimeOfDay? _horaLimite; 

  List<Map<String, dynamic>> _trabajadores = [];
  bool _cargandoTrabajadores = true;

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    _fechaAsignada = DateTime(ahora.year, ahora.month, ahora.day);
    _cargarTrabajadores();

    // Si recibimos una actividad, rellenamos los datos para editar
    if (widget.actividadAEditar != null) {
      _tituloController.text = widget.actividadAEditar!.titulo;
      _descripcionController.text = widget.actividadAEditar!.descripcion;
      _trabajadorSeleccionadoId = widget.actividadAEditar!.asignadoATrabajadorId;
      _fechaAsignada = widget.actividadAEditar!.fechaAsignada;
      _fechaLimite = widget.actividadAEditar!.fechaTermino;
      _horaLimite = TimeOfDay.fromDateTime(widget.actividadAEditar!.fechaTermino);
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
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

      if (!mounted) return;
      setState(() {
        _trabajadores = temp;
        _cargandoTrabajadores = false;
      });
    } catch (e) {
      print("Error al cargar trabajadores: $e");
      if (!mounted) return;
      setState(() {
        _cargandoTrabajadores = false;
      });
    }
  }

  Future<void> _seleccionarDiaTarea(BuildContext context) async {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final primerDia = _fechaAsignada.isBefore(hoy) ? _fechaAsignada : hoy;

    final DateTime? seleccion = await showDatePicker(
      context: context,
      initialDate: _fechaAsignada,
      firstDate: primerDia,
      lastDate: DateTime(2035),
      helpText: 'DÍA DE LA TAREA',
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
        _fechaAsignada = DateTime(
          seleccion.year,
          seleccion.month,
          seleccion.day,
        );
      });
    }
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final primerDia = DateTime(
      _fechaAsignada.year,
      _fechaAsignada.month,
      _fechaAsignada.day,
    );
    final fechaInicial = _fechaLimite != null && !_fechaLimite!.isBefore(primerDia)
        ? _fechaLimite!
        : primerDia;
    final DateTime? seleccion = await showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: primerDia,
      lastDate: DateTime(2035),
      helpText: 'FECHA LÍMITE DE ENTREGA',
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
    final String tituloModal = esEdicion ? 'EDITAR TAREA DIARIA' : 'ASIGNAR TAREA DIARIA';
    final String textoBoton = esEdicion ? 'ACTUALIZAR TAREA' : 'ASIGNAR TAREA';

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

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDE21).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFDE21).withOpacity(0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.fact_check_outlined, color: Color(0xFFFFDE21), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TAREA DIARIA · DIAGNÓSTICO',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFFDE21),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'El trabajador deberá subir evidencia para poder marcarla como terminada.',
                            style: GoogleFonts.inter(color: Colors.white60, fontSize: 12, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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

              Text(
                'DÍA DE LA TAREA',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Día en que el trabajador debe realizar esta actividad.',
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _seleccionarDiaTarea(context),
                  icon: const Icon(Icons.today_outlined, size: 18, color: Color(0xFFFFDE21)),
                  label: Text(
                    DateFormat('dd MMM yyyy').format(_fechaAsignada),
                    style: GoogleFonts.inter(color: Colors.white70),
                  ),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    side: const BorderSide(color: Colors.white10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
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
                    if (!_formKey.currentState!.validate()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Por favor, completa los campos requeridos'), backgroundColor: Colors.redAccent),
                      );
                      return;
                    }

                    if (_fechaLimite == null || _horaLimite == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Selecciona la fecha y la hora límite de la tarea'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    final fechaHoraLimiteCompleta = DateTime(
                      _fechaLimite!.year,
                      _fechaLimite!.month,
                      _fechaLimite!.day,
                      _horaLimite!.hour,
                      _horaLimite!.minute,
                    );
                    final fechaInicioActividad = esEdicion
                        ? widget.actividadAEditar!.fechaInicio
                        : DateTime.now();
                    final inicioDiaTarea = DateTime(
                      _fechaAsignada.year,
                      _fechaAsignada.month,
                      _fechaAsignada.day,
                    );
                    final comienzoTarea = inicioDiaTarea.isAfter(fechaInicioActividad)
                        ? inicioDiaTarea
                        : fechaInicioActividad;

                    if (!fechaHoraLimiteCompleta.isAfter(comienzoTarea)) {
                      final comienzoLegible = DateFormat('dd MMM yyyy, HH:mm').format(comienzoTarea);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'La fecha límite debe ser posterior al comienzo de la tarea ($comienzoLegible).',
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(color: Color(0xFFFFDE21)),
                      ),
                    );

                    if (esEdicion) {
                      final actividadOriginal = widget.actividadAEditar!;
                      final actividadActualizada = ActividadModel(
                        id: actividadOriginal.id,
                        proyectoId: actividadOriginal.proyectoId,
                        titulo: _tituloController.text.trim(),
                        descripcion: _descripcionController.text.trim(),
                        asignadoATrabajadorId: _trabajadorSeleccionadoId!,
                        fechaInicio: actividadOriginal.fechaInicio,
                        fechaAsignada: _fechaAsignada,
                        fechaTermino: fechaHoraLimiteCompleta,
                        estatus: actividadOriginal.estatus,
                        observacionesAdmin: actividadOriginal.observacionesAdmin,
                        comentariosTrabajador: actividadOriginal.comentariosTrabajador,
                        evidenciaFotos: actividadOriginal.evidenciaFotos,
                        historialEventos: actividadOriginal.historialEventos,
                        completadoEn: actividadOriginal.completadoEn,
                        evidenciasCount: actividadOriginal.evidenciasCount,
                        ultimoAvance: actividadOriginal.ultimoAvance,
                        requiereEvidencia: actividadOriginal.requiereEvidencia,
                      );
                      final messenger = ScaffoldMessenger.of(context);

                      try {
                        await ActividadesService().actualizarActividad(actividadActualizada);

                        if (!mounted) return;
                        Navigator.pop(context);
                        Navigator.pop(context);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Tarea diaria actualizada con éxito'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (mounted) {
                          Navigator.pop(context);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Error al actualizar: $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                      return;
                    }

                    final nuevaActividad = ActividadModel(
                      id: '',
                      proyectoId: widget.proyectoId,
                      titulo: _tituloController.text.trim(),
                      descripcion: _descripcionController.text.trim(),
                      asignadoATrabajadorId: _trabajadorSeleccionadoId!,
                      fechaInicio: fechaInicioActividad,
                      fechaAsignada: _fechaAsignada,
                      fechaTermino: fechaHoraLimiteCompleta,
                      requiereEvidencia: true,
                    );

                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      // El servicio guarda la tarea y cambia el proyecto a
                      // EN PROCESO en un mismo lote atómico.
                      await ActividadesService().crearActividad(nuevaActividad);
                      if (!mounted) return;
                      Navigator.pop(context);
                      Navigator.pop(context);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Tarea diaria asignada y proyecto EN PROCESO'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (mounted) {
                        Navigator.pop(context);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Error al guardar la tarea: $e'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
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
