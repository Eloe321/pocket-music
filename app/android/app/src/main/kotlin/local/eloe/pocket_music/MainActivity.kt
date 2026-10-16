package local.eloe.pocket_music

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private var pendingScan: MethodChannel.Result? = null
    private var pendingImport: MethodChannel.Result? = null
    private val library by lazy { MusicLibrary(applicationContext) }
    private val audioPermission: String get() = if (Build.VERSION.SDK_INT >= 33)
        Manifest.permission.READ_MEDIA_AUDIO else Manifest.permission.READ_EXTERNAL_STORAGE

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pocket_music/library")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scan" -> {
                        val allowed = checkSelfPermission(audioPermission) == PackageManager.PERMISSION_GRANTED
                        if (!allowed && call.argument<Boolean>("requestPermission") == true) {
                            if (pendingScan != null) result.error("busy", "An audio permission request is already open.", null)
                            else {
                                pendingScan = result
                                requestPermissions(arrayOf(audioPermission), 410)
                            }
                        } else scan(result, allowed)
                    }
                    "importFiles" -> {
                        if (pendingImport != null) result.error("busy", "The file picker is already open.", null)
                        else {
                            pendingImport = result
                            val picker = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "audio/*"
                                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                            }
                            try { startActivityForResult(picker, 411) }
                            catch (e: Exception) {
                                pendingImport = null
                                result.error("picker", "No audio file picker is available.", null)
                            }
                        }
                    }
                    "openSettings" -> {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun scan(result: MethodChannel.Result, allowed: Boolean) {
        worker.execute {
            try {
                val songs = library.scan(allowed)
                runOnUiThread { result.success(mapOf("songs" to songs, "permissionDenied" to !allowed)) }
            } catch (e: SecurityException) {
                runOnUiThread { result.success(mapOf("songs" to library.importedSongs(), "permissionDenied" to true)) }
            } catch (e: Exception) {
                runOnUiThread { result.error("scan", "Your music could not be read. Try refreshing the library.", null) }
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 410) {
            val result = pendingScan ?: return
            pendingScan = null
            scan(result, grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        }
    }

    @Deprecated("Legacy activity result API is supported by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 411) return
        val result = pendingImport ?: return
        pendingImport = null
        if (resultCode != Activity.RESULT_OK || data == null) { result.success(emptyList<Any>()); return }
        val uris = data.clipData?.let { clip -> (0 until clip.itemCount).map { clip.getItemAt(it).uri } }
            ?: listOfNotNull(data.data)
        worker.execute {
            try {
                val songs = mutableListOf<Map<String, Any?>>()
                var failures = 0
                for (uri in uris.distinct()) {
                    try { songs.add(library.importAudio(uri)) }
                    catch (_: Exception) { failures++ }
                }
                runOnUiThread {
                    if (failures == 0) result.success(songs)
                    else result.error("partial_import", "Some files could not be imported.",
                        mapOf("songs" to songs, "failedCount" to failures))
                }
            } catch (e: Exception) {
                runOnUiThread { result.error("import", "Some files could not be imported. Refresh the library to see any completed imports.", null) }
            }
        }
    }

    override fun onDestroy() {
        pendingScan?.error("cancelled", "The permission request was closed.", null)
        pendingImport?.error("cancelled", "The file picker was closed.", null)
        pendingScan = null
        pendingImport = null
        worker.shutdown()
        super.onDestroy()
    }
}
