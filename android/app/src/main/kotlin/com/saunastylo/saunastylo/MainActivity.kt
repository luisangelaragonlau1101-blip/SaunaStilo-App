package com.saunastylo.saunastylo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val soundUri = Settings.System.DEFAULT_NOTIFICATION_URI
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()
            val channel = NotificationChannel(
                "sauna_alertas",
                "Alertas Sauna Stilo",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Tareas, solicitudes de almacén y avisos importantes"
                enableVibration(true)
                setSound(soundUri, audioAttributes)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }
}
