import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'profile_social_links.dart';

class TeamNoteDraft {
  final String text;
  final String song;
  final String url;
  const TeamNoteDraft({required this.text, this.song = '', this.url = ''});
  TeamNoteDraft validated() {
    final t = text.trim(), s = song.trim(), u = ProfileSocialLinks.music(url);
    if (t.length > 180 || s.length > 100 || (t.isEmpty && u.isEmpty)) {
      throw const FormatException('Escribe una nota de hasta 180 caracteres o agrega un enlace de canción.');
    }
    if (s.isNotEmpty && u.isEmpty) throw const FormatException('Agrega el enlace para compartir esa canción.');
    return TeamNoteDraft(text: t, song: s, url: u);
  }
}

/// A note is a real social publication, shared with the authenticated team.
/// One stable document per person prevents double posts on a retry.
class TeamNotesService {
  final FirebaseFirestore _db;
  TeamNotesService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _posts => _db.collection('publicaciones_sociales');
  Stream<QuerySnapshot<Map<String, dynamic>>> watch() => _posts.where('tipo', isEqualTo: 'nota_equipo').snapshots();
  Future<void> save(UserModel user, TeamNoteDraft draft) async {
    if (FirebaseAuth.instance.currentUser?.uid != user.id) throw StateError('Tu sesión cambió. Vuelve a entrar.');
    final d = draft.validated();
    final ref = _posts.doc('nota_equipo_${user.id}');
    await _db.runTransaction((t) async {
      final old = await t.get(ref);
      if (old.exists && old.data()?['autorId'] != user.id) throw StateError('Nota no autorizada.');
      final data = <String, dynamic>{
        'autorId': user.id, 'autorNombre': user.nombre, 'autorFotoUrl': user.fotoUrl ?? '', 'autorRol': user.rol,
        'tipo': 'nota_equipo', 'estado': 'nota', 'notaTexto': d.text, 'musicaTitulo': d.song, 'musicaUrl': d.url,
        'texto': [d.text, if (d.url.isNotEmpty) '♫ ${d.song.isEmpty ? 'Mi canción' : d.song}\n${d.url}'].where((v) => v.isNotEmpty).join('\n'),
        'fecha': FieldValue.serverTimestamp(),
      };
      if (old.exists) {t.update(ref, data);} else {t.set(ref, {...data, 'imagenes': <String>[], 'videos': <String>[], 'rutasStorage': <String>[], 'rutasVideosStorage': <String>[], 'likesPor': <String>[], 'comentariosCount': 0});}
    });
  }
  Future<void> remove(String userId) async {
    if (FirebaseAuth.instance.currentUser?.uid != userId) throw StateError('Tu sesión cambió.');
    await _posts.doc('nota_equipo_$userId').delete();
  }
}
