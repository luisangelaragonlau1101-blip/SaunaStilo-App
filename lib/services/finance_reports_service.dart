import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;

class FinanceReports {
  static List<Map<String, dynamic>> statementRows(String source) {
    final rows = const CsvToListConverter(shouldParseNumbers: false, eol: '\n').convert(source.replaceAll('\r\n', '\n').replaceFirst('\uFEFF', ''));
    if (rows.length < 2) throw StateError('El CSV debe incluir encabezados fecha, referencia e importe.');
    final header = rows.first.map((v) => v.toString().trim().toLowerCase()).toList();
    final dateIndex = header.indexOf('fecha'), refIndex = header.indexOf('referencia'), amountIndex = header.indexOf('importe');
    if ([dateIndex, refIndex, amountIndex].any((i) => i < 0)) throw StateError('Usa las columnas fecha, referencia, importe. Fecha: AAAA-MM-DD; importe con signo y punto decimal.');
    return rows.skip(1).where((r) => r.any((c) => c.toString().trim().isNotEmpty)).map((r) {
      if (r.length != header.length) throw StateError('Un renglón del CSV tiene columnas incompletas.');
      final input = r[amountIndex].toString().trim();
      if (!RegExp(r'^-?\d{1,9}(\.\d{1,2})?$').hasMatch(input)) throw StateError('Usa importes como 3450.50 o -250.00, sin separadores de miles.');
      final negative = input.startsWith('-'), parts = input.replaceFirst('-', '').split('.');
      final amount = (int.parse(parts[0]) * 100 + (parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0)) * (negative ? -1 : 1);
      final day = r[dateIndex].toString().trim();
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day) || DateTime.tryParse(day) == null || DateTime.parse(day).toIso8601String().substring(0, 10) != day) throw StateError('Revisa las fechas del CSV: AAAA-MM-DD.');
      return <String, dynamic>{'fecha': '${day}T12:00:00.000Z', 'referencia': r[refIndex].toString().trim(), 'centavos': amount};
    }).toList();
  }

  static Future<void> exportCsv(String month, List<Map<String, dynamic>> movements) async {
    final csv = const ListToCsvConverter().convert([
      ['fecha', 'tipo', 'subtipo', 'concepto', 'importe_MXN', 'cuenta', 'proyecto', 'categoria', 'factura', 'autor', 'id'],
      ...movements.map((m) => [m['fecha'], m['tipo'], m['subtipo'] ?? '', m['concepto'], ((m['centavos'] as num? ?? 0) / 100).toStringAsFixed(2), m['cuentaId'] ?? 'historico_sin_cuenta', m['proyectoId'] ?? '', m['categoria'] ?? '', m['facturaEstado'] ?? 'sin_clasificar', m['creadoPor'] ?? '', m['id']]),
    ]);
    // Escape formulas in untrusted text before opening in a spreadsheet.
    final rows = const CsvToListConverter(shouldParseNumbers: false).convert(csv).map((r) => r.map((v) { final s = v.toString(); return RegExp(r'^[=+@\t\r-]').hasMatch(s) ? "'$s" : s; }).toList()).toList();
    await FilePicker.saveFile(dialogTitle: 'Guardar reporte para Contabilidad', fileName: 'STILO-movimientos-$month.csv', type: FileType.custom, allowedExtensions: ['csv'], bytes: Uint8List.fromList(utf8.encode('\uFEFF${const ListToCsvConverter().convert(rows)}')));
  }

  static Future<void> exportPdf(String month, List<Map<String, dynamic>> movements, Map<String, dynamic> summary, {List<Map<String, dynamic>> profitability = const []}) async {
    String money(dynamic v) => '\$${((v as num? ?? 0) / 100).toStringAsFixed(2)} MXN';
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(build: (_) => [
      pw.Text('SAUNA STILO - Control empresarial', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.Text('Periodo: $month'), pw.SizedBox(height: 12),
      pw.Text('Ingresos: ${money(summary['ingresos'])} | Egresos: ${money(summary['egresos'])}'),
      pw.Text('Saldo registrado: ${money(summary['saldoRegistrado'])}. No representa saldo bancario sin conciliacion.'),
      pw.Text('IVA estimado por pagar: ${money(summary['ivaEstimadoPorPagar'])}. Requiere revision de Contabilidad.'),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(headers: ['Fecha', 'Tipo', 'Concepto', 'Importe'], data: movements.map((m) => [m['fecha'].toString().split('T').first, m['tipo'], m['concepto'], money(m['centavos'])]).toList(), cellStyle: const pw.TextStyle(fontSize: 8)),
      if (profitability.isNotEmpty) ...[
        pw.SizedBox(height: 20), pw.Text('Rentabilidad estimada por proyecto'),
        pw.TableHelper.fromTextArray(headers: ['Proyecto', 'Precio', 'Costo registrado', 'Pendiente/estimado', 'Margen estimado'], data: profitability.map((p) => [p['titulo'], p['precioVentaCentavos'] == null ? 'Sin configurar' : money(p['precioVentaCentavos']), money(p['costoRegistrado']), money((p['costosPendientes'] as num? ?? 0) + (p['costosEstimados'] as num? ?? 0)), p['margenEstimado'] == null ? 'Sin configurar' : money(p['margenEstimado'])]).toList(), cellStyle: const pw.TextStyle(fontSize: 8)),
      ],
    ]));
    await FilePicker.saveFile(dialogTitle: 'Guardar reporte financiero', fileName: 'STILO-reporte-$month.pdf', type: FileType.custom, allowedExtensions: ['pdf'], bytes: await doc.save());
  }

}
