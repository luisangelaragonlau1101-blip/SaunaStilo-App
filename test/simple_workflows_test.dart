import 'package:saunastilo/services/attendance_history_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/models/user_model.dart';
import 'package:saunastilo/services/inventario_service.dart';
import 'package:saunastilo/services/inventory_photo_codec.dart';
import 'package:saunastilo/services/asistencia_service.dart';
import 'package:saunastilo/services/attendance_gateway_service.dart';
import 'package:saunastilo/services/company_learning_service.dart';
import 'package:saunastilo/services/recorded_streak.dart';
import 'package:saunastilo/widgets/inventory_photo.dart';
import 'package:saunastilo/widgets/home_shortcuts.dart';
import 'package:saunastilo/widgets/jornada_compacta.dart';

UserModel person(String role) => UserModel(id: 'qa', nombre: 'Prueba', correo: 'qa@example.invalid', rol: role, fechaRegistro: DateTime(2026));
class ManualApi extends CompanyLearningService {
  final bool supported;
  final data = <String,dynamic>{};
  final movements = <String>[];
  ManualApi({this.supported = true});
  @override Future<Map<String,dynamic>> call(String action, [Map<String,dynamic> body = const {}]) async {
    if (action == 'attendance-record') {
      expect(body['manual'], true);
      expect(body.containsKey('latitud'), false);
      movements.add(body['movement'] as String);
      data[{'entrada':'horaEntrada','salida_comida':'salidaComidaReal','regreso_comida':'regresoComidaReal','salida':'horaSalida'}[body['movement']]!] = '2026-09-28T21:00:00Z';
    }
    return {'supportsManual':supported,'day':'20260928','data':{...data},'exito':true};
  }
}

void main() {
  test('recent receipts never replace administrative amounts or restore a corrected time', () {
    final ledger = <String,dynamic>{'horaEntrada': null, 'listaBonos': [{'monto': 250}], 'observacionesAdmin': 'Revisado', 'movimientosServidor': {'horaEntrada': 'original'}};
    final recent = <String,dynamic>{'horaEntrada': 'old', 'horaSalida': 'new', 'listaBonos': [{'monto': 100}], 'observacionesAdmin': 'Anterior', 'movimientosServidor': {'horaEntrada': 'original', 'horaSalida': 'pending'}};
    final merged = AttendanceHistoryService.mergeReceipt(ledger, recent);
    expect(merged['horaEntrada'], isNull);
    expect(merged['horaSalida'], 'new');
    expect(merged['listaBonos'], [{'monto': 250}]);
    expect(merged['observacionesAdmin'], 'Revisado');
    expect(ledger.containsKey('horaSalida'), false);
  });

  testWidgets('product photo persists in the product JSON and renders after reopening without Storage', (t) async {
    late String saved;
    await t.runAsync(() async {
      saved = await InventarioService().subirImagenInsumoBytes(await File('assets/logo_saunastilo.png').readAsBytes(), 'Producto QA');
    });
    expect(InventoryPhotoCodec.decode(saved)!.length, lessThanOrEqualTo(InventoryPhotoCodec.maxBytes));
    final reopened = jsonDecode(jsonEncode({'imagen_url':saved})) as Map;
    await t.pumpWidget(MaterialApp(home: InventoryPhoto(imageUrl: reopened['imagen_url'] as String)));
    await t.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('all profiles have the same five visible home shortcuts', (t) async {
    for (final role in ['admin','maestro','almacenista','trabajador']) {
      var selected = -1;
      await t.pumpWidget(MaterialApp(home: Scaffold(body: MainHomeShortcuts(user: person(role), onTab: (i) => selected = i))));
      for (final label in ['Comunidad','Mensajes','Tareas','Almacén','Perfil']) { expect(find.text(label), findsOneWidget); }
      await t.tap(find.text('Perfil')); expect(selected, 4);
      await t.tap(find.text('Tareas')); expect(selected, 3);
    }
  });
  testWidgets('manual attendance for admin records every step without requesting geolocation', (t) async {
    final api = ManualApi();
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: JornadaCompacta(usuario: person('admin'), showDetails: false, service: AsistenciaService(gateway: AttendanceGatewayService(api: api)))))));
    await t.pumpAndSettle();
    for (final key in ['attendance-entry','attendance-meal','attendance-return','attendance-exit']) {
      await t.ensureVisible(find.byKey(ValueKey(key))); await t.tap(find.byKey(ValueKey(key))); await t.pumpAndSettle();
    }
    await t.tap(find.text('Confirmar salida')); await t.pumpAndSettle();
    expect(api.movements, ['entrada','salida_comida','regreso_comida','salida']);
    expect(find.text('FINALIZADA'), findsOneWidget);
    await t.pumpWidget(const SizedBox()); await t.pumpAndSettle();
  });
  testWidgets('pending backend release never presents admin manual clock-in as available', (t) async {
    final api = ManualApi(supported: false);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: JornadaCompacta(usuario: person('admin'), showDetails: false, service: AsistenciaService(gateway: AttendanceGatewayService(api: api))))));
    await t.pumpAndSettle();
    expect(find.textContaining('pendiente de la actualización'), findsOneWidget);
    expect(t.widget<FilledButton>(find.byKey(const ValueKey('attendance-entry'))).onPressed, isNull);
    expect(api.movements, isEmpty);
    await t.pumpWidget(const SizedBox()); await t.pumpAndSettle();
  });
  test('both actual justification statuses preserve a recorded streak', () {
    final result = RecordedStreak.from([AttendancePoint(DateTime(2026,9,1),'a_tiempo'), AttendancePoint(DateTime(2026,9,2),'justificado'), AttendancePoint(DateTime(2026,9,3),'justificada'), AttendancePoint(DateTime(2026,9,4),'a_tiempo')]);
    expect(result.current, 2);
  });
}
