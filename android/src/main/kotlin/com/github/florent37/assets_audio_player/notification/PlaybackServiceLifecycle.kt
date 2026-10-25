package com.github.florent37.assets_audio_player.notification

object PlaybackServiceLifecycle {
    fun publishNotification(
        isPlaying: Boolean,
        isForeground: Boolean,
        promote: () -> Unit,
        notify: () -> Unit,
        demote: () -> Unit,
    ): Boolean {
        if (isPlaying && !isForeground) {
            promote()
            return true
        }
        notify()
        if (!isPlaying && isForeground) {
            demote()
            return false
        }
        return isForeground
    }

    fun onTaskRemoved(isPlaying: Boolean, stopService: () -> Unit) {
        if (!isPlaying) stopService()
    }
}
