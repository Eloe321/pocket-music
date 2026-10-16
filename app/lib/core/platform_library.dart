import 'package:flutter/services.dart';
import 'models.dart';
import 'ports.dart';

class PlatformLibrary implements LibraryPort {
  PlatformLibrary({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('pocket_music/library');
  final MethodChannel _channel;
  @override
  Future<LibraryResult> scan({required bool requestPermission}) async {
    final result = await _channel.invokeMapMethod<String, dynamic>('scan', {
      'requestPermission': requestPermission,
    });
    return LibraryResult(
      songs: _songs(result?['songs']),
      permissionDenied: result?['permissionDenied'] == true,
    );
  }

  @override
  Future<List<Song>> importFiles() async {
    try {
      return _songs(await _channel.invokeMethod<dynamic>('importFiles'));
    } on PlatformException catch (error) {
      if (error.code != 'partial_import') rethrow;
      final details = error.details;
      if (details is! Map) rethrow;
      final count = details['failedCount'];
      throw PartialImportException(
        songs: _songs(details['songs']),
        failedCount: count is num && count > 0 ? count.toInt() : 1,
      );
    }
  }

  @override
  Future<void> openSettings() async =>
      _channel.invokeMethod<void>('openSettings');

  static List<Song> _songs(dynamic input) {
    final result = <Song>[];
    for (final raw in input is List ? input : const []) {
      if (raw is! Map || raw['id'] == null || raw['path'] is! String) continue;
      if (!isLocalMediaPath(raw['path'] as String)) continue;
      try {
        result.add(Song.fromJson(Map<String, dynamic>.from(raw)));
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    return result;
  }
}

bool isLocalMediaPath(String path) {
  if (path.isEmpty) return false;
  final uri = Uri.tryParse(path);
  return uri != null &&
      (uri.scheme.isEmpty || uri.scheme == 'file' || uri.scheme == 'content');
}
