import 'models.dart';

class LibraryResult {
  const LibraryResult({required this.songs, this.permissionDenied = false});
  final List<Song> songs;
  final bool permissionDenied;
}

/// Some selected files failed while the others were copied successfully.
class PartialImportException implements Exception {
  PartialImportException({required List<Song> songs, required this.failedCount})
    : songs = List.unmodifiable(songs);
  final List<Song> songs;
  final int failedCount;
}

abstract class LibraryPort {
  Future<LibraryResult> scan({required bool requestPermission});
  Future<List<Song>> importFiles();
  Future<void> openSettings();
}

class PlaybackEvent {
  const PlaybackEvent({
    this.position,
    this.duration,
    this.isPlaying,
    this.completed = false,
    this.error,
  });
  final Duration? position, duration;
  final bool? isPlaying;
  final bool completed;
  final String? error;
}

abstract class PlaybackPort {
  Stream<PlaybackEvent> get changes;
  Future<void> open(
    Song song, {
    required bool autoStart,
    required Duration position,
  });
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

abstract class StateStore {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> value);
}

/// Optional notification controls; the app owns queue order and repeat behavior.
abstract class RemotePlaybackPort {
  void bindRemoteControls({
    Future<void> Function()? play,
    Future<void> Function()? pause,
    required Future<void> Function() next,
    required Future<void> Function() previous,
    required Future<void> Function() toggle,
    required Future<void> Function() stop,
  });
}
