package com.github.florent37.assets_audio_player

import org.junit.Assert.*
import org.junit.Test

class PlaybackPositionTickerTest {
    private val pending = mutableSetOf<Runnable>()
    private var updates = 0
    private val ticker = PlaybackPositionTicker(
        post = { runnable, _ -> pending.add(runnable); Unit },
        cancel = { pending.remove(it); Unit },
        update = { updates++ },
    )

    @Test fun repeatedPlayCreatesExactlyOnePollingChain() {
        repeat(100) { ticker.start() }
        assertEquals(1, pending.size)
        tick()
        assertEquals(1, updates)
        assertEquals(1, pending.size)
    }

    @Test fun longPlaybackAndPauseResumeDoNotAccumulatePollers() {
        ticker.start()
        repeat(7200) {
            tick()
            assertEquals(1, pending.size)
        }
        repeat(100) {
            ticker.stop()
            assertTrue(pending.isEmpty())
            ticker.start()
            tick()
            assertEquals(1, pending.size)
        }
        ticker.stop()
        assertTrue(pending.isEmpty())
    }

    @Test fun backendBufferingDoesNotStopThePollingChain() {
        ticker.start()
        repeat(10) { tick() }
        assertEquals(10, updates)
        assertEquals(1, pending.size)
    }

    private fun tick() {
        val next = pending.first()
        pending.remove(next)
        next.run()
    }
}
