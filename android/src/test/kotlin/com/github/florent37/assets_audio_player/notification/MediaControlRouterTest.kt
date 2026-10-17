package com.github.florent37.assets_audio_player.notification

import android.view.KeyEvent
import org.junit.Assert.assertEquals
import org.junit.Test

class MediaControlRouterTest {
    @Test fun headsetAndPhoneMediaKeysMapToPlaybackActions() {
        assertEquals(MediaControlRouter.Action.TOGGLE,
            MediaControlRouter.actionForKeyCode(KeyEvent.KEYCODE_HEADSETHOOK))
        assertEquals(MediaControlRouter.Action.TOGGLE,
            MediaControlRouter.actionForKeyCode(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
        assertEquals(MediaControlRouter.Action.NEXT,
            MediaControlRouter.actionForKeyCode(KeyEvent.KEYCODE_MEDIA_NEXT))
        assertEquals(MediaControlRouter.Action.PREVIOUS,
            MediaControlRouter.actionForKeyCode(KeyEvent.KEYCODE_MEDIA_PREVIOUS))
        assertEquals(MediaControlRouter.Action.PAUSE,
            MediaControlRouter.actionForKeyCode(KeyEvent.KEYCODE_MEDIA_PAUSE))
    }

    @Test fun explicitPauseDoesNotResumeAnAlreadyPausedPlayer() {
        val commands = mutableListOf<String>()
        MediaControlRouter.dispatch(
            MediaControlRouter.Action.PAUSE,
            isPlaying = false,
            toggle = { commands.add("toggle") },
            next = { commands.add("next") },
            previous = { commands.add("previous") },
            stop = { commands.add("stop") },
        )
        assertEquals(emptyList<String>(), commands)
    }

    @Test fun explicitPlayDoesNotPauseAnAlreadyPlayingPlayer() {
        val commands = mutableListOf<String>()
        MediaControlRouter.dispatch(
            MediaControlRouter.Action.PLAY,
            isPlaying = true,
            toggle = { commands.add("toggle") },
            next = { commands.add("next") },
            previous = { commands.add("previous") },
            stop = { commands.add("stop") },
        )
        assertEquals(emptyList<String>(), commands)
    }

    @Test fun mediaCommandsReachTheirSpecificHandlers() {
        val commands = mutableListOf<String>()
        for (action in listOf(
            MediaControlRouter.Action.TOGGLE,
            MediaControlRouter.Action.NEXT,
            MediaControlRouter.Action.PREVIOUS,
        )) {
            MediaControlRouter.dispatch(
                action,
                isPlaying = true,
                toggle = { commands.add("toggle") },
                next = { commands.add("next") },
                previous = { commands.add("previous") },
                stop = { commands.add("stop") },
            )
        }
        assertEquals(listOf("toggle", "next", "previous"), commands)
    }
}
