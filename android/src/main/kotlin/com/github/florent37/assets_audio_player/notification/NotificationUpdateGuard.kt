package com.github.florent37.assets_audio_player.notification

/** A decoded cover belongs only to the notification update that requested it. */
internal class NotificationUpdateGuard {
    private var revision = 0L
    fun next(): Long = ++revision
    fun isCurrent(revision: Long): Boolean = revision == this.revision
    fun invalidate() { revision++ }
}
