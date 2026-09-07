import '../services/external_transfer.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 👈 IMPORTADO PARA SABER QUIÉN ESTÁ LOGUEADO
import '../models/seguimiento_cotizaciones_model.dart';

class DetalleCotizacionScreen extends StatefulWidget {
  final SeguimientoCotizacionModel cotizacion;

  const DetalleCotizacionScreen({Key? key, required this.cotizacion}) : super(key: key);

  @override
  State<DetalleCotizacionScreen> createState() => _DetalleCotizacionScreenState();
}

class _DetalleCotizacionScreenState extends State<DetalleCotizacionScreen> {
  bool _procesandoEstatus = false;
  final TextEditingController _nuevaNotaController = TextEditingController();
  late SeguimientoCotizacionModel _cotizacionActual;
  String _nombreAdminActual = 'Sin asignar'; // 👈 VARIABLE PARA EL USUARIO ACTUAL

  @override
  void initState() {
    super.initState();
    _cotizacionActual = widget.cotizacion;
    _obtenerUsuarioActual(); // 👈 LLAMAMOS LA FUNCIÓN AL INICIAR
  }

  // 👈 NUEVA FUNCIÓN PARA OBTENER EL NOMBRE DEL ADMIN ACTUAL
  Future<void> _obtenerUsuarioActual() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _nombreAdminActual = userData['nombre'] ?? 'Admin';
            });
          }
        }
      } catch (e) {
        debugPrint("Error obteniendo usuario actual: $e");
      }
    }
  }

  @override
  void dispose() {
    _nuevaNotaController.dispose();
    super.dispose();
  }

 // LÓGICA CORE: Aceptar cotización, crear cliente (si es nuevo) y crear proyecto pendiente
  Future<void> _aprobarCotizacion() async {
    setState(() => _procesandoEstatus = true);

    try {
      final firestore = FirebaseFirestore.instance;
      String idClienteFinal = _cotizacionActual.idCliente;

      if (_cotizacionActual.clienteEsNuevo && idClienteFinal.isEmpty) {
        final nuevoClienteRef = await firestore.collection('clientes').add({
          'nombre': _cotizacionActual.datosCliente.nombre,
          'telefono': _cotizacionActual.datosCliente.telefono,
          'direccion': _cotizacionActual.datosCliente.direccion,
          'fecha_registro': Timestamp.now(),
        });
        idClienteFinal = nuevoClienteRef.id;
      }

      // 1. 👇 CAPTURAMOS LA REFERENCIA DEL PROYECTO CREADO (Cambiamos el 'await' por una variable)
      final nuevoProyectoRef = await firestore.collection('proyectos').add({
        'titulo': _cotizacionActual.datosProyecto.titulo,
        'id_sauna': _cotizacionActual.datosProyecto.idSauna,
        'id_cliente': idClienteFinal,
        'estatus': 'pendiente', 
        'fecha_inicio': Timestamp.now(),
        'fecha_entrega': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))), 
        'medidas': _cotizacionActual.datosProyecto.medidas,
        'descripcion': _cotizacionActual.datosProyecto.descripcion,
        'encargados': [], 
      });

    // 2. 👇 CREAMOS EL DOCUMENTO EN LA SUBCOLECCIÓN 'FINANZAS' CON LA ESTRUCTURA CORRECTA
      await nuevoProyectoRef.collection('finanzas').doc('datos_pago').set({
        'cotizacion': _cotizacionActual.montoCotizado,
        'pago_inicial': 0.0, // Arranca en 0 hasta que registres un anticipo
        'monto_pagado': 0.0, // Arranca en 0
        'fecha_registro': FieldValue.serverTimestamp(),
      });

      // 3. ACTUALIZAMOS LA COTIZACIÓN ORIGINAL
      await firestore.collection('seguimiento_cotizaciones').doc(_cotizacionActual.id).update({
        'estatus_cotizacion': 'ACEPTADA',
        'id_cliente': idClienteFinal,
        'cliente_es_nuevo': false, 
      });

      setState(() {
        _cotizacionActual = SeguimientoCotizacionModel(
          id: _cotizacionActual.id,
          adminEncargado: _cotizacionActual.adminEncargado,
          clienteEsNuevo: false,
          idCliente: idClienteFinal,
          estatusCotizacion: 'ACEPTADA',
          fechaCotizacion: _cotizacionActual.fechaCotizacion,
          montoCotizado: _cotizacionActual.montoCotizado,
          datosCliente: _cotizacionActual.datosCliente,
          datosProyecto: _cotizacionActual.datosProyecto,
          notasSeguimiento: _cotizacionActual.notasSeguimiento,
        );
        _procesandoEstatus = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Cotización Aceptada! Cliente, Proyecto e información financiera creados.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _procesandoEstatus = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // AGREGAR NOTA ADICIONAL COMO TAREA PENDIENTE
  Future<void> _agregarNotaSeguimiento() async {
    String textoNota = _nuevaNotaController.text.trim();
    if (textoNota.isEmpty) return;

    try {
      final nuevaNota = NotaSeguimiento(
        fecha: DateTime.now(),
        comentario: textoNota,
        completada: false, 
        creadaPor: _nombreAdminActual, // 👈 ASIGNAMOS QUIÉN CREÓ LA NOTA
      );

      List<NotaSeguimiento> notasActualizadas = List.from(_cotizacionActual.notasSeguimiento)..add(nuevaNota);

      await FirebaseFirestore.instance
          .collection('seguimiento_cotizaciones')
          .doc(_cotizacionActual.id)
          .update({
        'notas_seguimiento': notasActualizadas.map((n) => n.toJson()).toList(),
      });

      setState(() {
        _cotizacionActual = SeguimientoCotizacionModel(
          id: _cotizacionActual.id,
          adminEncargado: _cotizacionActual.adminEncargado,
          clienteEsNuevo: _cotizacionActual.clienteEsNuevo,
          idCliente: _cotizacionActual.idCliente,
          estatusCotizacion: _cotizacionActual.estatusCotizacion,
          fechaCotizacion: _cotizacionActual.fechaCotizacion,
          montoCotizado: _cotizacionActual.montoCotizado,
          datosCliente: _cotizacionActual.datosCliente,
          datosProyecto: _cotizacionActual.datosProyecto,
          notasSeguimiento: notasActualizadas,
        );
        _nuevaNotaController.clear();
      });

      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar nota: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // CAMBIAR EL ESTADO DEL CHECKLIST Y ASIGNAR QUIÉN LO COMPLETÓ
  Future<void> _cambiarEstadoNota(int indexOriginal, bool nuevoEstado) async {
    try {
      List<NotaSeguimiento> notasActualizadas = List.from(_cotizacionActual.notasSeguimiento);
      
      // Creamos una nueva instancia de la nota.
      // Si se marca como completada, se actualiza el 'creadaPor' al admin actual.
      // Si se desmarca, se queda con el admin actual también (ya que él fue quien la desmarcó).
      notasActualizadas[indexOriginal] = NotaSeguimiento(
        fecha: DateTime.now(), // Actualizamos la fecha a la hora de completarse
        comentario: notasActualizadas[indexOriginal].comentario,
        completada: nuevoEstado,
        creadaPor: _nombreAdminActual, // 👈 ACTUALIZAMOS QUIÉN CAMBIÓ EL ESTADO
      );

      await FirebaseFirestore.instance
          .collection('seguimiento_cotizaciones')
          .doc(_cotizacionActual.id)
          .update({
        'notas_seguimiento': notasActualizadas.map((n) => n.toJson()).toList(),
      });

      setState(() {
        _cotizacionActual = SeguimientoCotizacionModel(
          id: _cotizacionActual.id,
          adminEncargado: _cotizacionActual.adminEncargado,
          clienteEsNuevo: _cotizacionActual.clienteEsNuevo,
          idCliente: _cotizacionActual.idCliente,
          estatusCotizacion: _cotizacionActual.estatusCotizacion,
          fechaCotizacion: _cotizacionActual.fechaCotizacion,
          montoCotizado: _cotizacionActual.montoCotizado,
          datosCliente: _cotizacionActual.datosCliente,
          datosProyecto: _cotizacionActual.datosProyecto,
          notasSeguimiento: notasActualizadas,
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar tarea: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatoMoneda = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final formatoFecha = DateFormat('dd/MM/yyyy - hh:mm a');

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Text("DETALLE DE COTIZACIÓN", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _procesandoEstatus
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // CABECERA DE ESTATUS Y ADMIN ENCARGADO
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Monto Cotizado", style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(formatoMoneda.format(_cotizacionActual.montoCotizado),
                                  style: GoogleFonts.inter(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _cotizacionActual.estatusCotizacion == 'ACEPTADA'
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _cotizacionActual.estatusCotizacion,
                              style: GoogleFonts.inter(
                                color: _cotizacionActual.estatusCotizacion == 'ACEPTADA' ? Colors.greenAccent : Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      Row(
                        children: [
                          const Icon(Icons.assignment_ind_outlined, color: Color(0xFF8B5CF6), size: 18),
                          const SizedBox(width: 8),
                          Text("Encargado: ", style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
                          Text(
                            _cotizacionActual.adminEncargado.isEmpty ? 'Sin asignar' : _cotizacionActual.adminEncargado, 
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // SECCIÓN CLIENTE
                _buildSectionCard(
                  title: "DATOS DEL CLIENTE",
                  icon: Icons.person_outline,
                  color: const Color(0xFF06B6D4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow("Nombre:", _cotizacionActual.datosCliente.nombre),
                      _buildInfoRow("Teléfono:", _cotizacionActual.datosCliente.telefono),
                      _buildInfoRow("Dirección:", _cotizacionActual.datosCliente.direccion),
                      _buildInfoRow("Tipo de cliente:", _cotizacionActual.clienteEsNuevo ? "Cliente Nuevo" : "Cliente Existente"),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // SECCIÓN PROYECTO
                _buildSectionCard(
                  title: "DATOS DEL PROYECTO",
                  icon: Icons.hot_tub_outlined,
                  color: const Color(0xFF8B5CF6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow("Título:", _cotizacionActual.datosProyecto.titulo),
                      _buildInfoRow("Medidas:", _cotizacionActual.datosProyecto.medidas),
                      _buildInfoRow("Descripción:", _cotizacionActual.datosProyecto.descripcion.isEmpty ? 'Sin descripción' : _cotizacionActual.datosProyecto.descripcion),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // SECCIÓN CHECKLIST DE TAREAS / NOTAS
                Text(
                  "TAREAS Y NOTAS DE SEGUIMIENTO (${_cotizacionActual.notasSeguimiento.length})",
                  style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 12),

                if (_cotizacionActual.notasSeguimiento.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text("No hay tareas registradas en esta cotización.", style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
                  )
                else
                  ...List.generate(_cotizacionActual.notasSeguimiento.length, (index) {
                    final indexReverso = (_cotizacionActual.notasSeguimiento.length - 1) - index;
                    final nota = _cotizacionActual.notasSeguimiento[indexReverso];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E), 
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: nota.completada ? Colors.greenAccent.withOpacity(0.2) : Colors.white12),
                      ),
                      child: CheckboxListTile(
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: Colors.greenAccent,
                        checkColor: const Color(0xFF1E1E1E),
                        value: nota.completada,
                        onChanged: (bool? valor) {
                          if (valor != null) {
                            _cambiarEstadoNota(indexReverso, valor);
                          }
                        },
                        title: Text(
                          nota.comentario, 
                          style: TextStyle(
                            color: nota.completada ? Colors.white38 : Colors.white, 
                            fontSize: 14,
                            decoration: nota.completada ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        // 👇 AQUÍ AÑADIMOS EL NOMBRE DE QUIÉN COMPLETÓ/CREÓ LA TAREA
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "${formatoFecha.format(nota.fecha)} • ${nota.completada ? 'Completada por' : 'Añadida por'} ${nota.creadaPor}", 
                            style: TextStyle(
                              color: nota.completada ? Colors.greenAccent.withOpacity(0.6) : Colors.white38, 
                              fontSize: 11
                            )
                          ),
                        ),
                      ),
                    );
                  }).toList(),

                const SizedBox(height: 16),

                // INPUT PARA AGREGAR NUEVA NOTA RÁPIDA
                Row(
                  children: [
                    Expanded(
                      child: TextField(contextMenuBuilder: privacyTextMenu,
                        controller: _nuevaNotaController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Escribe una tarea o comentario de seguimiento...",
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF59E0B))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFFF59E0B)),
                      onPressed: _agregarNotaSeguimiento,
                    )
                  ],
                ),
                const SizedBox(height: 40),

                // BOTÓN DINÁMICO DE ACCIÓN DE ESTATUS
                if (_cotizacionActual.estatusCotizacion == 'PENDIENTE')
                  Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                      onPressed: _aprobarCotizacion,
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: Text("ACEPTAR COTIZACIÓN", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified, color: Colors.greenAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "ESTA COTIZACIÓN YA GENERÓ UN PROYECTO",
                            style: GoogleFonts.inter(color: Colors.greenAccent, fontWeight: FontWeight.w600, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Color color, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(title, style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: child,
        )
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14))),
        ],
      ),
    );
  }
}