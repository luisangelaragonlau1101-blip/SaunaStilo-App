import 'package:flutter_test/flutter_test.dart';
import 'package:saunastilo/presentation/appearance.dart';
import 'package:saunastilo/workflow/company_structure.dart';

void main() {
  test('original Home palette remains the default and wine is optional', () {
    expect(AppearanceController.instance.palette.id, 'stilo');
    expect(stiloPalettes.first.id, 'stilo');
    expect(stiloPalettes.singleWhere((p) => p.id == 'vino').light, isFalse);
    expect(stiloTheme(stiloPalettes.first).colorScheme.primary.toARGB32(), 0xFFB7FF2A);
  });
  test('company catalog covers factory, office and internship assignments', () {
    expect(companyDepartments, containsAll(['Producción', 'Almacén', 'Logística y Envíos', 'Recursos Humanos']));
    expect(companyPositions, contains('Practicante'));
    expect(internshipCareers, containsAll(['Arquitectura', 'Ingeniería industrial', 'Administración']));
  });
}
