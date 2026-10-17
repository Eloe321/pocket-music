package com.github.florent37.assets_audio_player.notification

import android.support.v4.media.session.PlaybackStateCompat
import org.junit.Assert.assertTrue
import org.junit.Test

class NotificationPlaybackActionsTest {
    @Test fun sessionAdvertisesAllHeadphoneTransportCommands() {
        val actions = NotificationPlaybackActions.flags
        assertTrue(actions and PlaybackStateCompat.ACTION_PLAY != 0L)
        assertTrue(actions and PlaybackStateCompat.ACTION_PAUSE != 0L)
        assertTrue(actions and PlaybackStateCompat.ACTION_PLAY_PAUSE != 0L)
        assertTrue(actions and PlaybackStateCompat.ACTION_SKIP_TO_NEXT != 0L)
        assertTrue(actions and PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS != 0L)
    }
}
