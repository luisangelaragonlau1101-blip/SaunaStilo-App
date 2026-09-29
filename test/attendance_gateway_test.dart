import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/services/asistencia_service.dart';
import 'package:saunastilo/services/attendance_gateway_service.dart';
import 'package:saunastilo/services/company_learning_service.dart';
import 'package:saunastilo/widgets/jornada_compacta.dart';
import 'package:saunastilo/models/asistencia_model.dart';
import 'package:saunastilo/services/attendance_history_service.dart';

class AttendanceApiFake extends CompanyLearningService {
  final data = <String, dynamic>{};
  final calls = <String>[];
  final pauseRequests = <Map<String, dynamic>>[];
  bool fail = false;
  int revision = 0;
  @override
  Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> body = const {}]) async {
    calls.add(action);
    if (action == 'attendance-record') {
      if (fail) throw StateError('No se confirmó el guardado.');
      expect(body['manual'], true);
      expect(body.containsKey('latitud'), false);
      final field = {'entrada': 'horaEntrada', 'salida_comida': 'salidaComidaReal', 'regreso_comida': 'regresoComidaReal', 'salida': 'horaSalida'}[body['movement']]!;
      data[field] = '2026-09-28T15:00:00Z';
      revision++;
    }
    if (action == 'attendance-pause') {
      pauseRequests.add({...body});
      if (fail) throw StateError('No se confirmó el guardado.');
      final pauses = List<Map<String, dynamic>>.from(data['pausasJornada'] as List? ?? []);
      if (body['direction'] == 'out') {
        pauses.add({'id': 'pause-${pauses.length}', 'tipo': body['kind'], 'descripcion': body['detail'], 'salida': '2026-09-28T17:00:00Z', 'regreso': null});
      } else {
        final index = pauses.indexWhere((p) => p['id'] == body['pauseId']);
        pauses[index] = {...pauses[index], 'regreso': '2026-09-28T17:08:00Z', 'regresoId': 'return'};
      }
      data['pausasJornada'] = pauses;
      revision++;
    }
    return {'supportsManual': true, 'supportsPauses': true, 'receiptRevision': '$revision', 'day': '20260928', 'asistenciaId': 'worker_20260928', 'data': {...data}, 'exito': true, 'pendingSync': true};
  }
}
class AttendanceServiceFake extends AsistenciaService {
  AttendanceServiceFake(AttendanceApiFake api) : super(gateway: AttendanceGatewayService(api: api));
}
final person = UserModel(id: 'worker', nombre: 'Persona de prueba', correo: 'test@example.invalid', rol: 'trabajador', fechaRegistro: DateTime(2026));

