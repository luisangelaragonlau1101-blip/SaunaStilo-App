import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../workflow/productivity_2026.dart';

class ProductivitySnapshot {
  final WorkProductivity report;
  final bool cached;
  const ProductivitySnapshot(this.report, {this.cached = false});
}

/// Own activity metadata only. No evidence/history downloads and no team reads.
/// Queries have a date range and page cap; a cap is reported instead of silently
/// presenting an incomplete aggregate as a complete company record.
class EmployeeProductivityService {
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;
  EmployeeProductivityService({this.firestore, this.auth});
  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => auth ?? FirebaseAuth.instance;

  Future<ProductivitySnapshot> load(String uid, {DateTime? now}) async {
    if (_auth.currentUser?.uid != uid)
      throw StateError('Abre tus avances con tu cuenta.');
    final today = companyDay(now ?? DateTime.now());
    final since = today.subtract(const Duration(days: 89));
    final profile = await _db.collection('usuarios').doc(uid).get();
    if (!profile.exists || profile.data()?['activo'] == false)
      throw StateError('Tu cuenta no está activa.');
    final tasks = _db.collection('actividades');
    final month = DateTime(today.year, today.month, 1);
    Timestamp atCompanyMidnight(DateTime date) =>
        Timestamp.fromDate(DateTime.utc(date.year, date.month, date.day, 6));
    final pages = await Future.wait([
      for (final shared in [false, true]) ...[
        _read(
          (shared
                  ? tasks.where('asignadosIds', arrayContains: uid)
                  : tasks.where('asignadoATrabajadorId', isEqualTo: uid))
              .where(
                'fechaInicio',
                isGreaterThanOrEqualTo: atCompanyMidnight(since),
              )
              .orderBy('fechaInicio', descending: true),
        ),
        _read(
          (shared
                  ? tasks.where('asignadosIds', arrayContains: uid)
                  : tasks.where('asignadoATrabajadorId', isEqualTo: uid))
              .where(
                'fechaAsignada',
                isGreaterThanOrEqualTo: atCompanyMidnight(since),
              )
              .orderBy('fechaAsignada', descending: true),
        ),
        _read(
          (shared
                  ? tasks.where('asignadosIds', arrayContains: uid)
                  : tasks.where('asignadoATrabajadorId', isEqualTo: uid))
              .where(
                'aprobadoEn',
                isGreaterThanOrEqualTo: atCompanyMidnight(month),
              )
              .orderBy('aprobadoEn', descending: true),
        ),
      ],
    ]);
    if (_auth.currentUser?.uid != uid) throw StateError('Tu sesión cambió.');
    final unique = <String, WorkActivity>{};
    for (final page in pages) {
      for (final document in page.docs) {
        final data = document.data();
        dynamic date(dynamic value) =>
            value is Timestamp ? value.toDate() : value;
        unique[document.id] = WorkActivity.fromMap({
          ...data,
          'id': document.id,
          'fechaAsignada': date(data['fechaAsignada'] ?? data['fechaInicio']),
          'aprobadoEn': date(data['aprobadoEn']),
        });
      }
    }
    return ProductivitySnapshot(
      WorkProductivity.fromActivities(
        unique.values,
        today: today,
        personId: uid,
        observedSince: since,
        schedule: _schedule(profile.data()!, since, today),
        partial: pages.any((p) => p.partial),
      ),
      cached: profile.metadata.isFromCache || pages.any((p) => p.cached),
    );
  }

  Future<_ActivityPage> _read(Query<Map<String, dynamic>> query) async {
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    bool cached = false, partial = false;
    while (true) {
      final page =
          await (docs.isEmpty ? query : query.startAfterDocument(docs.last))
              .limit(200)
              .get();
      cached = cached || page.metadata.isFromCache;
      docs.addAll(page.docs);
      if (page.docs.length < 200) break;
      if (docs.length >= 2000) {
        partial = true;
        break;
      }
    }
    return _ActivityPage(docs, cached, partial);
  }

  WorkSchedule _schedule(
    Map<String, dynamic> profile,
    DateTime since,
    DateTime today,
  ) {
    final configured = profile['diasDescanso'];
    final rest = configured is List
        ? configured
              .whereType<num>()
              .map((n) => n.toInt())
              .where((n) => n >= 1 && n <= 7)
              .toSet()
        : <int>{7, if (profile['trabajaSabados'] != true) 6};
    final leave = <DateTime>{};
    for (final key in ['permisos', 'vacaciones']) {
      final entries = profile[key];
      if (entries is! List) continue;
      for (final entry in entries.whereType<Map>()) {
        if (!['aprobado', 'aprobada', 'approved'].contains(entry['estado']))
          continue;
        DateTime? day(dynamic value) {
          if (value is Timestamp) return companyDay(value.toDate());
          final parsed = DateTime.tryParse(value?.toString() ?? '');
          return parsed == null ? null : workDay(parsed);
        }

        final begin = day(entry['inicio']), end = day(entry['fin']);
        if (begin == null || end == null || end.isBefore(begin)) continue;
        final first = begin.isBefore(since) ? since : begin;
        final last = end.isAfter(today) ? today : end;
        for (
          var d = first;
          !d.isAfter(last);
          d = d.add(const Duration(days: 1))
        ) {
          leave.add(d);
        }
      }
    }
    return WorkSchedule(restWeekdays: rest, approvedLeaveDays: leave);
  }
}

class _ActivityPage {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool cached, partial;
  const _ActivityPage(this.docs, this.cached, this.partial);
}
