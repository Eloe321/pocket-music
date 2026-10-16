import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'ports.dart';
import 'platform_library.dart' show isLocalMediaPath;
export 'models.dart';
export 'ports.dart';

class MusicController extends ChangeNotifier {
  MusicController({
    required LibraryPort library,
    required PlaybackPort playback,
    required StateStore store,
    Random? random,
  }) : _library = library,
       _playback = playback,
       _store = store,
       _random = random ?? Random() {
    _subscription = _playback.changes.listen(
      _onPlaybackEvent,
      onError: (Object _) {
        _isPlaying = false;
        _error = 'This song could not be played. Try another file.';
        _notify();
      },
    );
    if (playback is RemotePlaybackPort) {
      (playback as RemotePlaybackPort).bindRemoteControls(
        next: next,
        previous: previous,
        toggle: togglePlayPause,
        stop: stop,
      );
    }
  }
  final LibraryPort _library;
  final PlaybackPort _playback;
  final StateStore _store;
  final Random _random;
  late final StreamSubscription<PlaybackEvent> _subscription;
  Future<void> _commands = SynchronousFuture<void>(null);
  List<Song> _songs = [], _queue = [];
  List<LocalPlaylist> _playlists = [];
  Set<String> _favorites = {};
  List<int> _shuffleBag = [], _history = [];
  int _currentIndex = -1, _lastPositionSave = 0, _playlistSequence = 0;
  Duration _position = Duration.zero, _actualDuration = Duration.zero;
  bool _isPlaying = false,
      _isBusy = false,
      _permissionDenied = false,
      _shuffleEnabled = false,
      _loaded = false,
      _opening = false,
      _disposed = false,
      _initialized = false;
  RepeatMode _repeatMode = RepeatMode.off;
  String _searchQuery = '';
  String? _error;

  List<Song> get songs => List.unmodifiable(_songs);
  List<Song> get filteredSongs {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return songs;
    return List.unmodifiable(
      _songs.where(
        (song) => '${song.title} ${song.artist} ${song.album}'
            .toLowerCase()
            .contains(query),
      ),
    );
  }

  List<LocalPlaylist> get playlists => List.unmodifiable(_playlists);
  Set<String> get favorites => Set.unmodifiable(_favorites);
  List<Song> get queue => List.unmodifiable(_queue);
  Song? get currentSong => _currentIndex >= 0 && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;
  int get currentIndex => _currentIndex;
  Duration get position => _position;
  Duration get duration => _actualDuration > Duration.zero
      ? _actualDuration
      : currentSong?.duration ?? Duration.zero;
  bool get isPlaying => _isPlaying;
  bool get isBusy => _isBusy;
  bool get permissionDenied => _permissionDenied;
  String? get error => _error;
  bool get shuffleEnabled => _shuffleEnabled;
  RepeatMode get repeatMode => _repeatMode;
  String get searchQuery => _searchQuery;
  Map<String, List<Song>> get albums => _groupBy((song) => song.album);
  Map<String, List<Song>> get artists => _groupBy((song) => song.artist);
  Map<String, List<Song>> _groupBy(String Function(Song) key) {
    final result = <String, List<Song>>{};
    for (final song in _songs) {
      (result[key(song)] ??= []).add(song);
    }
    return Map.unmodifiable(
      result.map((key, value) => MapEntry(key, List<Song>.unmodifiable(value))),
    );
  }