void main() {
  testWidgets('four manual controls reflect saved state, meal return, reload and confirmed exit on mobile', (t) async {
    t.view.physicalSize = const Size(375, 900); t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    final api = AttendanceApiFake(); final service = AttendanceServiceFake(api); var exits = 0;
    Widget app() => MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: SingleChildScrollView(child: JornadaCompacta(usuario: person, service: service, showDetails: false, onExitConfirmed: () => exits++))));
    await t.pumpWidget(app()); await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('attendance-entry'))); await t.pumpAndSettle();
    expect(find.text('Entrada 09:00'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('attendance-meal'))); await t.pumpAndSettle();
    expect(find.textContaining('Espera la autorización'), findsNothing);
    expect(find.byKey(const ValueKey('attendance-return')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('attendance-return'))); await t.pumpAndSettle();
    expect(find.text('Regreso de comida registrado'), findsOneWidget);
    await t.pumpWidget(const SizedBox()); await t.pumpAndSettle();
    await t.pumpWidget(app()); await t.pumpAndSettle();
    expect(find.text('Entrada 09:00'), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('attendance-exit'))); await t.tap(find.byKey(const ValueKey('attendance-exit'))); await t.pumpAndSettle();
    expect(exits, 0);
    await t.tap(find.text('Confirmar salida')); await t.pumpAndSettle();
    expect(exits, 1); expect(find.text('FINALIZADA'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox()); await t.pumpAndSettle();
  });

  testWidgets('bathroom pause, reason validation and return persist separately after reopening on mobile', (t) async {
    t.view.physicalSize = const Size(375, 900); t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    final api = AttendanceApiFake(); final service = AttendanceServiceFake(api); var exits = 0;
    Widget app() => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: JornadaCompacta(usuario: person, service: service, showDetails: false, onExitConfirmed: () => exits++))));
    await t.pumpWidget(app()); await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('attendance-entry'))); await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const ValueKey('attendance-pause-out')));
    await t.tap(find.byKey(const ValueKey('attendance-pause-out'))); await t.pumpAndSettle();
    await t.tap(find.text('Otro motivo')); await t.pumpAndSettle();
    await t.tap(find.text('Guardar salida')); await t.pumpAndSettle();
    expect(find.text('Escribe el motivo.'), findsOneWidget); expect(api.pauseRequests, isEmpty);
    await t.tap(find.text('Baño')); await t.pumpAndSettle();
    await t.tap(find.text('Guardar salida')); await t.pumpAndSettle();
    expect(find.text('En pausa: Baño'), findsOneWidget);
    expect(api.data['horaEntrada'], '2026-09-28T15:00:00Z');
    expect(api.data['horaSalida'], isNull); expect(api.data['salidaComidaReal'], isNull); expect(exits, 0);
    await t.pumpWidget(const SizedBox()); await t.pumpAndSettle();
    await t.pumpWidget(app()); await t.pumpAndSettle();
    expect(find.text('En pausa: Baño'), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('attendance-pause-return')));
    await t.tap(find.byKey(const ValueKey('attendance-pause-return'))); await t.pumpAndSettle();
    expect(find.textContaining('8 min'), findsOneWidget); expect(exits, 0);
    expect(api.data['horaSalida'], isNull); expect(api.data['regresoComidaReal'], isNull);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox()); await t.pumpAndSettle();
  });

  testWidgets('a failed pause remains unsaved and retry retains its request identity', (t) async {
    final api = AttendanceApiFake()..data['horaEntrada'] = '2026-09-28T15:00:00Z';
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: JornadaCompacta(usuario: person, service: AttendanceServiceFake(api), showDetails: false)))));
    await t.pumpAndSettle(); api.fail = true;
    for (var attempt = 0; attempt < 2; attempt++) {
      await t.ensureVisible(find.byKey(const ValueKey('attendance-pause-out')));
      await t.tap(find.byKey(const ValueKey('attendance-pause-out'))); await t.pumpAndSettle();
      await t.tap(find.text('Guardar salida')); await t.pumpAndSettle();
      if (attempt == 0) { expect(api.data['pausasJornada'], isNull); expect(find.text('No se confirmó el guardado.'), findsOneWidget); api.fail = false; }
    }
    expect(api.pauseRequests.length, 2);
    expect(api.pauseRequests[0]['requestId'], api.pauseRequests[1]['requestId']);
    expect((api.data['pausasJornada'] as List).length, 1);
    await t.pumpWidget(const SizedBox()); await t.pumpAndSettle();
  });

  test('payroll history includes new pause returns while preserving reviewed primary hours and amounts', () {
    final ledger = <String,dynamic>{'horaEntrada':null, 'movimientosServidor':{'horaEntrada':'reviewed'}, 'listaBonos':[{'monto':200}], 'pausasJornada':[{'id':'pause','tipo':'bano','salida':'2026-09-28T17:00:00Z','regreso':null}]};
    final receipt = <String,dynamic>{'horaEntrada':'old','movimientosServidor':{'horaEntrada':'reviewed'},'pausasJornada':[{'id':'pause','tipo':'bano','salida':'2026-09-28T17:00:00Z','regreso':'2026-09-28T17:08:00Z','regresoId':'saved'}]};
    final merged = AttendanceHistoryService.mergeReceipt(ledger, receipt);
    expect(merged['horaEntrada'], isNull); expect(merged['listaBonos'], [{'monto':200}]);
    final model = AsistenciaModel.fromData('worker_20260928', merged);
    expect(model.pausas.single.label, 'Baño'); expect(model.pausas.single.minutes, 8);
  });

  testWidgets('a failed write never shows an entry or completes a shift', (t) async {
    final api = AttendanceApiFake()..fail = true; var exits = 0;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: JornadaCompacta(usuario: person, service: AttendanceServiceFake(api), showDetails: false, onExitConfirmed: () => exits++))));
    await t.pumpAndSettle(); await t.tap(find.byKey(const ValueKey('attendance-entry'))); await t.pumpAndSettle();
    expect(find.text('Entrada —'), findsOneWidget); expect(find.text('No se confirmó el guardado.'), findsOneWidget);
    expect(exits, 0); expect(api.data, isEmpty);
    await t.pumpWidget(const SizedBox()); await t.pumpAndSettle();
  });
}
