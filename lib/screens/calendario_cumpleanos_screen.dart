import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../services/team_profile_helpers.dart';
import 'perfil_social_screen.dart';

class CalendarioCumpleanosScreen extends StatefulWidget {
  const CalendarioCumpleanosScreen({super.key});
  @override
  State<CalendarioCumpleanosScreen> createState() => _CalendarioCumpleanosScreenState();
}
class _CalendarioCumpleanosScreenState extends State<CalendarioCumpleanosScreen> {
  String _search = '';
  bool _monthOnly = false;
  @override
  Widget build(BuildContext context) {
    final today = mexicoToday();
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(title: const Text('Cumpleaños del equipo')), body: Column(children: [
      Container(margin: const EdgeInsets.all(18), padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFF35101E), Color(0xFF111012)])), child: const Row(children: [Icon(Icons.celebration_outlined, size: 35, color: Color(0xFFB7FF2A)), SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Celebramos a nuestra gente', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), SizedBox(height: 5), Text('Fechas, intereses y detalles que nos unen.', style: TextStyle(color: Colors.white60))]))])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: TextField(decoration: const InputDecoration(hintText: 'Buscar a una persona…', prefixIcon: Icon(Icons.search)), onChanged: (s) => setState(() => _search = s.trim().toLowerCase()))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9), child: Row(children: [ChoiceChip(label: const Text('Próximos'), selected: !_monthOnly, onSelected: (_) => setState(() => _monthOnly = false)), const SizedBox(width: 8), ChoiceChip(label: const Text('Este mes'), selected: _monthOnly, onSelected: (_) => setState(() => _monthOnly = true))])),
      Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: FirebaseFirestore.instance.collection('usuarios').snapshots(), builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No se pudo cargar el equipo. Revisa la conexión y los permisos.')));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final all = snapshot.data!.docs.where((d) => d.data()['activo'] != false && d.data()['cumpleanos'] is Timestamp).toList();
        DateTime birth(QueryDocumentSnapshot<Map<String, dynamic>> d) => (d.data()['cumpleanos'] as Timestamp).toDate();
        all.sort((a, b) { final cmp = nextTeamBirthday(birth(a), today).compareTo(nextTeamBirthday(birth(b), today)); return cmp != 0 ? cmp : (a.data()['nombre']?.toString() ?? '').compareTo(b.data()['nombre']?.toString() ?? ''); });
        final people = all.where((d) => (d.data()['nombre']?.toString().toLowerCase() ?? '').contains(_search) && (!_monthOnly || birth(d).month == today.month)).toList();
        if (people.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(25), child: Text('No hay cumpleaños en esta vista. Cada persona puede agregar su fecha desde Configuración.', textAlign: TextAlign.center)));
        return ListView.builder(padding: const EdgeInsets.fromLTRB(18, 0, 18, 30), itemCount: people.length, itemBuilder: (c, i) {
          final d = people[i]; final p = d.data(); final next = nextTeamBirthday(birth(d), today); final days = next.difference(today).inDays;
          final name = p['nombre']?.toString() ?? 'Integrante'; final photo = p['fotoUrl']?.toString() ?? '';
          final interests = profileTags(p['intereses']); final colors = profileTags(p['coloresFavoritos']);
          return Card(margin: const EdgeInsets.only(bottom: 12), color: days == 0 ? const Color(0xFF2A1420) : const Color(0xFF111012), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: days == 0 ? const Color(0xFFB7FF2A) : Colors.white12)), child: InkWell(borderRadius: BorderRadius.circular(22), onTap: () => _openProfile(d.id), child: Padding(padding: const EdgeInsets.all(17), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [CircleAvatar(radius: 26, backgroundImage: photo.isEmpty ? null : NetworkImage(photo), child: photo.isEmpty ? const Icon(Icons.cake_outlined) : null), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), Text(DateFormat('d MMMM', 'es').format(birth(d)), style: const TextStyle(color: Colors.white60))])), Flexible(child: Text(days == 0 ? '¡HOY! 🎉' : days == 1 ? 'Mañana' : 'En $days días', textAlign: TextAlign.end, style: const TextStyle(color: Color(0xFFB7FF2A), fontWeight: FontWeight.w700)))]),
            if (interests.isNotEmpty || colors.isNotEmpty) ...[const SizedBox(height: 10), Wrap(spacing: 6, runSpacing: 4, children: [for (final s in interests.take(4)) Chip(avatar: const Icon(Icons.favorite_border, size: 14), label: Text(s)), for (final s in colors.take(3)) Chip(avatar: const Icon(Icons.palette_outlined, size: 14), label: Text(s))])]
            else const Padding(padding: EdgeInsets.only(top: 10), child: Text('Sus gustos todavía están por descubrir.', style: TextStyle(fontSize: 12, color: Colors.white38))),
          ]))));
        });
      })),
    ]));
  }
  Future<void> _openProfile(String id) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final me = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (!me.exists || !mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PerfilSocialScreen(usuarioActual: UserModel.fromFirestore(me), perfilId: id)));
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el perfil.'))); }
  }
}
