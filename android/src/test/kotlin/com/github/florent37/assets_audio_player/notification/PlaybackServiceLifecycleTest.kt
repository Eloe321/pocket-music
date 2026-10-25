package com.github.florent37.assets_audio_player.notification

import org.junit.Assert.assertEquals
import org.junit.Test

class PlaybackServiceLifecycleTest {
    @Test fun pausedMetadataDoesNotAttemptBackgroundForegroundPromotion() {
        val effects = mutableListOf<String>()
        val foreground = PlaybackServiceLifecycle.publishNotification(false, false,
            { effects.add("promote") }, { effects.add("notify") }, { effects.add("demote") })
        assertEquals(listOf("notify"), effects)
        assertEquals(false, foreground)
    }

    @Test fun ongoingPlaybackUpdatesDoNotRestartForegroundService() {
        val effects = mutableListOf<String>()
        val foreground = PlaybackServiceLifecycle.publishNotification(true, true,
            { effects.add("promote") }, { effects.add("notify") }, { effects.add("demote") })
        assertEquals(listOf("notify"), effects)
        assertEquals(true, foreground)
    }

    @Test fun pauseThenResumeChangesForegroundOnlyOncePerTransition() {
        val effects = mutableListOf<String>()
        var foreground = PlaybackServiceLifecycle.publishNotification(true, false,
            { effects.add("promote") }, { effects.add("notify") }, { effects.add("demote") })
        foreground = PlaybackServiceLifecycle.publishNotification(false, foreground,
            { effects.add("promote") }, { effects.add("notify") }, { effects.add("demote") })
        PlaybackServiceLifecycle.publishNotification(true, foreground,
            { effects.add("promote") }, { effects.add("notify") }, { effects.add("demote") })
        assertEquals(listOf("promote", "notify", "demote", "promote"), effects)
    }

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
