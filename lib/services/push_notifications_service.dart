import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'web_push_environment_stub.dart' if (dart.library.html) 'web_push_environment_web.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';

class PushActivationResult {
  final bool active;
  final String message;

  const PushActivationResult({required this.active, required this.message});
}

class PushNotificationsService {
  static const String _webVapidKey = String.fromEnvironment(
    'FCM_VAPID_KEY',
    defaultValue:
        'BG-mPJ0heLV8V0-65XbnbgEidZCeOIUdwHfJhirnHvqq4Nl8LFM3DUvKT9EmiQO2ZYB1Gs9srh8M9xV2b_D9TRY',
  );

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  StreamSubscription<String>? _tokenRefreshSubscription;

  PushNotificationsService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  Future<NotificationSettings> currentSettings() {
    return _messaging.getNotificationSettings();
  }

  Future<PushActivationResult> activateFor(UserModel user) async {
    try {
      final problem = pushEnvironmentProblem();
      if (problem != null) return PushActivationResult(active: false, message: problem);
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final authorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!authorized) {
        return const PushActivationResult(
          active: false,
          message: 'Autoriza las notificaciones en la configuración del dispositivo.',
        );
      }

      await _messaging.setAutoInitEnabled(true);
      final token = await _messaging.getToken(
        vapidKey: kIsWeb && _webVapidKey.isNotEmpty ? _webVapidKey : null,
        serviceWorkerScriptPath: kIsWeb
            ? Uri.base.resolve('firebase-messaging-sw.js').path
            : null,
      );
      if (token == null || token.isEmpty) {
        return const PushActivationResult(
          active: false,
          message: 'El dispositivo todavía no entregó un identificador push.',
        );
      }

      await _saveToken(user: user, token: token).timeout(const Duration(seconds: 15));
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
        (newToken) async {
          try { await _saveToken(user: user, token: newToken); }
          catch (_) { debugPrint('[push] Reintentar registro al volver a la app.'); }
        },
      );

      // Foreground audio is handled once by AvisosSonoros from the saved notice.

      return const PushActivationResult(
        active: true,
        message: 'Dispositivo registrado. Las alertas generales usan prioridad alta. Con la app abierta se reproduce la alarma urgente; en segundo plano el sonido depende de los permisos y ajustes del teléfono.',
      );
    } catch (error) {
      debugPrint('[push] No se pudo activar FCM: $error');
      return PushActivationResult(
        active: false,
        message: kIsWeb
            ? 'El navegador no entregó el permiso push. Abre la app desde su URL segura, permite notificaciones y vuelve a intentar.'
            : 'No se pudieron activar las notificaciones. Revisa el permiso del sistema e intenta nuevamente.',
      );
    }
  }

  Future<void> _saveToken({
    required UserModel user,
    required String token,
  }) async {
    if (FirebaseAuth.instance.currentUser?.uid != user.id) return;
    await _firestore.collection('usuarios').doc(user.id).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'pushActualizadoEn': FieldValue.serverTimestamp(),
      'pushPlataforma': kIsWeb
          ? 'web'
          : defaultTargetPlatform.name.toLowerCase(),
    });
  }

  Future<void> deactivateFor(String userId) async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    try {
      final settings = await currentSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) return;
      final token = await _messaging.getToken(
        vapidKey: kIsWeb && _webVapidKey.isNotEmpty ? _webVapidKey : null,
        serviceWorkerScriptPath: kIsWeb
            ? Uri.base.resolve('firebase-messaging-sw.js').path
            : null,
      );
      if (token != null && token.isNotEmpty) {
        await _firestore.collection('usuarios').doc(userId).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
      await _messaging.deleteToken();
    } catch (error) {
      debugPrint('[push] No se pudo retirar el token al cerrar sesión: $error');
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
  }
}
