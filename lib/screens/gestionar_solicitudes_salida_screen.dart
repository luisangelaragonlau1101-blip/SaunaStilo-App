import '../presentation/appearance.dart';
import '../services/external_transfer.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/proyecto_model.dart';

class GestionarSolicitudesSalidaScreen extends StatefulWidget {
  final Proyecto proyecto;
  const GestionarSolicitudesSalidaScreen({Key? key, required this.proyecto}) : super(key: key);

  @override
  State<GestionarSolicitudesSalidaScreen> createState() => _GestionarSolicitudesSalidaScreenState();
}

class _GestionarSolicitudesSalidaScreenState extends State<GestionarSolicitudesSalidaScreen> {

  Future<void> _enviarKitAObra(String solicitudId) async {
    bool confirmar = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: StiloColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.local_shipping_outlined, color: Color(0xFF06B6D4)),
            SizedBox(width: 12),
            Text("Enviar a Obra", style: GoogleFonts.outfit(color: StiloColors.text, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text("¿Confirmas que envías este kit? El maestro deberá confirmar de recibido en obra para que se descuente del almacén.", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancelar", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF06B6D4), foregroundColor: StiloColors.background),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Sí, Enviar", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmar) return;

    try {
      await FirebaseFirestore.instance.collection('solicitudes_salida').doc(solicitudId).update({
        'estatus': 'enviada_a_obra',
        'fechaEnvio': FieldValue.serverTimestamp(),
        'enviadoPorId': FirebaseAuth.instance.currentUser?.uid,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.greenAccent, content: Text("Kit enviado a obra. Esperando confirmación del maestro.", style: GoogleFonts.inter(color: StiloColors.background, fontWeight: FontWeight.bold))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text("Error: $e")));
    }
  }

  void _abrirChecklistDevolucion(Map<String, dynamic> data, String solicitudId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChecklistDevolucionModal(
        solicitudId: solicitudId,
        articulos: data['articulos'] ?? [],
        proyectoId: widget.proyecto.id,
        trabajadorNombre: data['solicitanteNombre'] ?? 'Desconocido',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      backgroundColor: StiloColors.surface,
      appBar: AppBar(
        backgroundColor: StiloColors.surface,
        elevation: 0,
        title: Text("GESTIÓN DE KITS", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('solicitudes_salida')
            .where('proyectoId', isEqualTo: widget.proyecto.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 60, color: StiloColors.text.withOpacity(0.2)),
                  SizedBox(height: 16),
                  Text("No hay solicitudes de salida", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 16)),
                  SizedBox(height: 8),
                  Text("Los maestros aún no han pedido kits para este proyecto.", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .38), fontSize: 12)),
                ],
              ),
            );
          }

          var docs = snapshot.data!.docs;
          docs.sort((a, b) {
            Timestamp? tA = (a.data() as Map<String, dynamic>)['fechaSolicitud'] as Timestamp?;
            Timestamp? tB = (b.data() as Map<String, dynamic>)['fechaSolicitud'] as Timestamp?;
            if (tA == null || tB == null) return 0;
            return tB.compareTo(tA);
          });

          return ListView.builder(
            padding: EdgeInsets.all(20),
            physics: BouncingScrollPhysics(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index];
              var data = doc.data() as Map<String, dynamic>;

              String estatus = data['estatus'] ?? 'pendiente';
              List articulos = data['articulos'] ?? [];
              String solicitante = data['solicitanteNombre'] ?? 'Desconocido';
              Timestamp? fecha = data['fechaSolicitud'] as Timestamp?;
              String fechaStr = fecha != null ? DateFormat('dd/MM/yyyy HH:mm').format(fecha.toDate()) : 'Sin fecha';

              Color statusColor;
              String estatusText;

              if (estatus == 'pendiente') {
                statusColor = Colors.orangeAccent;
                estatusText = 'NUEVA SOLICITUD';
              } else if (estatus == 'enviada_a_obra') {
                statusColor = Color(0xFF06B6D4);
                estatusText = 'EN CAMINO A OBRA';
              } else if (estatus == 'recibida_en_obra') {
                statusColor = Colors.greenAccent;
                estatusText = 'EN USO (OBRA)';
              } else if (estatus == 'recibida_con_danos') {
                statusColor = Colors.orangeAccent;
                estatusText = 'EN OBRA (CON DAÑOS REPORTADOS)';
              } else if (estatus == 'completada') {
                statusColor = Colors.blueAccent;
                estatusText = 'DEVUELTO / CERRADO';
              } else if (estatus == 'completada_con_danos') {
                statusColor = Colors.redAccent;
                estatusText = 'DEVUELTO (HERRAMIENTAS DAÑADAS)';
              } else {
                statusColor = StiloColors.text.withValues(alpha: .54);
                estatusText = estatus.toUpperCase();
              }

              return Card(
                color: StiloColors.surface,
                margin: EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: statusColor.withOpacity(0.3))
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // ---> AQUÍ SE APLICÓ LA SOLUCIÓN DEL DESBORDAMIENTO <---
                          Flexible(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor.withOpacity(0.5))
                              ),
                              child: Text(
                                estatusText,
                                style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis, // Si no cabe, añade "..."
                              ),
                            ),
                          ),
                          SizedBox(width: 8), // Añadimos una separación segura
                          Text(fechaStr, style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 12)),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Solicita: $solicitante",
                        style: GoogleFonts.outfit(color: StiloColors.text, fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis, // Protección extra
                      ),
                      SizedBox(height: 4),
                      Text("Kit con ${articulos.length} artículos diferentes", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .70), fontSize: 14)),
                      SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: StiloColors.text,
                                side: BorderSide(color: StiloColors.text.withValues(alpha: .24)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: Icon(Icons.visibility_outlined, size: 18),
                              label: Text("Ver Kit"),
                              onPressed: () => _mostrarDetalleKit(context, data),
                            ),
                          ),

                          if (estatus == 'pendiente') ...[
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF06B6D4),
                                  foregroundColor: StiloColors.background,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: Icon(Icons.local_shipping_outlined, size: 18),
                                label: Text("Enviar", style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () => _enviarKitAObra(doc.id),
                              ),
                            ),
                          ],

                          if (estatus == 'recibida_en_obra' || estatus == 'recibida_con_danos') ...[
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent,
                                  foregroundColor: StiloColors.background,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: Icon(Icons.fact_check_outlined, size: 18),
                                label: Text("Recibir Kit", style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () => _abrirChecklistDevolucion(data, doc.id),
                              ),
                            ),
                          ]
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _mostrarDetalleKit(BuildContext context, Map<String, dynamic> data) {
    List articulos = data['articulos'] ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.70,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: StiloColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4, margin: EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(color: StiloColors.text.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Text("Contenido del Kit", style: GoogleFonts.outfit(color: StiloColors.text, fontSize: 24, fontWeight: FontWeight.bold)),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(color: StiloColors.text.withValues(alpha: .10)),
                ),
                Expanded(
                  child: ListView.separated(
                    physics: BouncingScrollPhysics(),
                    itemCount: articulos.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = articulos[index];
                      final bool esRetornable = item['esRetornable'] ?? false;

                      return Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: StiloColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: StiloColors.text.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              esRetornable ? Icons.build_rounded : Icons.lightbulb_outline,
                              color: esRetornable ? Colors.orangeAccent : Colors.cyanAccent,
                              size: 28
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['nombreInsumo'] ?? 'Desconocido', style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.w600, fontSize: 14)),
                                  SizedBox(height: 4),
                                  Text(esRetornable ? "RETORNABLE" : "SE QUEDA EN OBRA", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Text("x${item['cantidad']}", style: GoogleFonts.outfit(color: StiloColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// CHECKLIST Y REPORTE DE DAÑOS POR HERRAMIENTA (USANDO ÍNDICE INEFABLE)
// ============================================================================
class ChecklistDevolucionModal extends StatefulWidget {
  final String solicitudId;
  final List articulos;
  final String proyectoId;
  final String trabajadorNombre;

  ChecklistDevolucionModal({
    Key? key,
    required this.solicitudId,
    required this.articulos,
    required this.proyectoId,
    required this.trabajadorNombre,
  }) : super(key: key);

  @override
  State<ChecklistDevolucionModal> createState() => _ChecklistDevolucionModalState();
}

class _ChecklistDevolucionModalState extends State<ChecklistDevolucionModal> {
  final Map<int, bool> _evaluacion = {};
  final Map<int, TextEditingController> _notasPorHerramienta = {};

  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.articulos.length; i++) {
      if (widget.articulos[i]['esRetornable'] == true) {
        _evaluacion[i] = true;
        _notasPorHerramienta[i] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _notasPorHerramienta.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _guardarChecklist() async {
    setState(() => _procesando = true);

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      DocumentReference solicitudRef = FirebaseFirestore.instance.collection('solicitudes_salida').doc(widget.solicitudId);

      bool huboDanos = false;

      for (int i = 0; i < widget.articulos.length; i++) {
        var item = widget.articulos[i];

        if (item['esRetornable'] == true) {
          String insumoId = item['insumoId']?.toString() ?? item['id']?.toString() ?? item['idInsumo']?.toString() ?? '';
          int cantidad = int.tryParse(item['cantidad'].toString()) ?? 0;
          bool estaBueno = _evaluacion[i] ?? true;

          if (insumoId.isNotEmpty && cantidad > 0) {
            if (estaBueno) {
              DocumentReference insumoRef = FirebaseFirestore.instance.collection('insumos_inventario').doc(insumoId);

              batch.set(insumoRef, {
                'cantidad_disponible': FieldValue.increment(cantidad),
                'ultima_actualizacion': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

            } else {
              huboDanos = true;
              String notasEspecificas = _notasPorHerramienta[i]?.text.trim() ?? '';

              DocumentReference tallerRef = FirebaseFirestore.instance.collection('reparaciones_taller').doc();
              batch.set(tallerRef, {
                'insumoId': insumoId,
                'nombreInsumo': item['nombreInsumo'],
                'cantidad': cantidad,
                'origen': 'devolucion_obra',
                'proyectoId': widget.proyectoId,
                'reportadoPor': widget.trabajadorNombre,
                'fechaIngreso': FieldValue.serverTimestamp(),
                'estatus': 'en_reparacion',
                'notasDelFallo': notasEspecificas,
              });
            }
          }
        }
      }

      batch.update(solicitudRef, {
        'estatus': huboDanos ? 'completada_con_danos' : 'completada',
        'fechaDevolucion': FieldValue.serverTimestamp(),
        'recibidoPorId': FirebaseAuth.instance.currentUser?.uid,
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: huboDanos ? Colors.redAccent : Colors.greenAccent,
            content: Text(
              huboDanos ? "Herramientas dañadas enviadas al taller." : "Todo el kit regresó en perfecto estado al inventario.",
              style: TextStyle(color: StiloColors.background, fontWeight: FontWeight.bold)
            )
          )
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.redAccent, content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    bool noHayRetornables = widget.articulos.where((i) => i['esRetornable'] == true).isEmpty;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: BoxDecoration(
          color: StiloColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(top: 12, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          children: [
            Container(width: 40, height: 4, margin: EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: StiloColors.text.withOpacity(0.2), borderRadius: BorderRadius.circular(10))),

            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Recepción de Almacén", style: GoogleFonts.outfit(color: StiloColors.text, fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text("Si algo regresa roto, márcalo y se irá directo a la lista del taller.", style: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .54), fontSize: 13)),
                    SizedBox(height: 24),

                    if (noHayRetornables)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text("Este kit solo tenía consumibles. No hay herramientas para revisar.", textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.orangeAccent)),
                        ),
                      )
                    else
                      ...widget.articulos.asMap().entries.map((entry) {
                        int index = entry.key;
                        var item = entry.value;

                        if (item['esRetornable'] != true) return SizedBox.shrink();

                        bool estaBueno = _evaluacion[index] ?? true;

                        return Container(
                          margin: EdgeInsets.only(bottom: 16),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: StiloColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: estaBueno ? StiloColors.text.withOpacity(0.05) : Colors.redAccent.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.build_circle_outlined, color: estaBueno ? Color(0xFF06B6D4) : Colors.redAccent, size: 28),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(item['nombreInsumo'], style: GoogleFonts.inter(color: StiloColors.text, fontWeight: FontWeight.bold, fontSize: 15)),
                                  ),
                                  Text("x${item['cantidad']}", style: GoogleFonts.outfit(color: StiloColors.text, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _evaluacion[index] = true;
                                          _notasPorHerramienta[index]?.clear();
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: estaBueno ? Colors.greenAccent.withOpacity(0.15) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: estaBueno ? Colors.greenAccent : StiloColors.text.withValues(alpha: .24),
                                            width: estaBueno ? 2 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              estaBueno ? Icons.check_circle : Icons.check_circle_outline,
                                              color: estaBueno ? Colors.greenAccent : StiloColors.text.withValues(alpha: .54),
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              "Regresó Bien",
                                              style: GoogleFonts.inter(
                                                color: estaBueno ? Colors.greenAccent : StiloColors.text.withValues(alpha: .54),
                                                fontWeight: estaBueno ? FontWeight.bold : FontWeight.w500,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() => _evaluacion[index] = false),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: !estaBueno ? Colors.redAccent.withOpacity(0.15) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: !estaBueno ? Colors.redAccent : StiloColors.text.withValues(alpha: .24),
                                            width: !estaBueno ? 2 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              !estaBueno ? Icons.report_problem : Icons.report_problem_outlined,
                                              color: !estaBueno ? Colors.redAccent : StiloColors.text.withValues(alpha: .54),
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              "Dañado",
                                              style: GoogleFonts.inter(
                                                color: !estaBueno ? Colors.redAccent : StiloColors.text.withValues(alpha: .54),
                                                fontWeight: !estaBueno ? FontWeight.bold : FontWeight.w500,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (!estaBueno) ...[
                                SizedBox(height: 16),
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Describe el daño para el taller:", style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                      SizedBox(height: 8),
                                      TextField(contextMenuBuilder: privacyTextMenu,
                                        controller: _notasPorHerramienta[index],
                                        style: GoogleFonts.inter(color: StiloColors.text, fontSize: 14),
                                        decoration: InputDecoration(
                                          hintText: "Ej. Se quemó el motor...",
                                          hintStyle: GoogleFonts.inter(color: StiloColors.text.withValues(alpha: .38), fontSize: 13),
                                          filled: true,
                                          fillColor: StiloColors.surface,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              ]
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: StiloColors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _procesando ? SizedBox.shrink() : Icon(Icons.inventory_rounded),
                label: _procesando
                    ? CircularProgressIndicator(color: StiloColors.background)
                    : Text("GUARDAR EN INVENTARIO", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                onPressed: _procesando ? null : _guardarChecklist,
              ),
            )
          ],
        ),
      ),
    );
  }
}
