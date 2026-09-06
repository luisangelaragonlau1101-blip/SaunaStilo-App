import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'party_match.dart';

/// One shared-device save slot, containing only local game state. Never Auth or Firestore.
class PartyStore {
  static const key = 'sauna.pausa.local.v1';
  static Future<void> _tail = Future<void>.value();
  static Future<PartyMatch?> read() async {
    await _tail;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    if (raw.length > 12000) throw const FormatException('Partida local demasiado grande.');
    return PartyMatch.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }
  static Future<void> save(PartyMatch match) {
    // Snapshot immediately; serialized writes cannot restore an older turn after a newer turn.
    final value = jsonEncode(match.toJson());
    final next = _tail.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, value)) throw StateError('No se guardó la partida.');
    });
    _tail = next.catchError((Object _) {});
    return next;
  }
}
