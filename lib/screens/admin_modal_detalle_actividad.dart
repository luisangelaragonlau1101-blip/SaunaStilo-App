import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/actividad_model.dart';
import '../services/actividades_service.dart';

class ModalDetalleActividad extends StatefulWidget {
  final ActividadModel actividad;

  const ModalDetalleActividad({Key? key, required this.actividad}) : super(key: key);

  @override
  State<ModalDetalleActividad> createState() => _ModalDetalleActividadState();
}

class _ModalDetalleActividadState extends State<ModalDetalleActividad> {
  final TextEditingController _observacionesController = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _observacionesController.text = widget.actividad.observacionesAdmin;
  }

  // Agrega texto rápido desde los chips de administración
  void _agregarNotaRapida(String texto) {
    setState(() {
      if (_observacionesController.text.isEmpty) {
        _observacionesController.text = texto;
      } else {
        _observacionesController.text += " | $texto";
      }
    });
  }

  // Muestra la imagen en pantalla completa con opción de zoom
  void _mostrarImagenEnGrande(BuildContext context, String imageUrl) {
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
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- LÓGICA DE ATRASO DINÁMICA ---
    bool estaAtrasada = widget.actividad.estatus != 'completado' && DateTime.now().isAfter(widget.actividad.fechaTermino);
    
    String textoEstatus = estaAtrasada ? 'ATRASADO' : widget.actividad.estatus;

    Color estatusColor = widget.actividad.estatus == 'completado'
        ? Colors.greenAccent
        : estaAtrasada
            ? Colors.redAccent // Alerta roja si ya pasó la fecha límite
            : widget.actividad.estatus == 'en_progreso'
                ? Colors.cyanAccent
                : Colors.orangeAccent;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85, // Ocupa el 85% de la pantalla
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Control superior de arrastre
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 20),

          // Título y Estatus
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.actividad.titulo.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: estatusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  textoEstatus.toUpperCase(), // Usamos la variable dinámica
                  style: GoogleFonts.inter(color: estatusColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Cuerpo con scroll para el desglose operativo
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fechas de control operativa
                  Row(
                    children: [
                      Icon(
                        estaAtrasada ? Icons.error_outline : Icons.calendar_today, 
                        color: estaAtrasada ? Colors.redAccent : Colors.white54, 
                        size: 16
                      ),
                      const SizedBox(width: 8),
                      Text(
                        estaAtrasada 
                            ? "Venció el: ${DateFormat('dd/MM/yyyy HH:mm').format(widget.actividad.fechaTermino)}"
                            : "Fecha Límite: ${DateFormat('dd/MM/yyyy HH:mm').format(widget.actividad.fechaTermino)}",
                        style: GoogleFonts.inter(
                          color: estaAtrasada ? Colors.redAccent : Colors.white70, 
                          fontSize: 14,
                          fontWeight: estaAtrasada ? FontWeight.bold : FontWeight.normal
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 30),

                  // SECCIÓN: EVIDENCIA POR FOTO (Trabajador)
                  Text("EVIDENCIA FOTOGRÁFICA", style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  const SizedBox(height: 10),
                  widget.actividad.evidenciaFotos.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            children: [
                              const Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 32),
                              const SizedBox(height: 8),
                              Text("El trabajador no ha subido fotos aún.", style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
                            ],
                          ),
                        )
                      : SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.actividad.evidenciaFotos.length,
                         itemBuilder: (context, i) {
  return GestureDetector(
    onTap: () {
      // Abre la imagen tocada en grande
      _mostrarImagenEnGrande(context, widget.actividad.evidenciaFotos[i]);
    },
    child: Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: NetworkImage(widget.actividad.evidenciaFotos[i]),
          fit: BoxFit.cover,
        ),
      ),
    ),
  );
},
                          ),
                        ),
                  const Divider(color: Colors.white10, height: 30),

                  // SECCIÓN: COMENTARIOS DEL TRABAJADOR
                  Text("COMENTARIOS DEL TRABAJADOR", style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  const SizedBox(height: 8),
                  Text(
                    widget.actividad.comentariosTrabajador.isEmpty 
                        ? "Sin comentarios del operador." 
                        : widget.actividad.comentariosTrabajador,
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, height: 1.4),
                  ),
                  const Divider(color: Colors.white10, height: 30),

                  // SECCIÓN: OBSERVACIONES DEL ADMIN (Formulario interactivo)
                  Text("OBSERVACIONES Y NOTAS OPERATIVAS (ADMIN)", style: GoogleFonts.inter(color: const Color(0xFFFFDE21), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  const SizedBox(height: 12),
                  
                  // Chips de acceso rápido
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickChip("Descuento por error", Colors.redAccent),
                      _buildQuickChip("Multa de herramienta", Colors.orangeAccent),
                      _buildQuickChip("Llamada de atención", Colors.yellow),
                      _buildQuickChip("Incentivo económico", Colors.greenAccent),
                      _buildQuickChip("Repetición del trabajo", Colors.greenAccent),
                      _buildQuickChip("Suspensión", Colors.redAccent),
                    ],
                  ),
                  const SizedBox(height: 15),

                  TextFormField(
                    controller: _observacionesController,
                    maxLines: 3,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Escribe multas, suspensiones, observaciones o felicitaciones aquí...',
                      hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF121212),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Botón fijo abajo para Guardar Notas
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFDE21),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _guardando ? null : _guardarObservaciones,
              child: _guardando
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Text('ACTUALIZAR OBSERVACIONES', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, Color color) {
    return ActionChip(
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.4)),
      label: Text(label, style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      onPressed: () => _agregarNotaRapida(label),
    );
  }

  Future<void> _guardarObservaciones() async {
    setState(() => _guardando = true);
    try {
      await ActividadesService().registrarObservacionesAdmin(
        widget.actividad.id, 
        _observacionesController.text.trim()
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Observaciones actualizadas correctamente'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }
}
