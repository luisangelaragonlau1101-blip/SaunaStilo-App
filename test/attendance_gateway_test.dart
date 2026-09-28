import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/services/asistencia_service.dart';
import 'package:saunastilo/services/attendance_gateway_service.dart';
import 'package:saunastilo/services/company_learning_service.dart';
import 'package:saunastilo/widgets/jornada_compacta.dart';

class AttendanceApiFake extends CompanyLearningService {
  final data = <String, dynamic>{};
  final calls = <String>[];
  bool fail = false;
  @override
  Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> body = const {}]) async {
    calls.add(action);
    if (action == 'attendance-record') {
      if (fail) throw StateError('No se confirmó el guardado.');
      final field = {'entrada': 'horaEntrada', 'solicitar_comida': 'salidaComidaSolicitada', 'regreso_comida': 'regresoComidaReal', 'salida': 'horaSalida'}[body['movement']]!;
      data[field] = '2026-09-28T15:00:00Z';
    }
    return {'day': '20260928', 'asistenciaId': 'worker_20260928', 'data': {...data}, 'exito': true, 'pendingSync': true};
  }
}
class AttendanceServiceFake extends AsistenciaService {
  AttendanceServiceFake(AttendanceApiFake api) : super(gateway: AttendanceGatewayService(api: api));
  @override Future<Map<String, dynamic>> registrarMovimiento(String action) => gateway.record(action, latitude: 19.26247565075755, longitude: -98.89430986717343);
}
final person = UserModel(id: 'worker', nombre: 'Persona de prueba', correo: 'test@example.invalid', rol: 'trabajador', fechaRegistro: DateTime(2026));

void main() {
  testWidgets('four controls reflect saved state, approval, reload and confirmed exit on mobile', (t) async {
    t.view.physicalSize = const Size(375, 900); t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
    final api = AttendanceApiFake(); final service = AttendanceServiceFake(api); var exits = 0;
    Widget app() => MaterialApp(theme: ThemeData.dark(), home: Scaffold(body: SingleChildScrollView(child: JornadaCompacta(usuario: person, service: service, showDetails: false, onExitConfirmed: () => exits++))));
    await t.pumpWidget(app()); await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('attendance-entry'))); await t.pumpAndSettle();
    expect(find.text('Entrada 09:00'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('attendance-meal'))); await t.pumpAndSettle();
    expect(find.textContaining('Espera la autorización'), findsOneWidget);
    expect(find.byKey(const ValueKey('attendance-return')), findsNothing);
    api.data['salidaComidaReal'] = '2026-09-28T20:00:00Z';
    AttendanceGatewayService.refresh(); await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('attendance-return'))); await t.pumpAndSettle();
    expect(find.text('Regreso de comida registrado'), findsOneWidget);
    await t.pumpWidget(const SizedBox()); await t.pumpAndSettle();
    await t.pumpWidget(app()); await t.pumpAndSettle();
    expect(find.text('Entrada 09:00'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('attendance-exit'))); await t.pumpAndSettle();
    expect(exits, 0);
    await t.tap(find.text('Confirmar salida')); await t.pumpAndSettle();
    expect(exits, 1); expect(find.text('FINALIZADA'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox()); await t.pumpAndSettle();
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
