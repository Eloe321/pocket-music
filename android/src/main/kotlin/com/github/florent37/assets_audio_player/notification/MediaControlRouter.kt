package com.github.florent37.assets_audio_player.notification

import android.view.KeyEvent

/** Keep explicit play/pause idempotent when an accessory sends a delayed key. */
object MediaControlRouter {
    enum class Action { PLAY, PAUSE, TOGGLE, NEXT, PREVIOUS, STOP }

    fun actionForKeyCode(keyCode: Int): Action? = when (keyCode) {
        KeyEvent.KEYCODE_MEDIA_PLAY -> Action.PLAY
        KeyEvent.KEYCODE_MEDIA_PAUSE -> Action.PAUSE
        KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
        KeyEvent.KEYCODE_HEADSETHOOK -> Action.TOGGLE
        KeyEvent.KEYCODE_MEDIA_NEXT,
        KeyEvent.KEYCODE_MEDIA_SKIP_FORWARD -> Action.NEXT
        KeyEvent.KEYCODE_MEDIA_PREVIOUS,
        KeyEvent.KEYCODE_MEDIA_SKIP_BACKWARD -> Action.PREVIOUS
        KeyEvent.KEYCODE_MEDIA_STOP -> Action.STOP
        else -> null
    }

    fun dispatch(
        action: Action,
        isPlaying: Boolean,
        toggle: () -> Unit,
        next: () -> Unit,
        previous: () -> Unit,
        stop: () -> Unit,
    ) {
        when (action) {
            Action.PLAY -> if (!isPlaying) toggle()
            Action.PAUSE -> if (isPlaying) toggle()
            Action.TOGGLE -> toggle()
            Action.NEXT -> next()
            Action.PREVIOUS -> previous()
            Action.STOP -> stop()
        }
    }
}
