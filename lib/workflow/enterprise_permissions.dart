import '../models/user_model.dart';

/// Convenience for navigation; all mutations are checked again by Firebase.
class EnterprisePermissions {
  static const keys = <String>[
    'finanzas', 'autorizarCompras', 'solicitarCompras',
    'instalaciones', 'coordinarInstalaciones', 'direccion',
  ];
  static bool has(UserModel user, String key) => user.activo &&
      (user.rol == AppRoles.admin || user.permisosEmpresa.contains(key));
  static bool canFinance(UserModel user) => user.activo &&
      ([AppRoles.admin, AppRoles.finanzas, AppRoles.contabilidad].contains(user.rol) || has(user, 'finanzas'));
  static bool canViewFinance(UserModel user) => canFinance(user) || has(user, 'direccion');
  static bool canApprovePurchases(UserModel user) => canFinance(user) || has(user, 'autorizarCompras');
  static bool canRequestPurchase(UserModel user) => canFinance(user) || has(user, 'solicitarCompras');
  static bool canManageInstallations(UserModel user) => has(user, 'instalaciones');
  static bool canCoordinateInstallations(UserModel user) => user.activo &&
      ([AppRoles.admin, AppRoles.maestro, AppRoles.almacenista].contains(user.rol) ||
       has(user, 'instalaciones') || has(user, 'coordinarInstalaciones'));
}
