package com.github.florent37.assets_audio_player.notification

import org.junit.Assert.*
import org.junit.Test

class NotificationUpdateGuardTest {
    @Test fun slowCoverCannotRestorePreviousTrack() {
        val guard = NotificationUpdateGuard()
        val firstTrack = guard.next()
        val secondTrack = guard.next()
        assertFalse(guard.isCurrent(firstTrack))
        assertTrue(guard.isCurrent(secondTrack))
    }

    @Test fun slowPausedCoverCannotDemoteResumedPlayback() {
        val guard = NotificationUpdateGuard()
        guard.next()
        val paused = guard.next()
        val resumed = guard.next()
        assertFalse(guard.isCurrent(paused))
        assertTrue(guard.isCurrent(resumed))
    }

    @Test fun lateCoverCannotResurrectHiddenOrDestroyedNotification() {
        val guard = NotificationUpdateGuard()
        val playing = guard.next()
        guard.invalidate()
        assertFalse(guard.isCurrent(playing))
    }
}
