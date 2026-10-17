package local.eloe.pocket_music

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/** Playback and its Dart queue must outlive the screen that displays them. */
class PocketMusicApplication : Application() {
    private var playbackEngine: FlutterEngine? = null

    @Synchronized
    fun getPlaybackEngine(): FlutterEngine {
        return playbackEngine ?: FlutterEngine(this).also { playbackEngine = it }
    }

    fun startPlaybackEngine() {
        val engine = getPlaybackEngine()
        if (!engine.dartExecutor.isExecutingDart) {
            engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        }
    }
}
