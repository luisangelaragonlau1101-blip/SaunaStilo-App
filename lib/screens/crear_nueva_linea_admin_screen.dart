import '../presentation/appearance.dart';
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
  Color get colorFondo => StiloColors.surface;
  Color get colorTarjeta => StiloColors.surface;
  Color get colorMorado => StiloColors.accent;
  Color get colorAmarillo => Color(0xFFFFDE21);

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
          SnackBar(content: Text('¡Nueva línea de negocio guardada en la incubadora!'), backgroundColor: Colors.green),
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
                side: BorderSide(color: StiloColors.text.withValues(alpha: .12), width: 1)
              ),
              title: Text(
                'Nueva Asignación',
                style: TextStyle(color: StiloColors.text, fontWeight: FontWeight.bold, fontSize: 18)
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(color: StiloColors.surface, borderRadius: BorderRadius.circular(14)),
                      child: TextField(contextMenuBuilder: privacyTextMenu,
                        controller: _tareaTituloController,
                        style: TextStyle(color: StiloColors.text),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          labelText: '¿Qué hay que hacer?',
                          labelStyle: TextStyle(color: StiloColors.text.withValues(alpha: .54)),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(color: StiloColors.surface, borderRadius: BorderRadius.circular(14)),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return LinearProgressIndicator(color: colorMorado);
                          var usuarios = snapshot.data!.docs;

                          return DropdownButtonFormField<String>(
                            dropdownColor: StiloColors.surface,
                            value: _trabajadorAsignadoId,
                            style: TextStyle(color: StiloColors.text, fontSize: 16),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              labelText: 'Asignar a:',
                              labelStyle: TextStyle(color: StiloColors.text.withValues(alpha: .54)),
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
                    SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(color: StiloColors.surface, borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: Icon(Icons.calendar_today_outlined, color: colorAmarillo, size: 20),
                        title: Text(
                          _fechaLimiteTarea == null
                              ? 'Definir fecha límite'
                              : DateFormat('dd/MM/yyyy').format(_fechaLimiteTarea!),
                          style: TextStyle(color: StiloColors.text.withValues(alpha: .70), fontSize: 14),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, color: StiloColors.text.withValues(alpha: .30), size: 14),
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(Duration(days: 365)),
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
                  child: Text('Cancelar', style: TextStyle(color: StiloColors.text.withValues(alpha: .54))),
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
                  child: Text('Añadir', style: TextStyle(color: StiloColors.text, fontWeight: FontWeight.bold)),
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
    Theme.of(context);
    final formatoFecha = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: colorFondo,
      appBar: AppBar(
        backgroundColor: colorFondo,
        elevation: 0,
        title: Text('Organizar Iniciativa', style: TextStyle(color: StiloColors.text, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: IconThemeData(color: StiloColors.text),
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: colorMorado))
          : Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(16.0),
                children: [
                  Card(
                    color: colorTarjeta,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: StiloColors.text.withValues(alpha: .12), width: 1),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline, color: colorMorado, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Detalles del Proyecto',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: StiloColors.text),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(color: StiloColors.surface, borderRadius: BorderRadius.circular(12)),
                            child: TextFormField(contextMenuBuilder: privacyTextMenu,
                              controller: _tituloController,
                              style: TextStyle(color: StiloColors.text),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Nombre de la idea (Ej: Línea de Lociones)',
                                hintStyle: TextStyle(color: StiloColors.text.withValues(alpha: .38), fontSize: 14),
                              ),
                              validator: (v) => v!.isEmpty ? 'Por favor, introduce un nombre para el plan' : null,
                            ),
                          ),
                          SizedBox(height: 14),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(color: StiloColors.surface, borderRadius: BorderRadius.circular(12)),
                            child: TextFormField(contextMenuBuilder: privacyTextMenu,
                              controller: _descripcionController,
                              maxLines: 3,
                              style: TextStyle(color: StiloColors.text.withValues(alpha: .70), fontSize: 14),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Anota aquí los objetivos generales, notas o especificaciones de la nueva idea...',
                                hintStyle: TextStyle(color: StiloColors.text.withValues(alpha: .38), fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PLAN DE ACCIÓN / TAREAS',
                          style: TextStyle(color: StiloColors.text.withValues(alpha: .54), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        TextButton.icon(
                          onPressed: _mostrarDialogoAgregarTarea,
                          icon: Icon(Icons.add, color: colorMorado, size: 18),
                          label: Text('Agregar Tarea', style: TextStyle(color: colorMorado, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                  SizedBox(height: 8),

                  _tareasPendientes.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Column(
                              children: [
                                Icon(Icons.playlist_add_check_rounded, size: 48, color: StiloColors.text.withValues(alpha: .24)),
                                SizedBox(height: 12),
                                Text(
                                  'No hay tareas asignadas a esta iniciativa.',
                                  style: TextStyle(color: StiloColors.text.withValues(alpha: .38), fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: _tareasPendientes.length,
                          itemBuilder: (context, index) {
                            final item = _tareasPendientes[index];

                            return Card(
                              color: colorTarjeta,
                              elevation: 2,
                              margin: EdgeInsets.symmetric(vertical: 6.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: StiloColors.text.withValues(alpha: .12), width: 1),
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    title: Text(
                                      item['titulo'],
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: StiloColors.text),
                                    ),
                                    subtitle: Padding(
                                      padding: EdgeInsets.only(top: 8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.person_outline, size: 16, color: StiloColors.text.withValues(alpha: .54)),
                                              SizedBox(width: 6),
                                              Text('Asignado: ${item['asignadoNombre']}', style: TextStyle(color: StiloColors.text.withValues(alpha: .70))),
                                            ],
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today_outlined, size: 14, color: StiloColors.text.withValues(alpha: .54)),
                                              SizedBox(width: 6),
                                              Text('Límite: ${formatoFecha.format(item['fechaLimite'])}', style: TextStyle(color: StiloColors.text.withValues(alpha: .70))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: colorAmarillo.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'PENDIENTE',
                                        style: TextStyle(color: colorAmarillo, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  Divider(color: StiloColors.text.withValues(alpha: .12), height: 1),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                          label: Text('Quitar', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
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
                  SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: StiloColors.text,
        foregroundColor: StiloColors.background,
        onPressed: _guardarIniciativa,
        icon: Icon(Icons.rocket_launch_outlined),
        label: Text('Lanzar Iniciativa', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
