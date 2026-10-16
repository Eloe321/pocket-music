import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'ports.dart';
import 'platform_library.dart' show isLocalMediaPath;
export 'models.dart';
export 'ports.dart';

class QueueEntry {
  const QueueEntry(
    this.song,
    this.sourceIndex, {
    this.isCurrent = false,
    this.isPlayed = false,
  });
  final Song song;
  final int sourceIndex;
  final bool isCurrent;
  final bool isPlayed;
}

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
  List<Song> _songs = [], _queue = [], _upNext = [], _upNextHistory = [];
  Song? _activeUpNext;
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
  List<int> get _orderedRemaining {
    final played = _history.toSet();
    return [
      for (var i = _currentIndex + 1; i < _queue.length; i++)
        if (!played.contains(i)) i,
    ];
  }

  List<int> get _upcomingIndices {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return const [];
    if (_shuffleEnabled) return _shuffleBag.reversed.toList();
    final upcoming = _orderedRemaining;
    if (upcoming.isEmpty && _repeatMode == RepeatMode.all) {
      return [
        for (var i = 0; i < _queue.length; i++)
          if (i != _currentIndex) i,
      ];
    }
    return upcoming;
  }

  List<QueueEntry> get displayQueue {
    if (_queue.isEmpty) return const [];
    final upcoming = _upcomingIndices;
    final scheduled = {...upcoming, _currentIndex};
    return List.unmodifiable([
      if (_currentIndex >= 0 && _currentIndex < _queue.length)
        QueueEntry(_queue[_currentIndex], _currentIndex, isCurrent: true),
      for (final index in upcoming) QueueEntry(_queue[index], index),
      for (var index = 0; index < _queue.length; index++)
        if (!scheduled.contains(index))
          QueueEntry(_queue[index], index, isPlayed: true),
    ]);
  }

  List<Song> get upNext => List.unmodifiable(_upNext);
  Song? get activeUpNextSong => _activeUpNext;
  bool get isPlayingUpNext => _activeUpNext != null;
  Song? get currentSong =>
      _activeUpNext ??
      (_currentIndex >= 0 && _currentIndex < _queue.length
          ? _queue[_currentIndex]
          : null);
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
      _upNext = (saved?['upNext'] as List? ?? [])
          .whereType<String>()
          .map((id) => byId[id])
          .whereType<Song>()
          .toList();
      _activeUpNext = byId[saved?['activeUpNextId'] as String?];
      final selectedId = saved?['currentSongId'] as String?;
      final normalSelectedId =
          (saved?['normalSongId'] as String?) ??
          (_activeUpNext == null ? selectedId : null);
      final savedIndex = (saved?['currentIndex'] as num?)?.toInt();
      _currentIndex =
          savedIndex != null &&
              savedIndex >= 0 &&
              savedIndex < ids.length &&
              ids[savedIndex] == normalSelectedId &&
              byId.containsKey(normalSelectedId)
          ? ids.take(savedIndex).where(byId.containsKey).length
          : _queue.indexWhere((song) => song.id == normalSelectedId);
      if (_currentIndex < 0 && _queue.isNotEmpty) _currentIndex = 0;
      final milliseconds = (saved?['positionMs'] as num?)?.toInt() ?? 0;
      _position = currentSong?.id == selectedId
          ? _clamp(Duration(milliseconds: milliseconds))
          : Duration.zero;
      final savedBag = (saved?['shuffleBag'] as List? ?? [])
          .whereType<num>()
          .map((n) => n.toInt())
          .toList();
      final savedHistory = (saved?['history'] as List? ?? [])
          .whereType<num>()
          .map((n) => n.toInt())
          .toList();
      final unchangedQueue =
          ids.length == _queue.length &&
          List.generate(
            ids.length,
            (i) => ids[i] == _queue[i].id,
          ).every((same) => same);
      final validOrder =
          [
            ...savedBag,
            ...savedHistory,
          ].every((i) => i >= 0 && i < _queue.length) &&
          savedBag.toSet().length == savedBag.length &&
          !savedBag.contains(_currentIndex);
      if (unchangedQueue && validOrder && saved?['shuffleBag'] is List) {
        _shuffleBag = savedBag;
        _history = savedHistory;
      } else {
        _resetShuffle();
      }
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
      final indexMap = <int, int>{};
      for (var i = 0; i < oldQueue.length; i++) {
        if (byId.containsKey(oldQueue[i].id)) indexMap[i] = indexMap.length;
      }
      _queue = _queue.map((song) => byId[song.id]).whereType<Song>().toList();
      _history = _history.map((i) => indexMap[i]).whereType<int>().toList();
      _shuffleBag = _shuffleBag
          .map((i) => indexMap[i])
          .whereType<int>()
          .toList();
      _upNext = _upNext.map((song) => byId[song.id]).whereType<Song>().toList();
      _activeUpNext = _activeUpNext == null ? null : byId[_activeUpNext!.id];
      _upNextHistory = _upNextHistory
          .map((song) => byId[song.id])
          .whereType<Song>()
          .toList();
      final oldNormal = oldIndex >= 0 && oldIndex < oldQueue.length
          ? oldQueue[oldIndex]
          : null;
      _currentIndex = oldNormal == null || !byId.containsKey(oldNormal.id)
          ? -1
          : oldQueue
                .take(oldIndex)
                .where((song) => byId.containsKey(song.id))
                .length;
      if (oldSong == null || currentSong?.id != oldSong.id) {
        await _playback.stop();
        _isPlaying = false;
        _loaded = false;
        _position = Duration.zero;
        _actualDuration = Duration.zero;
        if (_queue.isNotEmpty) _currentIndex = 0;
      }
      if (oldSong == null || currentSong?.id != oldSong.id) {
        _resetShuffle();
      } else {
        _shuffleBag.remove(_currentIndex);
      }
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
        _upNext = [];
        _upNextHistory = [];
        _activeUpNext = null;
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
    _upNext = [];
    _upNextHistory = [];
    _activeUpNext = null;
    _currentIndex = -1;
    _history = [];
    _shuffleBag = [];
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
    if (_upNext.isNotEmpty) {
      if (_activeUpNext != null) _upNextHistory.add(_activeUpNext!);
      _activeUpNext = _upNext.removeAt(0);
      _position = Duration.zero;
      _error = null;
      await _openCurrent(autoStart: true);
      return;
    }
    if (completed && _repeatMode == RepeatMode.one && _activeUpNext == null) {
      _position = Duration.zero;
      await _openCurrent(autoStart: true);
      return;
    }
    int? nextIndex;
    var newCycle = false;
    if (_activeUpNext != null &&
        _repeatMode == RepeatMode.one &&
        _queue.isNotEmpty) {
      nextIndex = _currentIndex;
    } else if (_shuffleEnabled && _queue.length > 1) {
      if (_shuffleBag.isEmpty && _repeatMode == RepeatMode.all) {
        _resetShuffle();
        newCycle = true;
      }
      if (_shuffleBag.isNotEmpty) nextIndex = _shuffleBag.removeLast();
    } else if (_orderedRemaining.isNotEmpty) {
      nextIndex = _orderedRemaining.first;
    } else if (_repeatMode == RepeatMode.all && _queue.isNotEmpty) {
      _history.clear();
      nextIndex = 0;
      newCycle = true;
    }
    if (nextIndex == null) {
      await _pause();
      _position = Duration.zero;
      if (_loaded) await _playback.seek(Duration.zero);
      return;
    }
    _activeUpNext = null;
    _upNextHistory = [];
    if (!newCycle && nextIndex != _currentIndex) _history.add(_currentIndex);
    _currentIndex = nextIndex;
    if (_shuffleEnabled &&
        _shuffleBag.isEmpty &&
        _repeatMode == RepeatMode.all) {
      _resetShuffle();
    }
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
    if (_activeUpNext != null) {
      _upNext.insert(0, _activeUpNext!);
      _activeUpNext = _upNextHistory.isEmpty
          ? null
          : _upNextHistory.removeLast();
      _position = Duration.zero;
      _error = null;
      await _openCurrent(autoStart: true);
      await _persist();
      return;
    }
    if (_shuffleEnabled && _history.isNotEmpty) {
      if (!_shuffleBag.contains(_currentIndex)) _shuffleBag.add(_currentIndex);
      _currentIndex = _history.removeLast();
    } else if (_history.isNotEmpty) {
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
    if (_shuffleEnabled) _resetShuffle(clearHistory: false);
    await _persist();
  });
  Future<void> cycleRepeat() => _run(() async {
    _repeatMode =
        RepeatMode.values[(_repeatMode.index + 1) % RepeatMode.values.length];
    await _persist();
  });
  void _resetShuffle({bool clearHistory = true}) {
    if (clearHistory) _history = [];
    final played = _history.toSet();
    _shuffleBag =
        List.generate(_queue.length, (index) => index)
            .where((index) => index != _currentIndex && !played.contains(index))
            .toList()
          ..shuffle(_random);
  }

  Future<void> addToUpNext(Song song) => _run(() async {
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
      _upNext.add(song);
    }
    await _persist();
  }, failure: 'Up next could not be updated. Try another file.');
  Future<void> addToQueue(Song song) => addToUpNext(song);
  Future<void> removeFromUpNext(int index) => _run(() async {
    if (index < 0 || index >= _upNext.length) return;
    _upNext.removeAt(index);
    await _persist();
  });
  Future<void> reorderUpNext(int oldIndex, int newIndex) => _run(() async {
    if (oldIndex < 0 ||
        oldIndex >= _upNext.length ||
        newIndex < 0 ||
        newIndex > _upNext.length) {
      return;
    }
    if (newIndex > oldIndex) newIndex--;
    _upNext.insert(newIndex, _upNext.removeAt(oldIndex));
    await _persist();
  });
  Future<void> removeFromQueue(int index) => _run(() async {
    if (index < 0 || index >= _queue.length) return;
    final wasPlaying = _isPlaying;
    final wasCurrent = index == _currentIndex;
    _history = _history
        .where((i) => i != index)
        .map((i) => i > index ? i - 1 : i)
        .toList();
    _shuffleBag = _shuffleBag
        .where((i) => i != index)
        .map((i) => i > index ? i - 1 : i)
        .toList();
    _queue.removeAt(index);
    if (_queue.isEmpty) {
      _history = [];
      _shuffleBag = [];
      _currentIndex = -1;
      if (_activeUpNext == null && _upNext.isNotEmpty) {
        _activeUpNext = _upNext.removeAt(0);
        _position = Duration.zero;
        await _openCurrent(autoStart: wasPlaying);
      } else if (_activeUpNext == null) {
        await _stopAndClear();
      }
    } else {
      if (index < _currentIndex) _currentIndex--;
      if (_currentIndex >= _queue.length) _currentIndex = _queue.length - 1;
      if (wasCurrent) {
        _history.remove(_currentIndex);
        _shuffleBag.remove(_currentIndex);
      }
      if (wasCurrent && _activeUpNext == null) {
        _position = Duration.zero;
        await _openCurrent(autoStart: wasPlaying);
      }
    }
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
  Future<void> reorderDisplayedQueue(int oldIndex, int newIndex) =>
      _run(() async {
        final upcoming = _upcomingIndices;
        if (upcoming.length < 2) return;
        final start = _currentIndex >= 0 ? 1 : 0;
        final oldUpcoming = oldIndex - start;
        final newUpcoming = (newIndex - start).clamp(0, upcoming.length - 1);
        if (oldUpcoming < 0 ||
            oldUpcoming >= upcoming.length ||
            oldUpcoming == newUpcoming) {
          return;
        }
        if (_shuffleEnabled) {
          upcoming.insert(newUpcoming, upcoming.removeAt(oldUpcoming));
          _shuffleBag = upcoming.reversed.toList();
        } else {
          final reorderedSongs = upcoming.map((i) => _queue[i]).toList();
          reorderedSongs.insert(
            newUpcoming,
            reorderedSongs.removeAt(oldUpcoming),
          );
          for (var i = 0; i < upcoming.length; i++) {
            _queue[upcoming[i]] = reorderedSongs[i];
          }
        }
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
    'upNext': _upNext.map((s) => s.id).toList(),
    'activeUpNextId': _activeUpNext?.id,
    'normalSongId': _currentIndex >= 0 && _currentIndex < _queue.length
        ? _queue[_currentIndex].id
        : null,
    'currentSongId': currentSong?.id,
    'currentIndex': _currentIndex,
    'shuffleBag': _shuffleBag,
    'history': _history,
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
