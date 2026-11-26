import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const attendanceRecordingRoles = {
  'admin',
  'trabajador',
  'maestro',
  'almacenista',
  'finanzas',
  'contabilidad',
  'direccion',
};
Map<String, dynamic> nativeAttendanceReceipt({
  required String userId,
  required String day,
  required Map<String, dynamic> profile,
  required Map<String, dynamic> record,
  bool cached = false,
  bool pending = false,
  Map<String, dynamic> legacy = const {},
  bool own = true,
}) => {
  'exito': true,
  'asistenciaId': '${userId}_$day',
  'day': day,
  'data': record,
  'supportsRecording':
      own &&
      profile['activo'] != false &&
      attendanceRecordingRoles.contains(profile['rol']),
  'supportsManual':
      own &&
      profile['activo'] != false &&
      attendanceRecordingRoles.contains(profile['rol']) &&
      profile['asistenciaManualPermitida'] == true,
  'requiresLocation': profile['asistenciaManualPermitida'] != true,
  'supportsPauses': true,
  'cached': cached,
  'pendingSync': pending,
  'receiptRevision': '${record['revision'] ?? 0}',
  'legacyPending': legacy.isNotEmpty,
  'legacyPendingData': legacy,
};

/// Firestore delivers cached hours immediately. Writes remain authenticated
/// callable operations; old device-only receipts are displayed separately.
Stream<Map<String, dynamic>> watchNativeAttendance(
  String userId, {
  String? day,
  required Stream<void> refreshes,
  FirebaseFirestore? firestore,
  FirebaseAuth? auth,
}) {
  final identity = auth ?? FirebaseAuth.instance,
      db = firestore ?? FirebaseFirestore.instance;
  final uid = identity.currentUser?.uid;
  if (uid == null)
    return Stream.error(StateError('Inicia sesión para consultar tu jornada.'));
  if (userId != uid)
    return Stream.error(
      StateError('Consulta otra jornada mediante el servicio autorizado.'),
    );
  if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(userId) ||
      day != null && !RegExp(r'^\d{8}$').hasMatch(day))
    return Stream.error(StateError('Revisa la jornada solicitada.'));
  String today() {
    final d = DateTime.now().toUtc().subtract(const Duration(hours: 6));
    return '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  }

  var selected = day ?? today(),
      generation = 0,
      cancelled = false,
      cached = true,
      pending = false;
  Map<String, dynamic>? profile, record;
  Map<String, dynamic> legacy = {};
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? journalSub,
      profileSub;
  StreamSubscription<User?>? authSub;
  StreamSubscription<void>? changeSub;
  Timer? rollover;
  late StreamController<Map<String, dynamic>> controller;
  bool valid() =>
      !cancelled && !controller.isClosed && identity.currentUser?.uid == uid;
  void fail(Object error) {
    if (valid()) controller.addError(error);
  }

  void emit() {
    if (valid() && profile != null && record != null)
      controller.add(
        nativeAttendanceReceipt(
          userId: userId,
          day: selected,
          profile: profile!,
          record: record!,
          cached: cached,
          pending: pending,
          legacy: legacy,
          own: userId == uid,
        ),
      );
  }

  Future<void> readLegacy(int ticket) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('sauna.attendance.pending.$userId.$selected');
      final decoded = raw == null ? null : jsonDecode(raw);
      if (valid() && ticket == generation) {
        legacy = decoded is Map ? Map<String, dynamic>.from(decoded) : {};
        emit();
      }
    } catch (_) {
      /* Never delete or silently confirm a legacy receipt. */
    }
  }

  void bind() {
    generation++;
    final ticket = generation;
    record = null;
    legacy = {};
    journalSub?.cancel();
    journalSub = db
        .collection('asistencias')
        .doc('${userId}_$selected')
        .snapshots(includeMetadataChanges: true)
        .listen((s) {
          if (!valid() || ticket != generation) return;
          record = s.data() ?? {};
          cached = s.metadata.isFromCache;
          pending = s.metadata.hasPendingWrites;
          emit();
        }, onError: fail);
    unawaited(readLegacy(ticket));
  }

  Future<void> refresh() async {
    if (!valid()) return;
    if (day == null && selected != today()) {
      selected = today();
      bind();
      return;
    }
    final ticket = generation;
    try {
      final s = await db
          .collection('asistencias')
          .doc('${userId}_$selected')
          .get(const GetOptions(source: Source.server));
      if (valid() && ticket == generation) {
        record = s.data() ?? {};
        cached = false;
        pending = s.metadata.hasPendingWrites;
        emit();
      }
    } catch (e) {
      fail(e);
    }
  }

  controller = StreamController<Map<String, dynamic>>(
    onListen: () {
      authSub = identity.authStateChanges().listen((user) {
        if (user?.uid != uid && !cancelled) {
          controller.addError(StateError('La sesión cambió.'));
          journalSub?.cancel();
          profileSub?.cancel();
        }
      });
      profileSub = db.collection('usuarios').doc(userId).snapshots().listen((
        s,
      ) {
        if (!valid()) return;
        if (!s.exists || s.data()?['activo'] == false) {
          profile = null;
          fail(StateError('La cuenta no está activa.'));
          return;
        }
        profile = s.data();
        emit();
      }, onError: fail);
      bind();
      changeSub = refreshes.listen((_) => unawaited(refresh()));
      rollover = Timer.periodic(const Duration(minutes: 1), (_) {
        if (day == null && selected != today()) {
          selected = today();
          bind();
        }
      });
    },
    onCancel: () async {
      cancelled = true;
      generation++;
      rollover?.cancel();
      await journalSub?.cancel();
      await profileSub?.cancel();
      await authSub?.cancel();
      await changeSub?.cancel();
    },
  );
  return controller.stream;
}
