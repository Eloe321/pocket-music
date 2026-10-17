package com.github.florent37.assets_audio_player.notification

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.support.v4.media.session.MediaControllerCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS
import android.support.v4.media.session.PlaybackStateCompat
import android.view.KeyEvent

class MediaButtonsReceiver(context: Context, private val onAction: (MediaControlRouter.Action) -> Unit, private val onNotifSeek: (Long) -> Unit) {

    companion object {
        var instance: MediaButtonsReceiver? = null


        private var mediaSessionCompat : MediaSessionCompat? = null
        fun getMediaSessionCompat(context: Context) : MediaSessionCompat {
            if(mediaSessionCompat == null) {
                mediaSessionCompat = MediaSessionCompat(context, "MediaButtonsReceiver", null, null).apply {
                    setFlags(FLAG_HANDLES_MEDIA_BUTTONS)
                    isActive = true
                }
            }
            return mediaSessionCompat!!
        }

        fun actionFromIntent(intent: Intent?): MediaControlRouter.Action? {
            if (intent?.action != Intent.ACTION_MEDIA_BUTTON) return null
            val event = intent.getParcelableExtra<KeyEvent>(Intent.EXTRA_KEY_EVENT) ?: return null
            if (event.action != KeyEvent.ACTION_DOWN || event.repeatCount != 0) return null
            return MediaControlRouter.actionForKeyCode(event.keyCode)
        }
    }

    init {
        instance = this
    }

    private val mediaSessionCallback = object : MediaSessionCompat.Callback() {
        override fun onPlay() { onAction(MediaControlRouter.Action.PLAY) }
        override fun onPause() { onAction(MediaControlRouter.Action.PAUSE) }
        override fun onSkipToNext() { onAction(MediaControlRouter.Action.NEXT) }
        override fun onSkipToPrevious() { onAction(MediaControlRouter.Action.PREVIOUS) }
        override fun onStop() { onAction(MediaControlRouter.Action.STOP) }
        override fun onMediaButtonEvent(mediaButtonEvent: Intent?): Boolean {
            val action = actionFromIntent(mediaButtonEvent) ?: return super.onMediaButtonEvent(mediaButtonEvent)
            onAction(action)
            // We already routed this key. Calling super would dispatch it again
            // through onPlay/onPause/onSkipToNext and double-toggle playback.
            return true
        }

        override fun onSeekTo(pos: Long) {
            super.onSeekTo(pos)
            seekPlayerTo(pos)
        }
    }

    init {
        getMediaSessionCompat(context).setCallback(mediaSessionCallback)
    }

    fun onIntentReceive(intent: Intent?) {
        actionFromIntent(intent)?.let(onAction)
    }

    private fun seekPlayerTo(pos: Long) {
        this.onNotifSeek(pos)
    }

}