  List<Song> songsForPlaylist(String id) {
    final selected = _playlists.where((p) => p.id == id).firstOrNull;
    final byId = {for (final song in _songs) song.id: song};
    return List.unmodifiable(
      selected?.songIds.map((id) => byId[id]).whereType<Song>() ?? <Song>[],
    );
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool busy = false,
    String failure = 'The action could not be completed. Please try again.',
  }) {
    final pending = _commands.then((_) async {
      if (_disposed) return;
      if (busy) {
        _isBusy = true;
        _notify();
      }
      try {
        await action();
      } catch (_) {
        _error = failure;
      } finally {
        if (busy) _isBusy = false;
        _notify();
      }
    });
    _commands = pending;
    return pending;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() => _run(
    () async {
      if (_initialized) return;
      _initialized = true;
      Map<String, dynamic>? saved;
      try {
        saved = await _store.read();
      } catch (_) {
        _error = 'Saved library could not be read. Your audio files are safe.';
      }
      if (saved != null) {
        try {
          _songs = _decodeSongs(saved['songs']);
          _favorites = (saved['favorites'] as List? ?? [])
              .whereType<String>()
              .toSet();
          _playlists = (saved['playlists'] as List? ?? [])
              .whereType<Map>()
              .map((p) => LocalPlaylist.fromJson(Map<String, dynamic>.from(p)))
              .toList();
          _shuffleEnabled = saved['shuffle'] == true;
          _repeatMode = RepeatMode.values.firstWhere(
            (r) => r.name == saved!['repeat'],
            orElse: () => RepeatMode.off,
          );
        } catch (_) {
          _error = 'Some saved library settings could not be restored.';
        }
      }
      try {
        final result = await _library.scan(requestPermission: false);
        _permissionDenied = result.permissionDenied;
        _songs = _ordered(
          result.permissionDenied ? [..._songs, ...result.songs] : result.songs,
        );
      } catch (_) {
        _error =
            'Music could not be scanned. Try scanning again or import files.';
      }
      final byId = {for (final song in _songs) song.id: song};
      final ids = (saved?['queue'] as List? ?? []).whereType<String>().toList();
      _queue = ids.map((id) => byId[id]).whereType<Song>().toList();
      final selectedId = saved?['currentSongId'] as String?;
      final savedIndex = (saved?['currentIndex'] as num?)?.toInt();
      _currentIndex =
          savedIndex != null &&
              savedIndex >= 0 &&
              savedIndex < ids.length &&
              ids[savedIndex] == selectedId &&
              byId.containsKey(selectedId)
          ? ids.take(savedIndex).where(byId.containsKey).length
          : _queue.indexWhere((song) => song.id == selectedId);
      if (_currentIndex < 0 && _queue.isNotEmpty) _currentIndex = 0;
      final milliseconds = (saved?['positionMs'] as num?)?.toInt() ?? 0;
      _position = currentSong?.id == selectedId
          ? _clamp(Duration(milliseconds: milliseconds))
          : Duration.zero;
      _resetShuffle();
      if (selectedId != null && currentSong?.id == selectedId) {
        try {
          await _openCurrent(autoStart: false);
        } catch (_) {
          _error =
              'The selected song could not be prepared. Choose another song.';
        }
      }
      await _persist();
    },
    busy: true,
    failure: 'The library could not be initialized. Try scanning again.',
  );

  Future<void> scan({bool requestPermission = true}) => _run(
    () async {
      _error = null;
      final result = await _library.scan(requestPermission: requestPermission);
      _permissionDenied = result.permissionDenied;
      _songs = _ordered(
        result.permissionDenied ? [..._songs, ...result.songs] : result.songs,
      );
      final oldSong = currentSong;
      final oldQueue = List<Song>.of(_queue);
      final oldIndex = _currentIndex;
      final byId = {for (final song in _songs) song.id: song};
      _queue = _queue.map((song) => byId[song.id]).whereType<Song>().toList();
      _currentIndex = oldSong == null || !byId.containsKey(oldSong.id)
          ? -1
          : oldQueue
                .take(oldIndex)
                .where((song) => byId.containsKey(song.id))
                .length;
      if (_currentIndex < 0) {
        await _playback.stop();
        _isPlaying = false;
        _loaded = false;
        _position = Duration.zero;
        _actualDuration = Duration.zero;
        if (_queue.isNotEmpty) _currentIndex = 0;
      }
      _resetShuffle();
      await _persist();
    },
    busy: true,
    failure: 'Music could not be scanned. Try again or import files.',
  );

  Future<void> importFiles() => _run(
    () async {
      _error = null;
      try {
        _songs = _ordered([..._songs, ...await _library.importFiles()]);
      } on PartialImportException catch (partial) {
        _songs = _ordered([..._songs, ...partial.songs]);
        final count = partial.failedCount;
        final nextStep = partial.songs.isEmpty
            ? 'Try choosing another audio file.'
            : 'The remaining files were added.';
        _error =
            '$count ${count == 1 ? 'file' : 'files'} could not be imported. $nextStep';
      }
      await _persist();
    },
    busy: true,
    failure: 'Files could not be imported. Please try again.',
  );
  Future<void> openSettings() => _run(
    _library.openSettings,
    failure:
        'Settings could not be opened. Open app permissions in device settings.',
  );

  Future<void> playSong(Song song, {List<Song>? from}) {
    final selected = List<Song>.of(from ?? _songs);
    var index = selected.indexWhere((s) => s.id == song.id);
    if (index < 0) {
      selected.add(song);
      index = selected.length - 1;
    }
    return playQueue(selected, startIndex: index);
  }

  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) {
    final requested = List<Song>.of(songs);
    return _run(
      () async {
        _error = null;
        if (requested.any((song) => !isLocalMediaPath(song.path))) {
          throw const FormatException('Local files only');
        }
        if (requested.isEmpty) {
          await _stopAndClear();
          await _persist();
          return;
        }
        _queue = requested;
        _currentIndex = startIndex.clamp(0, _queue.length - 1);
        _position = Duration.zero;
        _resetShuffle();
        await _openCurrent(autoStart: true);
        await _persist();
      },
      failure:
          'This song could not be played. Check that the file is still available.',
    );
  }

  Future<void> _openCurrent({required bool autoStart}) async {
    final song = currentSong;
    if (song == null) return;
    _actualDuration = Duration.zero;
    _loaded = false;
    _opening = true;
    final requestedPosition = _position;
    try {
      await _playback.open(
        song,
        autoStart: autoStart,
        position: requestedPosition,
      );
      _position = requestedPosition;
      _loaded = true;
      _isPlaying = autoStart;
    } catch (_) {
      _isPlaying = false;
      rethrow;
    } finally {
      _opening = false;
    }
  }

  Future<void> _play() async {
    _error = null;
    if (currentSong == null) {
      if (_songs.isEmpty) return;
      _queue = List.of(_songs);
      _currentIndex = 0;
      _position = Duration.zero;
      _resetShuffle();
    }
    if (_loaded) {
      await _playback.play();
      _isPlaying = true;
    } else {
      await _openCurrent(autoStart: true);
    }
    await _persist();
  }

  Future<void> play() => _run(
    _play,
    failure:
        'This song could not be played. Check that the file is still available.',
  );
  Future<void> pause() => _run(() async {
    await _pause();
    await _persist();
  });
  Future<void> _pause() async {
    if (_loaded) await _playback.pause();
    _isPlaying = false;
  }

  Future<void> togglePlayPause() => _run(
    () async {
      if (_isPlaying) {
        await _pause();
        await _persist();
      } else {
        await _play();
      }
    },
    failure:
        'This song could not be played. Check that the file is still available.',
  );
  Future<void> stop() => _run(() async {
    await _playback.stop();
    _loaded = false;
    _isPlaying = false;
    _position = Duration.zero;
    await _persist();
  });
  Future<void> _stopAndClear() async {
    await _playback.stop();
    _queue = [];
    _currentIndex = -1;
    _loaded = false;
    _isPlaying = false;
    _position = Duration.zero;
    _actualDuration = Duration.zero;
  }

  Future<void> next() => _run(() async {
    await _next();
    await _persist();
  }, failure: 'The next song could not be played. Try another file.');
  Future<void> _next({bool completed = false}) async {
    if (currentSong == null) return;
    // The completion callback runs after the native player has been stopped.
    // A later seek must be restored by open(), rather than sent to that player.
    if (completed) {
      _loaded = false;
    }
    if (completed && _repeatMode == RepeatMode.one) {
      _position = Duration.zero;
      await _openCurrent(autoStart: true);
      return;
    }
    int? nextIndex;
    if (_shuffleEnabled && _queue.length > 1) {
      if (_shuffleBag.isEmpty && _repeatMode == RepeatMode.all) {
        _resetShuffle(clearHistory: false);
      }
      if (_shuffleBag.isNotEmpty) nextIndex = _shuffleBag.removeLast();
    } else if (_currentIndex + 1 < _queue.length) {
      nextIndex = _currentIndex + 1;
    } else if (_repeatMode == RepeatMode.all) {
      nextIndex = 0;
    }
    if (nextIndex == null) {
      await _pause();
      _position = Duration.zero;
      if (_loaded) await _playback.seek(Duration.zero);
      return;
    }
    _history.add(_currentIndex);
    _currentIndex = nextIndex;
    _position = Duration.zero;
    _error = null;
    await _openCurrent(autoStart: true);
  }

  Future<void> previous() => _run(() async {
    if (currentSong == null) return;
    if (_position > const Duration(seconds: 3)) {
      await _seek(Duration.zero);
      await _persist();
      return;
    }
    if (_shuffleEnabled && _history.isNotEmpty) {
      _currentIndex = _history.removeLast();
    } else if (_currentIndex > 0) {
      _currentIndex--;
    } else if (_repeatMode == RepeatMode.all) {
      _currentIndex = _queue.length - 1;
    }
    _position = Duration.zero;
    _error = null;
    await _openCurrent(autoStart: true);
    await _persist();
  }, failure: 'The previous song could not be played. Try another file.');
  Duration _clamp(Duration value) {
    if (value < Duration.zero) return Duration.zero;
    final end = duration;
    return end > Duration.zero && value > end ? end : value;
  }

  Future<void> _seek(Duration value) async {
    if (currentSong == null) return;
    _position = _clamp(value);
    if (_loaded) await _playback.seek(_position);
  }

  Future<void> seek(Duration position) => _run(() async {
    await _seek(position);
    await _persist();
  });
  Future<void> toggleShuffle() => _run(() async {
    _shuffleEnabled = !_shuffleEnabled;
    _resetShuffle();
    await _persist();
  });
  Future<void> cycleRepeat() => _run(() async {
    _repeatMode =
        RepeatMode.values[(_repeatMode.index + 1) % RepeatMode.values.length];
    await _persist();
  });
  void _resetShuffle({bool clearHistory = true}) {
    _shuffleBag = List.generate(
      _queue.length,
      (index) => index,
    ).where((index) => index != _currentIndex).toList()..shuffle(_random);
    if (clearHistory) _history = [];
  }

  Future<void> addToQueue(Song song) => _run(() async {
    if (!isLocalMediaPath(song.path)) {
      throw const FormatException('Local files only');
    }
    if (currentSong == null) {
      _queue = [song];
      _currentIndex = 0;
      _position = Duration.zero;
      _resetShuffle();
      await _openCurrent(autoStart: true);
    } else {
      _queue.add(song);
    }
    _resetShuffle();
    await _persist();
  }, failure: 'The queue could not be updated. Try another file.');
  Future<void> removeFromQueue(int index) => _run(() async {
    if (index < 0 || index >= _queue.length) return;
    final wasPlaying = _isPlaying;
    final wasCurrent = index == _currentIndex;
    _queue.removeAt(index);
    if (_queue.isEmpty) {
      await _stopAndClear();
    } else {
      if (index < _currentIndex) _currentIndex--;
      if (_currentIndex >= _queue.length) _currentIndex = _queue.length - 1;
      if (wasCurrent) {
        _position = Duration.zero;
        await _openCurrent(autoStart: wasPlaying);
      }
    }
    _resetShuffle();
    await _persist();
  }, failure: 'The queue could not be updated. Try another file.');
  Future<void> reorderQueue(int oldIndex, int newIndex) => _run(() async {
    if (oldIndex < 0 ||
        oldIndex >= _queue.length ||
        newIndex < 0 ||
        newIndex > _queue.length) {
      return;
    }
    if (newIndex > oldIndex) newIndex--;
    final moved = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, moved);
    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
    _resetShuffle();
    await _persist();
  });
  Future<void> toggleFavorite(Song song) => _run(() async {
    if (!_favorites.remove(song.id)) _favorites.add(song.id);
    await _persist();
  });
  Future<void> createPlaylist(String name) => _run(() async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return;
    final id =
        '${DateTime.now().microsecondsSinceEpoch}-${_playlistSequence++}';
    _playlists.add(LocalPlaylist(id: id, name: cleaned));
    await _persist();
  });
  Future<void> _editPlaylist(
    String id,
    LocalPlaylist Function(LocalPlaylist) edit,
  ) async {
    final index = _playlists.indexWhere((p) => p.id == id);
    if (index < 0) return;
    _playlists[index] = edit(_playlists[index]);
    await _persist();
  }

  Future<void> renamePlaylist(String id, String name) => _run(() async {
    if (name.trim().isNotEmpty) {
      await _editPlaylist(id, (p) => p.copyWith(name: name.trim()));
    }
  });
  Future<void> deletePlaylist(String id) => _run(() async {
    _playlists.removeWhere((p) => p.id == id);
    await _persist();
  });
  Future<void> addToPlaylist(String id, Song song) => _run(
    () => _editPlaylist(
      id,
      (p) => p.songIds.contains(song.id)
          ? p
          : p.copyWith(songIds: [...p.songIds, song.id]),
    ),
  );
  Future<void> addSongsToPlaylist(String id, Iterable<Song> songs) {
    final additions = songs.map((song) => song.id).toList();
    return _run(
      () => _editPlaylist(
        id,
        (playlist) => playlist.copyWith(
          songIds: {...playlist.songIds, ...additions}.toList(),
        ),
      ),
    );
  }

  Future<void> removeFromPlaylist(String id, String songId) => _run(
    () => _editPlaylist(
      id,
      (p) =>
          p.copyWith(songIds: p.songIds.where((id) => id != songId).toList()),
    ),
  );
  void setSearchQuery(String query) {
    _searchQuery = query;
    _notify();
  }

  void clearError() {
    _error = null;
    _notify();
  }

  /// Flush progress when the host app becomes inactive or is suspended.
  Future<void> saveState() =>
      _run(_persist, failure: 'Playback progress could not be saved.');

  void _onPlaybackEvent(PlaybackEvent event) {
    if (_disposed) return;
    if (event.error != null) {
      _error = event.error;
      _isPlaying = false;
      _loaded = false;
    }
    if (event.isPlaying != null) _isPlaying = event.isPlaying!;
    if (event.duration != null) _actualDuration = event.duration!;
    if (event.position != null && currentSong != null && !_opening) {
      _position = _clamp(event.position!);
      if ((_position.inSeconds - _lastPositionSave).abs() >= 5) {
        _lastPositionSave = _position.inSeconds;
        unawaited(
          _run(_persist, failure: 'Playback progress could not be saved.'),
        );
      }
    }
    if (event.completed && !_opening) {
      unawaited(
        _run(() async {
          await _next(completed: true);
          await _persist();
        }, failure: 'The next song could not be played. Try another file.'),
      );
    }
    _notify();
  }

  static List<Song> _decodeSongs(dynamic value) {
    final songs = <Song>[];
    for (final raw in value is List ? value : const []) {
      try {
        final song = Song.fromJson(Map<String, dynamic>.from(raw as Map));
        if (isLocalMediaPath(song.path)) songs.add(song);
      } catch (_) {
        continue;
      }
    }
    return songs;
  }

  static List<Song> _ordered(List<Song> songs) =>
      {
        for (final song in songs)
          if (isLocalMediaPath(song.path)) song.id: song,
      }.values.toList()..sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
  Future<void> _persist() => _store.write({
    'version': 1,
    'songs': _songs.map((s) => s.toJson()).toList(),
    'favorites': _favorites.toList(),
    'playlists': _playlists.map((p) => p.toJson()).toList(),
    'queue': _queue.map((s) => s.id).toList(),
    'currentSongId': currentSong?.id,
    'currentIndex': _currentIndex,
    'positionMs': _position.inMilliseconds,
    'shuffle': _shuffleEnabled,
    'repeat': _repeatMode.name,
  });
  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    unawaited(
      _commands
          .then((_) async {
            try {
              await _persist();
            } finally {
              await _playback.dispose();
            }
          })
          .catchError((Object _) {}),
    );
    super.dispose();
  }
}
