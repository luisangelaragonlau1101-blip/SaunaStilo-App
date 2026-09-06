import 'dart:js_interop';
@JS('navigator.userAgent') external String get _userAgent;
@JS('navigator.maxTouchPoints') external int? get _maxTouchPoints;
@JS('navigator.standalone') external bool? get _iosStandalone;
@JS('window.matchMedia') external _MediaQueryList _matchMedia(String query);
@JS('window.location.protocol') external String get _protocol;
@JS('window.location.hostname') external String get _hostname;
@JS('window.Notification') external JSAny? get _notification;
@JS('navigator.serviceWorker') external JSAny? get _serviceWorker;
@JS('window.PushManager') external JSAny? get _pushManager;
extension type _MediaQueryList(JSObject _) implements JSObject { external bool get matches; }
String? pushEnvironmentProblem() {
  final ua=_userAgent;
  final ios=RegExp(r'iPad|iPhone|iPod').hasMatch(ua)||(ua.contains('Macintosh')&&(_maxTouchPoints??0)>1);
  if(ios&&!(_matchMedia('(display-mode: standalone)').matches||_iosStandalone==true)) return 'En iPhone: abre esta dirección en Safari, toca Compartir → Añadir a pantalla de inicio. Abre Sauna Stilo desde ese icono y pulsa Activar avisos.';
  if(_protocol!='https:'&&_hostname!='localhost'&&_hostname!='127.0.0.1') return 'Los avisos necesitan la dirección HTTPS de la aplicación.';
  if(_notification==null||_serviceWorker==null||_pushManager==null) return 'Este navegador no admite avisos push. Actualiza el navegador o usa la aplicación instalada en un dispositivo compatible.';
  return null;
}
