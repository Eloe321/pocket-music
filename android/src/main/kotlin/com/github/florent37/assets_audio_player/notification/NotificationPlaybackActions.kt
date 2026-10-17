package com.github.florent37.assets_audio_player.notification

import android.support.v4.media.session.PlaybackStateCompat

object NotificationPlaybackActions {
    val flags: Long = PlaybackStateCompat.ACTION_PLAY or
        PlaybackStateCompat.ACTION_PAUSE or
        PlaybackStateCompat.ACTION_PLAY_PAUSE or
        PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
        PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
        PlaybackStateCompat.ACTION_SEEK_TO
}
