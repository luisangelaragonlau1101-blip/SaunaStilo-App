import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/enterprise_finance_service.dart';

String financeMoney(dynamic cents) => cents == null
    ? 'Sin configurar'
    : NumberFormat.currency(
        locale: 'es_MX',
        symbol: '\$',
      ).format((cents as num) / 100);
List<Map<String, dynamic>> financeRows(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];
Map<String, dynamic> financeMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
int financeCents(dynamic input, {bool zero = true, bool signed = false}) {
  final s = (input ?? '').toString().trim();
  if (s.isEmpty && zero) return 0;
  if (!RegExp(
    signed ? r'^-?\d{1,9}(\.\d{1,2})?$' : r'^\d{1,9}(\.\d{1,2})?$',
  ).hasMatch(s))
    throw StateError(
      'Revisa los importes: sin separadores de miles y con máximo dos decimales.',
    );
  final parts = s.replaceFirst('-', '').split('.');
  final value =
      (int.parse(parts[0]) * 100 +
          (parts.length > 1 ? int.parse(parts[1].padRight(2, '0')) : 0)) *
      (s.startsWith('-') ? -1 : 1);
  if (!zero && value <= 0)
    throw StateError('El importe debe ser mayor que cero.');
  return value;
}

class FinanceField {
  const FinanceField(
    this.key,
    this.label, {
    this.initial = '',
    this.options,
    this.money = false,
    this.toggle = false,
    this.lines = 1,
  });
  final String key, label;
  final dynamic initial;
  final Map<String, String>? options;
  final bool money, toggle;
  final int lines;
}

Future<bool?> showFinanceForm(
  BuildContext context, {
  required String title,
  required List<FinanceField> fields,
  required Future<void> Function(Map<String, dynamic>, String) save,
  String? help,
  String saveLabel = 'Guardar',
}) async {
  final controls = {
    for (final f in fields.where((f) => !f.toggle && f.options == null))
      f.key: TextEditingController(text: f.initial.toString()),
  };
  final values = {
    for (final f in fields) f.key: f.toggle ? f.initial == true : f.initial,
  };
  final operation = EnterpriseFinanceService.operationId();
  var busy = false;
  String? error;
  try {
    final route = DialogRoute<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(
        builder: (c, update) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (help != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(help),
                      ),
                    for (final f in fields)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: f.toggle
                            ? SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(f.label),
                                value: values[f.key] == true,
                                onChanged: busy
                                    ? null
                                    : (v) => update(() => values[f.key] = v),
                              )
                            : f.options != null
                            ? DropdownButtonFormField<String>(
                                initialValue: values[f.key]?.toString(),
                                isExpanded: true,
                                decoration: InputDecoration(labelText: f.label),
                                items: f.options!.entries
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e.key,
                                        child: Text(
                                          e.value,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: busy
                                    ? null
                                    : (v) => update(() => values[f.key] = v),
                              )
                            : TextField(
                                controller: controls[f.key],
                                enabled: !busy,
                                minLines: 1,
                                maxLines: f.lines,
                                keyboardType: f.money
                                    ? const TextInputType.numberWithOptions(
                                        decimal: true,
                                        signed: true,
                                      )
                                    : TextInputType.text,
                                decoration: InputDecoration(
                                  labelText: f.label,
                                  prefixText: f.money ? '\$ ' : null,
                                ),
                              ),
                      ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(color: Theme.of(c).colorScheme.error),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialog, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        update(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          await save({
                            ...values,
                            for (final e in controls.entries)
                              e.key: e.value.text.trim(),
                          }, operation);
                          if (dialog.mounted) Navigator.pop(dialog, true);
                        } catch (e) {
                          if (c.mounted)
                            update(() {
                              busy = false;
                              error = EnterpriseFinanceService.message(e);
                            });
                        }
                      },
                child: Text(busy ? 'Guardando…' : saveLabel),
              ),
            ],
          ),
        ),
      ),
    );
    final result = await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
    return result;
  } finally {
    for (final c in controls.values) {
      c.dispose();
    }
  }
}

Widget financeMetric(
  BuildContext context,
  String title,
  dynamic cents, {
  String? subtitle,
  IconData icon = Icons.account_balance_wallet_outlined,
}) => Card(
  child: Padding(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          financeMoney(cents),
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
        ),
        if (subtitle != null)
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  ),
);
