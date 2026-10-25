package com.github.florent37.assets_audio_player.notification

import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import com.github.florent37.assets_audio_player.AssetsAudioPlayerPlugin

class NotificationManager(private val context: Context) {

    var closed = false

    fun showNotification(playerId: String, audioMetas: AudioMetas, isPlaying: Boolean, notificationSettings: NotificationSettings, stop: Boolean, durationMs: Long) {
        try {
            if (closed)
                return
            if (stop) {
                stopNotification()
            } else {
                val intent = Intent(context, NotificationService::class.java).apply {
                    putExtra(NotificationService.EXTRA_NOTIFICATION_ACTION, NotificationAction.Show(
                            isPlaying = isPlaying,
                            audioMetas = audioMetas,
                            playerId = playerId,
                            notificationSettings = notificationSettings,
                            durationMs = durationMs
                    ))
                }
                if (isPlaying && Build.VERSION.SDK_INT >= 26) {
                    ContextCompat.startForegroundService(context, intent)
                } else {
                    context.startService(intent)
                }
            }
            AssetsAudioPlayerPlugin.instance?.assetsAudioPlayer?.registerLastPlayerWithNotif(playerId)
        } catch (t: Throwable) {
            t.printStackTrace()
            // A startForegroundService rejection is synchronous here; no
            // onStartCommand will arrive to repair the claimed playing state.
            if (isPlaying) {
                AssetsAudioPlayerPlugin.instance?.assetsAudioPlayer?.getPlayer(playerId)?.let {
                    if (it.isPlaybackActive) it.pause()
                }
            }
        }
    }

    fun stopNotification() {
        try {
            context.startService(Intent(context, NotificationService::class.java).apply {
                putExtra(NotificationService.EXTRA_NOTIFICATION_ACTION, NotificationAction.Hide(
                ))
            })
        } catch (t: Throwable) {
            t.printStackTrace()
        }
    }

    fun hideNotificationService(definitively: Boolean = false) {
        try {
            //if remainingNotif == 0, stop
            context.stopService(Intent(context, NotificationService::class.java))
            closed = definitively
        } catch (t: Throwable) {
            t.printStackTrace()
        }
    }
}
