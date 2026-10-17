package com.github.florent37.assets_audio_player.notification

import org.junit.Assert.assertEquals
import org.junit.Test

class PlaybackServiceLifecycleTest {
    @Test fun removingAppFromRecentsKeepsOngoingPlayback() {
        var stops = 0
        PlaybackServiceLifecycle.onTaskRemoved(isPlaying = true) { stops++ }
        assertEquals(0, stops)
    }

    @Test fun removingPausedAppFromRecentsCanStopService() {
        var stops = 0
        PlaybackServiceLifecycle.onTaskRemoved(isPlaying = false) { stops++ }
        assertEquals(1, stops)
    }
}
