import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/notificaciones_service.dart';

class AdminAlertaGeneralScreen extends StatefulWidget {
  const AdminAlertaGeneralScreen({super.key});

  @override
  State<AdminAlertaGeneralScreen> createState() => _AdminAlertaGeneralScreenState();
}

class _AdminAlertaGeneralScreenState extends State<AdminAlertaGeneralScreen> {
  static const _bg = Color(0xFF050506);
  static const _panel = Color(0xFF121012);
  static const _wine = Color(0xFF8E1538);
  static const _neon = Color(0xFFB7FF2A);
  final _controller = TextEditingController(text: 'Atención equipo Sauna Stilo. Comuníquense con Administración de inmediato.');
  final _service = NotificacionesService();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final message = _controller.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe el motivo de la alerta.')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('¿Enviar alerta a TODO el equipo?'),
        content: const Text('Se enviará una notificación urgente a todos los dispositivos registrados. Úsala solo cuando necesites la atención inmediata del equipo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _wine, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ENVIAR ALERTA'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _sending = true);
    try {
      await _service.enviarAlertaGeneral(mensaje: message);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alerta general enviada al sistema de notificaciones.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo enviar la alerta: $error')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(title: const Text('Alerta General'), backgroundColor: _bg),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _wine.withOpacity(.7), width: 1.2),
              boxShadow: [BoxShadow(color: _wine.withOpacity(.18), blurRadius: 30, spreadRadius: 1)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: _wine.withOpacity(.22), borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('LLAMAR A TODO EL EQUIPO', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: .3)),
                  const SizedBox(height: 4),
                  Text('Alerta de prioridad máxima', style: GoogleFonts.inter(color: _neon, fontSize: 11, fontWeight: FontWeight.w800)),
                ])),
              ]),
              const SizedBox(height: 18),
              Text('Este botón envía un aviso urgente a todos los usuarios con un dispositivo registrado. En segundo plano el sistema solicita prioridad alta y sonido; el volumen final sigue dependiendo de permisos, modo Silencio/Enfoque y restricciones del teléfono.', style: GoogleFonts.inter(color: Colors.white70, height: 1.45, fontSize: 12.5)),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                minLines: 3,
                maxLines: 6,
                maxLength: 420,
                decoration: const InputDecoration(labelText: 'Mensaje de alerta', hintText: 'Escribe qué necesita hacer el equipo ahora'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _wine, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(62)),
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.notifications_active_rounded),
                  label: Text(_sending ? 'ENVIANDO…' : 'ACTIVAR ALERTA GENERAL', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF10130D), borderRadius: BorderRadius.circular(20), border: Border.all(color: _neon.withOpacity(.2))),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.verified_user_outlined, color: _neon),
              SizedBox(width: 10),
              Expanded(child: Text('Protección: el servidor verifica que la alerta haya sido creada por una cuenta de Administración antes de distribuirla a todo el equipo.')),
            ]),
          ),
        ],
      ),
    );
  }
}
