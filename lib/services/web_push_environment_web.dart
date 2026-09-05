// Browser-only compatibility checks; no asynchronous work before the permission gesture.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js;

String? pushEnvironmentProblem() {
  final nav = html.window.navigator;
  final ua = nav.userAgent;
  final touch = js.hasProperty(nav, 'maxTouchPoints')
      ? js.getProperty<num>(nav, 'maxTouchPoints') : 0;
  final ios = RegExp(r'iPad|iPhone|iPod').hasMatch(ua) ||
      (ua.contains('Macintosh') && touch > 1);
  final standalone = html.window.matchMedia('(display-mode: standalone)').matches ||
      (js.hasProperty(nav, 'standalone') && js.getProperty<Object?>(nav, 'standalone') == true);
  if (ios && !standalone) {
    return 'En iPhone: abre esta dirección en Safari, toca Compartir → Añadir a pantalla de inicio. Abre Sauna Stilo desde ese icono y pulsa Activar avisos.';
  }
  if (html.window.location.protocol != 'https:' && html.window.location.hostname != 'localhost') {
    return 'Los avisos necesitan la dirección HTTPS de la aplicación.';
  }
  if (!js.hasProperty(html.window, 'Notification') ||
      !js.hasProperty(nav, 'serviceWorker') ||
      !js.hasProperty(html.window, 'PushManager')) {
    return 'Este navegador no admite avisos push. Actualiza el navegador o usa la aplicación instalada en un dispositivo compatible.';
  }
  return null;
}
