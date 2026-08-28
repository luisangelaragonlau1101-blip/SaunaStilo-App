import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
      await _messaging.setAutoInitEnabled(true);
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

      await _saveToken(user: user, token: token);
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
        (newToken) => _saveToken(user: user, token: newToken),
      );

      return const PushActivationResult(
        active: true,
        message: 'Notificaciones activadas con sonido, insignias y avisos en segundo plano.',
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
    await _firestore.collection('usuarios').doc(user.id).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'pushActualizadoEn': FieldValue.serverTimestamp(),
      'pushPlataforma': kIsWeb
          ? 'web'
          : defaultTargetPlatform.name.toLowerCase(),
    });
  }

  Future<void> deactivateFor(String userId) async {
    try {
      String? token;
      token = await _messaging.getToken(
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
