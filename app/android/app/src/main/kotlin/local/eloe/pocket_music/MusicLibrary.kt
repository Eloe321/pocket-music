package local.eloe.pocket_music

import android.content.ContentUris
import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.MediaStore
import android.provider.OpenableColumns
import java.io.File
import java.security.MessageDigest

/** Reads device audio without moving originals. Imports are private application copies. */
class MusicLibrary(private val context: Context) {
    private val imports = File(context.filesDir, "music").apply { mkdirs() }
    private val artwork = File(context.cacheDir, "covers").apply { mkdirs() }

    fun scan(includeDevice: Boolean): List<Map<String, Any?>> {
        val songs = mutableListOf<Map<String, Any?>>()
        if (includeDevice) {
            val columns = arrayOf(MediaStore.Audio.Media._ID, MediaStore.Audio.Media.TITLE,
                MediaStore.Audio.Media.ARTIST, MediaStore.Audio.Media.ALBUM,
                MediaStore.Audio.Media.DURATION, MediaStore.Audio.Media.ALBUM_ID)
            context.contentResolver.query(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, columns,
                "${MediaStore.Audio.Media.DURATION} > 0", null, "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC")?.use { cursor ->
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(0)
                    val uri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
                    val albumId = cursor.getLong(5)
                    songs.add(mapOf("id" to "media:$id", "path" to uri.toString(),
                        "title" to clean(cursor.getString(1), "Untitled"),
                        "artist" to clean(cursor.getString(2), "Unknown artist"),
                        "album" to clean(cursor.getString(3), "Unknown album"),
                        "durationMs" to cursor.getLong(4), "artworkPath" to albumCover(albumId)))
                }
            }
        }
        songs.addAll(importedSongs())
        return songs.distinctBy { it["id"] }.sortedBy { (it["title"] as String).lowercase() }
    }

    private fun albumCover(albumId: Long): String? {
        val file = File(artwork, "album-$albumId.jpg")
        if (file.exists()) return file.path
        // Album artwork is optional. A failed provider lookup must never hide a song.
        return try {
            val uri = ContentUris.withAppendedId(Uri.parse("content://media/external/audio/albumart"), albumId)
            context.contentResolver.openInputStream(uri)?.use { input -> file.outputStream().use { input.copyTo(it) } }
            if (file.length() > 0) file.path else null
        } catch (_: Exception) { file.delete(); null }
    }

    fun importedSongs(): List<Map<String, Any?>> = imports.listFiles()?.filter {
        it.isFile && !it.name.endsWith(".partial")
    }?.mapNotNull { file -> try { metadata(file) } catch (_: Exception) { null } } ?: emptyList()

    fun importAudio(uri: Uri): Map<String, Any?> {
        var name = "Audio.mp3"
        context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) name = it.getString(0) ?: name
        }
        name = name.substringAfterLast('/').replace(Regex("[^\\p{L}\\p{N} ._()-]"), "_").take(160)
        val digest = MessageDigest.getInstance("SHA-256").digest(uri.toString().toByteArray())
            .take(12).joinToString("") { "%02x".format(it.toInt() and 255) }
        val destination = File(imports, "$digest-$name")
        if (!destination.exists()) {
            val partial = File(imports, "${destination.name}.partial")
            try {
                context.contentResolver.openInputStream(uri)?.use { input ->
                    partial.outputStream().use { output -> input.copyTo(output) }
                } ?: throw IllegalArgumentException("Unreadable file")
                // Validate before accepting the private copy; never delete the original.
                metadata(partial)
                check(partial.renameTo(destination)) { "Could not finish import" }
            } finally { partial.delete() }
        }
        return metadata(destination)
    }

    private fun metadata(file: File): Map<String, Any?> {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(file.path)
            val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0
            require(duration > 0) { "Not a playable audio file" }
            val cover = File(artwork, "import-${file.name.substringBefore('-')}.jpg")
            if (!cover.exists()) retriever.embeddedPicture?.let { cover.writeBytes(it) }
            val fallback = file.name.substringAfter('-').substringBeforeLast('.')
            return mapOf("id" to "import:${file.name}", "path" to file.path,
                "title" to clean(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE), fallback),
                "artist" to clean(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST), "Unknown artist"),
                "album" to clean(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM), "Imported music"),
                "durationMs" to duration, "artworkPath" to cover.takeIf { it.exists() }?.path)
        } finally { retriever.release() }
    }

    private fun clean(value: String?, fallback: String) = value?.trim()?.takeIf {
        it.isNotEmpty() && it != "<unknown>"
    } ?: fallback
}
