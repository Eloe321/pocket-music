package com.github.florent37.assets_audio_player.notification

object PlaybackServiceLifecycle {
    fun onTaskRemoved(isPlaying: Boolean, stopService: () -> Unit) {
        if (!isPlaying) stopService()
    }
}
