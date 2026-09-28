import '../widgets/inline_photo.dart';
import '../presentation/appearance.dart';
import '../services/external_transfer.dart';
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
    return Scaffold(backgroundColor: StiloColors.background, appBar: AppBar(title: Text('Cumpleaños del equipo')), body: Column(children: [
      Container(margin: EdgeInsets.all(18), padding: EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(colors: [StiloColors.surface, StiloColors.surface])), child: Row(children: [Icon(Icons.celebration_outlined, size: 35, color: StiloColors.accent), SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Celebramos a nuestra gente', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), SizedBox(height: 5), Text('Fechas, intereses y detalles que nos unen.', style: TextStyle(color: StiloColors.text.withValues(alpha: .60)))]))])),
      Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: TextField(contextMenuBuilder: privacyTextMenu, decoration: InputDecoration(hintText: 'Buscar a una persona…', prefixIcon: Icon(Icons.search)), onChanged: (s) => setState(() => _search = s.trim().toLowerCase()))),
      Padding(padding: EdgeInsets.symmetric(horizontal: 18, vertical: 9), child: Row(children: [ChoiceChip(label: Text('Próximos'), selected: !_monthOnly, onSelected: (_) => setState(() => _monthOnly = false)), SizedBox(width: 8), ChoiceChip(label: Text('Este mes'), selected: _monthOnly, onSelected: (_) => setState(() => _monthOnly = true))])),
      Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: FirebaseFirestore.instance.collection('usuarios').snapshots(), builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No se pudo cargar el equipo. Revisa la conexión y los permisos.')));
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        final all = snapshot.data!.docs.where((d) => d.data()['activo'] != false && d.data()['cumpleanos'] is Timestamp).toList();
        DateTime birth(QueryDocumentSnapshot<Map<String, dynamic>> d) => (d.data()['cumpleanos'] as Timestamp).toDate();
        all.sort((a, b) { final cmp = nextTeamBirthday(birth(a), today).compareTo(nextTeamBirthday(birth(b), today)); return cmp != 0 ? cmp : (a.data()['nombre']?.toString() ?? '').compareTo(b.data()['nombre']?.toString() ?? ''); });
        final people = all.where((d) => (d.data()['nombre']?.toString().toLowerCase() ?? '').contains(_search) && (!_monthOnly || birth(d).month == today.month)).toList();
        if (people.isEmpty) return Center(child: Padding(padding: EdgeInsets.all(25), child: Text('No hay cumpleaños en esta vista. Cada persona puede agregar su fecha desde Configuración.', textAlign: TextAlign.center)));
        return ListView.builder(padding: EdgeInsets.fromLTRB(18, 0, 18, 30), itemCount: people.length, itemBuilder: (c, i) {
          final d = people[i]; final p = d.data(); final next = nextTeamBirthday(birth(d), today); final days = next.difference(today).inDays;
          final name = p['nombre']?.toString() ?? 'Integrante'; final photo = p['fotoUrl']?.toString() ?? '';
          final interests = profileTags(p['intereses']); final colors = profileTags(p['coloresFavoritos']);
          return Card(margin: EdgeInsets.only(bottom: 12), color: days == 0 ? StiloColors.surface : StiloColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: days == 0 ? StiloColors.accent : StiloColors.text.withValues(alpha: .12))), child: InkWell(borderRadius: BorderRadius.circular(22), onTap: () => _openProfile(d.id), child: Padding(padding: EdgeInsets.all(17), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [CircleAvatar(radius: 26, backgroundImage: photo.isEmpty ? null : stiloImageProvider(photo), child: photo.isEmpty ? Icon(Icons.cake_outlined) : null), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), Text(DateFormat('d MMMM', 'es').format(birth(d)), style: TextStyle(color: StiloColors.text.withValues(alpha: .60)))])), Flexible(child: Text(days == 0 ? '¡HOY! 🎉' : days == 1 ? 'Mañana' : 'En $days días', textAlign: TextAlign.end, style: TextStyle(color: StiloColors.accent, fontWeight: FontWeight.w700)))]),
            if (interests.isNotEmpty || colors.isNotEmpty) ...[SizedBox(height: 10), Wrap(spacing: 6, runSpacing: 4, children: [for (final s in interests.take(4)) Chip(avatar: Icon(Icons.favorite_border, size: 14), label: Text(s)), for (final s in colors.take(3)) Chip(avatar: Icon(Icons.palette_outlined, size: 14), label: Text(s))])]
            else Padding(padding: EdgeInsets.only(top: 10), child: Text('Sus gustos todavía están por descubrir.', style: TextStyle(fontSize: 12, color: StiloColors.text.withValues(alpha: .38)))),
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
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo abrir el perfil.'))); }
  }
}
