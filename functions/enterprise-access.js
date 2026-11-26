'use strict';

// The profile is always loaded by the server; client role/permission claims
// are never accepted as authorization inputs.
const PERMISSIONS = Object.freeze([
  'finanzas', 'autorizarCompras', 'solicitarCompras',
  'instalaciones', 'coordinarInstalaciones', 'direccion',
]);
function active(profile) { return !!profile && profile.activo !== false; }
function hasPermission(profile, key) {
  return active(profile) && (profile.rol === 'admin' ||
    (Array.isArray(profile.permisosEmpresa) && profile.permisosEmpresa.includes(key)));
}
function canFinance(profile) {
  return active(profile) && (['admin', 'finanzas', 'contabilidad'].includes(profile.rol) || hasPermission(profile, 'finanzas'));
}
function canViewFinance(profile) { return canFinance(profile) || hasPermission(profile, 'direccion'); }
function canApprovePurchases(profile) { return canFinance(profile) || hasPermission(profile, 'autorizarCompras'); }
function canRequestPurchase(profile) { return canFinance(profile) || hasPermission(profile, 'solicitarCompras'); }
function canManageInstallations(profile) { return hasPermission(profile, 'instalaciones'); }
function canCoordinateInstallations(profile) {
  return active(profile) && (['admin', 'maestro', 'almacenista'].includes(profile.rol) ||
    hasPermission(profile, 'instalaciones') || hasPermission(profile, 'coordinarInstalaciones'));
}
async function requireProfile(db, uid, HttpsError) {
  if (typeof uid !== 'string' || !uid || uid.length > 128 || uid.includes('/')) {
    throw new HttpsError('unauthenticated', 'Inicia sesión en STILO.');
  }
  const snapshot = await db.collection('usuarios').doc(uid).get();
  const profile = snapshot.exists ? snapshot.data() : null;
  if (!active(profile)) throw new HttpsError('permission-denied', 'Tu cuenta no está activa.');
  return {...profile, id:uid, uid};
}
module.exports = {PERMISSIONS, active, hasPermission, canFinance, canViewFinance,
  canApprovePurchases, canRequestPurchase, canManageInstallations,
  canCoordinateInstallations, requireProfile};
