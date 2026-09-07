import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CrearNuevaLineaAdminScreen extends StatefulWidget {
  const CrearNuevaLineaAdminScreen({Key? key}) : super(key: key);

  @override
  _CrearNuevaLineaAdminScreenState createState() => _CrearNuevaLineaAdminScreenState();
}

class _CrearNuevaLineaAdminScreenState extends State<CrearNuevaLineaAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();

  // Lista local de misiones/tareas antes de consolidar en Firebase
  List<Map<String, dynamic>> _tareasPendientes = [];

  // Controladores y variables locales para el diálogo de agregar tarea
  final _tareaTituloController = TextEditingController();
  String? _trabajadorAsignadoId;
  String? _trabajadorAsignadoNombre;
  DateTime? _fechaLimiteTarea;

  bool _cargando = false;

  // Paleta estética homologada
  static const Color colorFondo = Color(0xFF121212);
  static const Color colorTarjeta = Color(0xFF1E1E1E);
  static const Color colorMorado = Color(0xFF8B5CF6);
  static const Color colorAmarillo = Color(0xFFFFDE21);

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _tareaTituloController.dispose();
    super.dispose();
  }

  // CORREGIDO: Guarda en una colección completamente nueva e independiente
  Future<void> _guardarIniciativa() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    try {
      // Mapeamos las tareas locales para guardarlas estructuradas dentro del mismo documento
      List<Map<String, dynamic>> tareasEstructuradas = _tareasPendientes.map((t) {
        return {
          'titulo': t['titulo'],
          'asignadoId': t['asignadoId'],
          'asignadoNombre': t['asignadoNombre'],
          'fechaTermino': Timestamp.fromDate(t['fechaLimite']),
          'estatus': 'pendiente',
        };
      }).toList();

      // Guardamos en una colección exclusiva para no alterar los Saunas (proyectos)
      await FirebaseFirestore.instance.collection('ideas_lineas_negocio').add({
        'titulo': _tituloController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'estatus': 'planeacion', 
        'fechaCreacion': Timestamp.now(),
        'tareas': tareasEstructuradas, // Se guardan aquí adentro para no contaminar 'actividades'
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Nueva línea de negocio guardada en la incubadora!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar iniciativa: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarDialogoAgregarTarea() {
    _tareaTituloController.clear();
    _trabajadorAsignadoId = null;
    _trabajadorAsignadoNombre = null;
    _fechaLimiteTarea = null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colorTarjeta,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24), 
                side: const BorderSide(color: Colors.white12, width: 1)
              ),
              title: const Text(
                'Nueva Asignación', 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF2D2D2D), borderRadius: BorderRadius.circular(14)),
                      child: TextField(contextMenuBuilder: privacyTextMenu,
                        controller: _tareaTituloController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: '¿Qué hay que hacer?',
                          labelStyle: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF2D2D2D), borderRadius: BorderRadius.circular(14)),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const LinearProgressIndicator(color: colorMorado);
                          var usuarios = snapshot.data!.docs;

                          return DropdownButtonFormField<String>(
                            dropdownColor: const Color(0xFF2D2D2D),
                            value: _trabajadorAsignadoId,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              labelText: 'Asignar a:',
                              labelStyle: TextStyle(color: Colors.white54),
                            ),
                            items: usuarios.map((user) {
                              var data = user.data() as Map<String, dynamic>;
                              return DropdownMenuItem<String>(
                                value: user.id,
                                child: Text(data['nombre'] ?? 'Sin nombre'),
                                onTap: () => _trabajadorAsignadoNombre = data['nombre'],
                              );
                            }).toList(),
                            onChanged: (val) => setDialogState(() => _trabajadorAsignadoId = val),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(color: const Color(0xFF2D2D2D), borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today_outlined, color: colorAmarillo, size: 20),
                        title: Text(
                          _fechaLimiteTarea == null 
                              ? 'Definir fecha límite' 
                              : DateFormat('dd/MM/yyyy').format(_fechaLimiteTarea!),
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 14),
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => _fechaLimiteTarea = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorMorado,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (_tareaTituloController.text.trim().isEmpty || _trabajadorAsignadoId == null || _fechaLimiteTarea == null) {
                      return;
                    }
                    setState(() {
                      _tareasPendientes.add({
                        'titulo': _tareaTituloController.text.trim(),
                        'asignadoId': _trabajadorAsignadoId,
                        'asignadoNombre': _trabajadorAsignadoNombre,
                        'fechaLimite': _fechaLimiteTarea,
                      });
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Añadir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatoFecha = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        backgroundColor: colorFondo,
        elevation: 0,
        title: const Text('Organizar Iniciativa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: colorMorado))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Card(
                    color: colorTarjeta,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Colors.white12, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.lightbulb_outline, color: colorMorado, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Detalles del Proyecto',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(color: const Color(0xFF2D2D2D), borderRadius: BorderRadius.circular(12)),
                            child: TextFormField(contextMenuBuilder: privacyTextMenu,
                              controller: _tituloController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Nombre de la idea (Ej: Línea de Lociones)',
                                hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                              ),
                              validator: (v) => v!.isEmpty ? 'Por favor, introduce un nombre para el plan' : null,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFF2D2D2D), borderRadius: BorderRadius.circular(12)),
                            child: TextFormField(contextMenuBuilder: privacyTextMenu,
                              controller: _descripcionController,
                              maxLines: 3,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Anota aquí los objetivos generales, notas o especificaciones de la nueva idea...',
                                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'PLAN DE ACCIÓN / TAREAS',
                          style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        TextButton.icon(
                          onPressed: _mostrarDialogoAgregarTarea,
                          icon: const Icon(Icons.add, color: colorMorado, size: 18),
                          label: const Text('Agregar Tarea', style: TextStyle(color: colorMorado, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  _tareasPendientes.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              children: const [
                                Icon(Icons.playlist_add_check_rounded, size: 48, color: Colors.white24),
                                SizedBox(height: 12),
                                Text(
                                  'No hay tareas asignadas a esta iniciativa.',
                                  style: TextStyle(color: Colors.white38, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _tareasPendientes.length,
                          itemBuilder: (context, index) {
                            final item = _tareasPendientes[index];

                            return Card(
                              color: colorTarjeta,
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 6.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Colors.white12, width: 1),
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    title: Text(
                                      item['titulo'],
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.person_outline, size: 16, color: Colors.white54),
                                              const SizedBox(width: 6),
                                              Text('Asignado: ${item['asignadoNombre']}', style: const TextStyle(color: Colors.white70)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.white54),
                                              const SizedBox(width: 6),
                                              Text('Límite: ${formatoFecha.format(item['fechaLimite'])}', style: const TextStyle(color: Colors.white70)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: colorAmarillo.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'PENDIENTE',
                                        style: TextStyle(color: colorAmarillo, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const Divider(color: Colors.white12, height: 1),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                          label: const Text('Quitar', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                                          onPressed: () => setState(() => _tareasPendientes.removeAt(index)),
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 80), 
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        onPressed: _guardarIniciativa,
        icon: const Icon(Icons.rocket_launch_outlined),
        label: const Text('Lanzar Iniciativa', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}