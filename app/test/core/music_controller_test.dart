import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_music/core/music_controller.dart';

Song song(String id, {String? title}) => Song(
  id: id,
  path: '/$id.mp3',
  title: title ?? 'Song $id',
  artist: 'Artist $id',
  album: 'Album',
  duration: const Duration(minutes: 3),
);

class FakeLibrary implements LibraryPort {
  int settingsCalls = 0;
  List<Song> songs = [song('a'), song('b'), song('c')];
  bool denied = false;
  Object? importError;
  List<Song>? importedSongs;
  @override
  Future<LibraryResult> scan({required bool requestPermission}) async =>
      LibraryResult(songs: songs, permissionDenied: denied);
  @override
  Future<List<Song>> importFiles() async {
    if (importError != null) throw importError!;
    return importedSongs ?? [song('d')];
  }

  @override
  Future<void> openSettings() async {
    settingsCalls++;
  }
}

class FakePlayback implements PlaybackPort {
  final events = StreamController<PlaybackEvent>.broadcast(sync: true);
  final opens = <String>[];
  final openedPositions = <Duration>[];
  bool fail = false;
  bool playing = false;
  bool emitZeroOnOpen = false;
  int active = 0;
  int maxActive = 0;
  @override
  Stream<PlaybackEvent> get changes => events.stream;
  @override
  Future<void> open(
    Song song, {
    required bool autoStart,
    required Duration position,
  }) async {
    active++;
    maxActive = max(maxActive, active);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    active--;
    if (fail) throw StateError('unreadable media');
    opens.add(song.id);
    openedPositions.add(position);
    if (emitZeroOnOpen) {
      events.add(const PlaybackEvent(position: Duration.zero));
    }
    playing = autoStart;
  }

