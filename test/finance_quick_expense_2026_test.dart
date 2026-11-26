import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/services/enterprise_finance_service.dart';
import 'package:saunastilo/widgets/finance_entry_sheet.dart';

class ExpenseApi extends EnterpriseFinanceService {
  final calls = <Map<String, dynamic>>[];
  final first = Completer<Map<String, dynamic>>();
  int uploads = 0;
  @override
  Future<Map<String, dynamic>> upload({
    required Uint8List bytes,
    required String name,
    required String operation,
  }) async {
    expect(bytes, isNotEmpty);
    uploads++;
    return {
      'path': 'finance/worker/$operation/ticket.png',
      'name': name,
      'contentType': 'image/png',
    };
  }

  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    calls.add({'action': action, ...data});
    return calls.length == 1 ? first.future : {'id': 'expense'};
  }
}

void main() {
  testWidgets(
    'expense with captured ticket requests its invoice and a network retry reuses the same upload and operation',
    (t) async {
      final api = ExpenseApi();
      const camera = MethodChannel('plugins.flutter.io/image_picker');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(camera, (call) async {
            expect(call.method, 'pickImage');
            return File('assets/logo_saunastilo.png').absolute.path;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(camera, null),
      );
      bool? saved;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () async => saved = await showFinanceEntry(
                  c,
                  service: api,
                  financial: false,
                ),
                child: const Text('Nuevo gasto'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Nuevo gasto'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('finance-amount')), '3450');
      await t.runAsync(() async {
        await t.tap(find.text('Fotografiar ticket'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await t.pumpAndSettle();
      expect(find.text('logo_saunastilo.png'), findsOneWidget);
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('finance-save')),
        250,
        scrollable: find
            .descendant(
              of: find.byType(FinanceEntrySheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.tap(find.byKey(const ValueKey('finance-save')));
      await t.pump();
      expect(api.calls, hasLength(1));
      expect(api.calls.single['centavos'], 345000);
      expect(api.calls.single['facturaOpcion'], 'necesito');
      expect(api.calls.single['action'], 'recordMovement');
      expect(api.calls.single['archivos'], hasLength(1));
      expect(
        t
            .widget<FilledButton>(find.byKey(const ValueKey('finance-save')))
            .onPressed,
        isNull,
      );
      api.first.completeError(StateError('Conexión interrumpida'));
      await t.pumpAndSettle();
      expect(saved, isNull);
      await t.tap(find.byKey(const ValueKey('finance-save')));
      await t.pumpAndSettle();
      expect(saved, isTrue);
      expect(api.uploads, 1);
      expect(api.calls[1]['operationId'], api.calls[0]['operationId']);
      expect(api.calls[1]['archivos'], api.calls[0]['archivos']);
      expect(t.takeException(), isNull);
    },
  );
}
