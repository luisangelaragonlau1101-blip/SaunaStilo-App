package com.saunastylo.saunastylo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sauna_stilo/security")
            .setMethodCallHandler { call, result ->
                if (call.method != "setSecure") { result.notImplemented() }
                else {
                    val secure = call.arguments as? Boolean
                    if (secure == null) { result.error("invalid", "Boolean required", null) }
                    else {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE) // Required for every Sauna Stilo route.
                        result.success(null)
                    }
                }
            }
    }

    override fun onResume() {
        super.onResume()
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE) // Secure until authenticated policy is loaded.
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationSound = Settings.System.DEFAULT_NOTIFICATION_URI
            val notificationAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()
            val alertsChannel = NotificationChannel(
                "sauna_alertas",
                "Alertas Sauna Stilo",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Tareas, solicitudes de almacén y avisos importantes"
                enableVibration(true)
                setSound(notificationSound, notificationAttributes)
            }

            val alarmSound = Settings.System.DEFAULT_ALARM_ALERT_URI
            val alarmAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .build()
            val urgentChannel = NotificationChannel(
                "sauna_alarmas_urgentes",
                "Alarmas urgentes Sauna Stilo",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Llamados urgentes enviados por administración"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 800, 250, 800, 250, 1200)
                setSound(alarmSound, alarmAttributes)
                setBypassDnd(false)
            }

            getSystemService(NotificationManager::class.java).apply {
                createNotificationChannel(alertsChannel)
                createNotificationChannel(urgentChannel)
            }
        }
    }
}