  @override
  Future<void> play() async {
    playing = true;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> stop() async {
    playing = false;
  }

  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> dispose() async {
    await events.close();
  }
}

class MemoryStore implements StateStore {
  Map<String, dynamic>? state;
  @override
  Future<Map<String, dynamic>?> read() async => state;
  @override
  Future<void> write(Map<String, dynamic> value) async {
    state = value;
  }
}

void main() {
  late FakeLibrary library;
  late FakePlayback playback;
  late MemoryStore store;
  late MusicController controller;
  setUp(() {
    library = FakeLibrary();
    playback = FakePlayback();
    store = MemoryStore();
    controller = MusicController(
      library: library,
      playback: playback,
      store: store,
      random: Random(4),
    );
  });
  tearDown(() {
    controller.dispose();
  });

  test('initializes library without starting playback', () async {
    await controller.initialize();
    expect(controller.songs.length, 3);
    expect(playback.opens, isEmpty);
    expect(controller.isPlaying, isFalse);
  });
  test('adding to an empty queue starts the chosen song', () async {
    await controller.initialize();
    await controller.addToQueue(library.songs[1]);
    expect(controller.currentSong?.id, 'b');
    expect(controller.isPlaying, isTrue);
    expect(playback.opens, ['b']);
  });
  test('Up next plays FIFO before resuming the normal queue', () async {
    await controller.initialize();
    await controller.playQueue(library.songs, startIndex: 0);
    await controller.addToUpNext(song('x'));
    await controller.addToUpNext(song('y'));
    expect(controller.queue.map((s) => s.id), ['a', 'b', 'c']);
    expect(controller.upNext.map((s) => s.id), ['x', 'y']);
    expect(controller.currentSong?.id, 'a');
    await controller.next();
    expect(controller.currentSong?.id, 'x');
    expect(controller.upNext.map((s) => s.id), ['y']);
    await controller.next();
    expect(controller.currentSong?.id, 'y');
    await controller.next();
    expect(controller.currentSong?.id, 'b');
    expect(controller.upNext, isEmpty);
    expect(controller.queue.map((s) => s.id), ['a', 'b', 'c']);
  });
  test(
    'visible normal queue follows current, upcoming, then played songs',
    () async {
      await controller.initialize();
      await controller.playQueue(library.songs);
      expect(controller.displayQueue.map((entry) => entry.song.id), [
        'a',
        'b',
        'c',
      ]);
      await controller.next();
      expect(controller.displayQueue.map((entry) => entry.song.id), [
        'b',
        'c',
        'a',
      ]);
      expect(controller.displayQueue.first.isCurrent, isTrue);
      expect(controller.displayQueue.last.isPlayed, isTrue);
      await controller.next();
      expect(controller.displayQueue.map((entry) => entry.song.id), [
        'c',
        'a',
        'b',
      ]);
    },
  );
  test('removing a queued song preserves the shuffled next order', () async {
    library.songs.add(song('d'));
    await controller.initialize();
    await controller.playQueue(library.songs);
    await controller.toggleShuffle();
    await controller.next();
    final before = controller.displayQueue
        .map((entry) => entry.song.id)
        .toList();
    expect(before.last, 'a');
    await controller.removeFromQueue(controller.displayQueue[2].sourceIndex);
    expect(controller.displayQueue.map((entry) => entry.song.id), [
      before[0],
      before[1],
      before[3],
    ]);
    await controller.next();
    expect(controller.currentSong?.id, before[1]);
  });
  test(
    'shuffle preview is the exact sequence used by Next and survives restart',
    () async {
      await controller.initialize();
      await controller.playQueue(library.songs);
      await controller.toggleShuffle();
      final expected = controller.displayQueue
          .map((entry) => entry.song.id)
          .toList();
      expect(expected.first, 'a');
      final restored = MusicController(
        library: library,
        playback: FakePlayback(),
        store: store,
        random: Random(99),
      );
      await restored.initialize();
      expect(restored.displayQueue.map((entry) => entry.song.id), expected);
      for (final id in expected.skip(1)) {
        await restored.next();
        expect(restored.currentSong?.id, id);
        expect(restored.displayQueue.first.song.id, id);
      }
      restored.dispose();
    },
  );
  test(
    'reordering a visible shuffled upcoming song changes playback',
    () async {
      await controller.initialize();
      await controller.playQueue(library.songs);
      await controller.toggleShuffle();
      final before = controller.displayQueue
          .map((entry) => entry.song.id)
          .toList();
      await controller.reorderDisplayedQueue(2, 1);
      expect(controller.displayQueue.map((entry) => entry.song.id), [
        before[0],
        before[2],
        before[1],
      ]);
      await controller.next();
      expect(controller.currentSong?.id, before[2]);
    },
  );
  test('Up next has priority over shuffle and natural completion', () async {
    await controller.initialize();
    await controller.playQueue(library.songs);
    await controller.toggleShuffle();
    await controller.addToUpNext(song('x'));
    playback.events.add(const PlaybackEvent(completed: true));
    await controller.saveState();
    expect(controller.currentSong?.id, 'x');
    await controller.next();
    expect(controller.currentSong?.id, isNot('x'));
  });
  test(
    'pending and active Up next survive restart and are removable',
    () async {
      await controller.initialize();
      await controller.playQueue(library.songs);
      await controller.addToUpNext(song('b'));
      await controller.addToUpNext(song('c'));
      await controller.next();
      final restored = MusicController(
        library: library,
        playback: FakePlayback(),
        store: store,
      );
      await restored.initialize();
      expect(restored.currentSong?.id, 'b');
      expect(restored.upNext.map((s) => s.id), ['c']);
      await restored.removeFromUpNext(0);
      await restored.next();
      expect(restored.currentSong?.id, 'b');
      expect(restored.isPlaying, isTrue);
      restored.dispose();
    },
  );
  test(
    'restoring a selected song prepares paused system media controls',
    () async {
      await controller.initialize();
      await controller.playSong(library.songs[1]);
      final restoredPlayback = FakePlayback();
      final restored = MusicController(
        library: library,
        playback: restoredPlayback,
        store: store,
      );
      await restored.initialize();
      expect(restoredPlayback.opens, ['b']);
      expect(restoredPlayback.playing, isFalse);
      restored.dispose();
    },
  );
  test(
    'repeat one yields to Up next, then returns to its normal song',
    () async {
      await controller.initialize();
      await controller.playQueue(library.songs);
      await controller.cycleRepeat();
      await controller.cycleRepeat();
      await controller.addToUpNext(song('b'));
      playback.events.add(const PlaybackEvent(completed: true));
      await controller.saveState();
      expect(controller.currentSong?.id, 'b');
      await controller.next();
      expect(controller.currentSong?.id, 'a');
    },
  );
  test('a new play queue clears pending Up next', () async {
    await controller.initialize();
    await controller.playQueue(library.songs);
    await controller.addToUpNext(song('b'));
    await controller.playQueue([song('c')]);
    expect(controller.upNext, isEmpty);
    expect(controller.currentSong?.id, 'c');
  });
  test(
    'Up next can be reordered and removed without editing normal queue',
    () async {
      await controller.initialize();
      await controller.playQueue(library.songs);
      await controller.addToUpNext(song('b'));
      await controller.addToUpNext(song('c'));
      await controller.reorderUpNext(0, 2);
      expect(controller.upNext.map((s) => s.id), ['c', 'b']);
      await controller.removeFromUpNext(0);
      expect(controller.upNext.map((s) => s.id), ['b']);
      expect(controller.queue.map((s) => s.id), ['a', 'b', 'c']);
      await controller.next();
      expect(controller.currentSong?.id, 'b');
      await controller.next();
      expect(controller.currentSong?.id, 'b');
    },
  );
  test(
    'batch playlist add preserves selected order and skips duplicates',
    () async {
      await controller.initialize();
      await controller.createPlaylist('Mix');
      final id = controller.playlists.single.id;
      await controller.addToPlaylist(id, library.songs[1]);
      await controller.addSongsToPlaylist(id, [
        library.songs[0],
        library.songs[1],
        library.songs[2],
      ]);
      expect(controller.playlists.single.songIds, ['b', 'a', 'c']);
    },
  );
  test(
    'permission denial is actionable and does not erase remembered files',
    () async {
      await controller.initialize();
      library.denied = true;
      library.songs = [];
      await controller.scan();
      expect(controller.permissionDenied, isTrue);
      expect(controller.songs.length, 3);
      expect(controller.isBusy, isFalse);
    },
  );
  test(
    'search matches title artist and album without case sensitivity',
    () async {
      await controller.initialize();
      controller.setSearchQuery('ARTIST b');
      expect(controller.filteredSongs.map((s) => s.id), ['b']);
      controller.setSearchQuery('album');
      expect(controller.filteredSongs.length, 3);
    },
  );
  test('favorites and playlist edits persist through initialization', () async {
    await controller.initialize();
    await controller.toggleFavorite(song('a'));
    await controller.createPlaylist('Night drive');
    final id = controller.playlists.single.id;
    await controller.addToPlaylist(id, song('b'));
    await controller.addToPlaylist(id, song('b'));
    await controller.renamePlaylist(id, 'Evening');
    final restored = MusicController(
      library: library,
      playback: FakePlayback(),
      store: store,
    );
    await restored.initialize();
    expect(restored.favorites, {'a'});
    expect(restored.playlists.single.name, 'Evening');
    expect(restored.playlists.single.songIds, ['b']);
    restored.dispose();
  });
  test(
    'restores queue and seek paused and removes unavailable songs',
    () async {
      await controller.initialize();
      await controller.playQueue(library.songs, startIndex: 1);
      await controller.seek(const Duration(seconds: 25));
      library.songs = [song('b'), song('c')];
      final restoredPlayback = FakePlayback();
      final restored = MusicController(
        library: library,
        playback: restoredPlayback,
        store: store,
      );
      await restored.initialize();
      expect(restored.queue.map((s) => s.id), ['b', 'c']);
      expect(restored.currentSong?.id, 'b');
      expect(restored.position.inSeconds, 25);
      expect(restoredPlayback.playing, isFalse);
      restored.dispose();
    },
  );
  test(
    'reordering and removing preceding entries preserve playing song',
    () async {
      await controller.initialize();
      await controller.playQueue(library.songs, startIndex: 1);
      await controller.reorderQueue(0, 3);
      expect(controller.currentSong?.id, 'b');
      expect(controller.currentIndex, 0);
      await controller.removeFromQueue(2);
      expect(controller.currentSong?.id, 'b');
    },
  );
  test(
    'removing current song plays its successor then empty queue stops',
    () async {
      await controller.initialize();
      await controller.playQueue(library.songs);
      await controller.removeFromQueue(0);
      expect(controller.currentSong?.id, 'b');
      expect(controller.isPlaying, isTrue);
      await controller.removeFromQueue(0);
      await controller.removeFromQueue(0);
      expect(controller.currentSong, isNull);
      expect(controller.isPlaying, isFalse);
    },
  );
  test('repeat off ends queue and repeat all wraps', () async {
    await controller.initialize();
    await controller.playQueue(library.songs, startIndex: 2);
    await controller.next();
    expect(controller.isPlaying, isFalse);
    await controller.cycleRepeat();
    expect(controller.repeatMode, RepeatMode.all);
    expect(controller.displayQueue[1].song.id, 'a');
    await controller.next();
    expect(controller.currentSong?.id, 'a');
  });
  test(
    'repeat one replays completed track and shuffle avoids same track',
    () async {
      await controller.initialize();
      await controller.playQueue(library.songs);
      await controller.cycleRepeat();
      await controller.cycleRepeat();
      playback.events.add(const PlaybackEvent(completed: true));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.currentSong?.id, 'a');
      expect(playback.opens.length, 2);
      await controller.toggleShuffle();
      await controller.next();
      expect(controller.currentSong?.id, isNot('a'));
    },
  );
  test('rapid track selections serialize and last selection wins', () async {
    await controller.initialize();
    await Future.wait([
      controller.playSong(song('a')),
      controller.playSong(song('b')),
      controller.playSong(song('c')),
    ]);
    expect(playback.maxActive, 1);
    expect(controller.currentSong?.id, 'c');
    expect(playback.opens, ['a', 'b', 'c']);
  });
  test('playback error clears playing state and is recoverable', () async {
    await controller.initialize();
    playback.fail = true;
    await controller.playSong(song('a'));
    expect(controller.error, contains('could not'));
    expect(controller.isPlaying, isFalse);
    playback.fail = false;
    await controller.playSong(song('b'));
    expect(controller.error, isNull);
    expect(controller.isPlaying, isTrue);
  });
  test('import merges songs and playlist removal persists', () async {
    await controller.initialize();
    await controller.importFiles();
    expect(controller.songs.length, 4);
    await controller.createPlaylist('Mix');
    final id = controller.playlists.single.id;
    await controller.addToPlaylist(id, song('d'));
    await controller.removeFromPlaylist(id, 'd');
    expect(controller.playlists.single.songIds, isEmpty);
    await controller.deletePlaylist(id);
    expect(controller.playlists, isEmpty);
  });
  test(
    'partial import adds and persists successful files with an actionable error',
    () async {
      await controller.initialize();
      library.importError = PartialImportException(
        songs: [song('d')],
        failedCount: 2,
      );
      await controller.importFiles();
      expect(controller.songs.map((song) => song.id), ['a', 'b', 'c', 'd']);
      expect(
        controller.error,
        '2 files could not be imported. The remaining files were added.',
      );
      expect(controller.isBusy, isFalse);
      expect(
        (store.state!['songs'] as List).map((song) => (song as Map)['id']),
        contains('d'),
      );
    },
  );
  test(
    'generic import failure keeps the existing library and a retry message',
    () async {
      await controller.initialize();
      library.importError = StateError('unreadable import');
      await controller.importFiles();
      expect(controller.songs.length, 3);
      expect(
        controller.error,
        'Files could not be imported. Please try again.',
      );
      expect(controller.isBusy, isFalse);
    },
  );
  test(
    'cancelled import leaves the library available without an error',
    () async {
      await controller.initialize();
      library.importedSongs = [];
      await controller.importFiles();
      expect(controller.songs.length, 3);
      expect(controller.error, isNull);
    },
  );
  test(
    'restored seek survives transient native zero position during open',
    () async {
      await controller.initialize();
      await controller.playSong(song('a'));
      await controller.seek(const Duration(seconds: 27));
      final restoredPlayback = FakePlayback()..emitZeroOnOpen = true;
      final restored = MusicController(
        library: library,
        playback: restoredPlayback,
        store: store,
      );
      await restored.initialize();
      await restored.play();
      expect(restored.position.inSeconds, 27);
      restored.dispose();
    },
  );
  test(
    'missing media stays in favorites and playlist membership after a scan',
    () async {
      await controller.initialize();
      await controller.createPlaylist('Card music');
      final id = controller.playlists.single.id;
      await controller.addToPlaylist(id, song('a'));
      await controller.toggleFavorite(song('a'));
      library.songs = [song('b')];
      await controller.scan();
      expect(controller.songsForPlaylist(id), isEmpty);
      expect(controller.playlists.single.songIds, ['a']);
      expect(controller.favorites, contains('a'));
      library.songs = [song('a'), song('b')];
      await controller.scan();
      expect(controller.songsForPlaylist(id).single.id, 'a');
    },
  );
  test(
    'seek clamps to duration and previous restarts an advanced song',
    () async {
      await controller.initialize();
      await controller.playQueue(library.songs, startIndex: 1);
      await controller.seek(const Duration(hours: 1));
      expect(controller.position, const Duration(minutes: 3));
      await controller.previous();
      expect(controller.currentSong?.id, 'b');
      expect(controller.position, Duration.zero);
      await controller.previous();
      expect(controller.currentSong?.id, 'a');
    },
  );
  test(
    'shuffle and repeat persist without starting restored playback',
    () async {
      await controller.initialize();
      await controller.toggleShuffle();
      await controller.cycleRepeat();
      await controller.saveState();
      final restored = MusicController(
        library: library,
        playback: FakePlayback(),
        store: store,
      );
      await restored.initialize();
      expect(restored.shuffleEnabled, isTrue);
      expect(restored.repeatMode, RepeatMode.all);
      expect(restored.isPlaying, isFalse);
      restored.dispose();
    },
  );
  test(
    'seeking after natural completion reopens at the chosen position',
    () async {
      await controller.initialize();
      await controller.playQueue([library.songs.first]);
      playback.events.add(
        const PlaybackEvent(completed: true, isPlaying: false),
      );
      await controller.saveState();
      await controller.seek(const Duration(seconds: 17));
      await controller.play();
      expect(playback.opens, ['a', 'a']);
      expect(playback.openedPositions.last, const Duration(seconds: 17));
    },
  );
  test(
    'restores the selected duplicate occurrence after unavailable entries are pruned',
    () async {
      await controller.initialize();
      await controller.playQueue([
        song('a'),
        song('b'),
        song('a'),
        song('c'),
      ], startIndex: 2);
      await controller.seek(const Duration(seconds: 17));
      library.songs = [song('a'), song('c')];
      final restored = MusicController(
        library: library,
        playback: FakePlayback(),
        store: store,
      );
      await restored.initialize();
      expect(restored.queue.map((s) => s.id), ['a', 'a', 'c']);
      expect(restored.currentIndex, 1);
      expect(restored.position.inSeconds, 17);
      restored.dispose();
    },
  );
}
