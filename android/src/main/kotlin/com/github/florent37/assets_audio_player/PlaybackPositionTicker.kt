package com.github.florent37.assets_audio_player

/** One polling chain for a playing backend, including time spent buffering. */
internal class PlaybackPositionTicker(
    private val post: (Runnable, Long) -> Unit,
    private val cancel: (Runnable) -> Unit,
    private val update: () -> Unit,
) {
    private var running = false
    private val tick = object : Runnable {
        override fun run() {
            if (!running) return
            update()
            if (running) post(this, 1000L)
        }
    }

    fun start() {
        running = true
        cancel(tick)
        post(tick, 0L)
    }

    fun stop() {
        running = false
        cancel(tick)
    }
}
