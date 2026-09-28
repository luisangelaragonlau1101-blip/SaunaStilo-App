import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../presentation/appearance.dart';
import '../services/team_profile_helpers.dart';
import 'inventory_photo.dart';

String? celebrationFor(DateTime today, DateTime? birthday) {
  if (birthday != null && nextTeamBirthday(birthday, today) == DateTime(today.year, today.month, today.day)) return '¡Feliz cumpleaños! Hoy celebramos contigo 🎂';
  if (today.month == 1 && today.day <= 6) return 'Un nuevo año para construir juntos ✨';
  if (today.month == 2 && today.day == 14) return 'Celebremos la amistad y el trabajo en equipo 💗';
  if (today.month == 9 && today.day >= 13 && today.day <= 16) return 'Hecho en México, con orgullo 🇲🇽';
  if ((today.month == 10 && today.day >= 28) || (today.month == 11 && today.day <= 2)) return 'Tradiciones que nos unen · Día de Muertos 🏵️';
  if (today.month == 12 && today.day >= 16) return 'Una temporada para agradecer y compartir ✨';
  return null;
}
String roleLabel(UserModel user) => user.panelIngenieria ? 'Ingeniería' : switch (user.rol) {'admin' => 'Administración', 'maestro' => 'Maestro', 'almacenista' => 'Almacén', _ => 'Mi equipo'};
class PersonalHeader extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onProfile;
  const PersonalHeader({super.key, required this.user, this.onProfile});
  @override State<PersonalHeader> createState() => _PersonalHeaderState();
}
class _PersonalHeaderState extends State<PersonalHeader> with WidgetsBindingObserver {
  Timer? _midnight;
  UserModel get user => widget.user;
  VoidCallback? get onProfile => widget.onProfile;
  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _schedule(); }
  void _schedule() {
    _midnight?.cancel();
    final now = DateTime.now().toUtc().subtract(const Duration(hours: 6));
    final next = DateTime.utc(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now) + const Duration(seconds: 1), () { if (mounted) { setState(() {}); _schedule(); } });
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) { setState(() {}); _schedule(); } }
  @override void dispose() { _midnight?.cancel(); WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override Widget build(BuildContext context) {
    Theme.of(context);
    final colors = Theme.of(context).colorScheme;
    final celebration = AppearanceController.instance.celebrations ? celebrationFor(mexicoToday(), user.cumpleanos) : null;
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: LinearGradient(colors: [colors.primary.withValues(alpha: .16), colors.surfaceContainerLow]), border: Border.all(color: colors.outlineVariant)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [InkWell(onTap: onProfile, borderRadius: BorderRadius.circular(50), child: Semantics(label: 'Foto de perfil de ${user.nombre}', button: onProfile != null, child: ClipOval(child: SizedBox(width: 60, height: 60, child: (user.fotoUrl ?? '').isNotEmpty ? InventoryPhoto(imageUrl: user.fotoUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => Icon(Icons.person, color: colors.primary, size: 34)) : ColoredBox(color: colors.primaryContainer, child: Center(child: Text(user.nombre.isEmpty ? 'S' : user.nombre.characters.first, style: TextStyle(fontSize: 24, color: colors.onPrimaryContainer)))))))),
        const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Hola, ${user.nombre.trim().split(' ').first}', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(roleLabel(user), style: TextStyle(color: colors.onSurfaceVariant))])),
        IconButton(tooltip: 'Personalizar mi panel', onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AppearanceScreen())), icon: Icon(Icons.palette_outlined, color: colors.primary)),
      ]),
      if (celebration != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(celebration, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700))),
      const SizedBox(height: 18), Text('SAUNA STILO', style: TextStyle(fontSize: 22, letterSpacing: 3, fontWeight: FontWeight.w900, color: colors.onSurface.withValues(alpha: .18), shadows: [Shadow(color: colors.primary.withValues(alpha: .16), offset: const Offset(0, 3), blurRadius: 14)])),
    ]));
  }
}
