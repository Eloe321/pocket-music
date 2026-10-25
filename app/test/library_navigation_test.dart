import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_music/core/music_controller.dart';
import 'package:pocket_music/player_app.dart';
import 'package:pocket_music/ui/song_widgets.dart';

import 'core/music_controller_test.dart' as fixtures;

void main() {
  late fixtures.FakeLibrary library;
  late MusicController controller;

  setUp(() {
    library = fixtures.FakeLibrary();
    controller = MusicController(
      library: library,
      playback: fixtures.FakePlayback(),
      store: fixtures.MemoryStore(),
    );
  });
  tearDown(() => controller.dispose());

  Future<void> openLibrary(WidgetTester tester) async {
    await controller.initialize();
    await tester.pumpWidget(PocketMusicApp(controller: controller));
  }

  testWidgets('a library search result queues the entire library', (
    tester,
  ) async {
    await openLibrary(tester);
    await tester.enterText(find.byKey(const Key('library-search')), 'Song b');
    await tester.pump();
    expect(find.byKey(const Key('song-a')), findsNothing);
    await tester.tap(find.byKey(const Key('song-b')));
    await tester.pumpAndSettle();
    expect(controller.queue.map((song) => song.id), ['a', 'b', 'c']);
    expect(controller.currentSong?.id, 'b');
    await tester.runAsync(controller.next);
    await tester.pumpAndSettle();
    expect(controller.currentSong?.id, 'c');
  });

  for (final action in ['Play all', 'Shuffle']) {
    testWidgets('$action from search uses the entire parent library', (
      tester,
    ) async {
      await openLibrary(tester);
      await tester.enterText(find.byKey(const Key('library-search')), 'Song b');
      await tester.pump();
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      expect(controller.queue.map((song) => song.id), ['a', 'b', 'c']);
    });
  }

  testWidgets('a searched favorite queues only the full favorites collection', (
    tester,
  ) async {
    await controller.initialize();
    await controller.toggleFavorite(library.songs[0]);
    await controller.toggleFavorite(library.songs[2]);
    await tester.pumpWidget(PocketMusicApp(controller: controller));
    await tester.tap(find.byKey(const Key('nav-favorites')));
    await tester.enterText(find.byKey(const Key('library-search')), 'Song c');
    await tester.pump();
    await tester.tap(find.byKey(const Key('song-c')));
    await tester.pumpAndSettle();
    expect(controller.queue.map((song) => song.id), ['a', 'c']);
    expect(controller.currentSong?.id, 'c');
  });

  testWidgets('searching inside a playlist preserves its complete queue', (
    tester,
  ) async {
    await controller.initialize();
    await controller.createPlaylist('Night');
    final id = controller.playlists.single.id;
    await controller.addToPlaylist(id, library.songs[0]);
    await controller.addToPlaylist(id, library.songs[2]);
    await tester.pumpWidget(PocketMusicApp(controller: controller));
    await tester.tap(find.byKey(const Key('nav-playlists')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Night'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('collection-search')),
      'Song c',
    );
    await tester.pump();
    expect(find.byKey(const Key('song-a')), findsNothing);
    await tester.tap(find.byKey(const Key('song-c')));
    await tester.pumpAndSettle();
    expect(controller.queue.map((song) => song.id), ['a', 'c']);
    expect(controller.currentSong?.id, 'c');
  });

  testWidgets('opening an album from global search includes the whole album', (
    tester,
  ) async {
    await openLibrary(tester);
    await tester.enterText(find.byKey(const Key('library-search')), 'Song b');
    await tester.pump();
    await tester.tap(find.text('Albums'));
    await tester.pump();
    await tester.tap(find.text('Album'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('collection-search')),
      'Song b',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('song-b')));
    await tester.pumpAndSettle();
    expect(controller.queue.map((song) => song.id), ['a', 'b', 'c']);
  });

  testWidgets('collection search stays pinned while browsing a playlist', (
    tester,
  ) async {
    library.songs = [for (var i = 0; i < 40; i++) fixtures.song('track-$i')];
    await controller.initialize();
    await controller.createPlaylist('Long playlist');
    final id = controller.playlists.single.id;
    for (final song in library.songs) {
      await controller.addToPlaylist(id, song);
    }
    await tester.pumpWidget(PocketMusicApp(controller: controller));
    await tester.tap(find.byKey(const Key('nav-playlists')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Long playlist'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('collection-song-scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    final search = find.byKey(const Key('collection-search'));
    expect(search, findsOneWidget);
    expect(tester.getTopLeft(search).dy, lessThan(150));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening a searched artist retains all songs by that artist', (
    tester,
  ) async {
    library.songs = [
      for (final id in ['a', 'b', 'c'])
        Song(
          id: id,
          path: '/$id.mp3',
          title: 'Song $id',
          artist: id == 'c' ? 'Other artist' : 'Shared artist',
          album: 'Album',
          duration: const Duration(minutes: 3),
        ),
    ];
    await openLibrary(tester);
    await tester.enterText(find.byKey(const Key('library-search')), 'Song b');
    await tester.pump();
    await tester.tap(find.text('Artists'));
    await tester.pump();
    await tester.tap(find.text('Shared artist'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('collection-search')),
      'Song b',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('song-b')));
    await tester.pumpAndSettle();
    expect(controller.queue.map((song) => song.id), ['a', 'b']);
  });

  List<Song> largeLibrary() => [
    fixtures.song('number', title: '101 nights'),
    fixtures.song('symbol', title: '! Again'),
    fixtures.song('unicode', title: '東京'),
    fixtures.song('accent', title: 'É song -01'),
    for (var letter = 65; letter <= 90; letter++)
      for (var i = 0; i < 37; i++)
        fixtures.song(
          '${String.fromCharCode(letter).toLowerCase()}-$i',
          title:
              '${String.fromCharCode(letter)} song ${i.toString().padLeft(2, '0')}',
        ),
  ];

  testWidgets(
    'alphabet jumps through a large library without building every song',
    (tester) async {
      library.songs = largeLibrary();
      await openLibrary(tester);
      expect(find.byType(SongTile).evaluate().length, lessThan(30));
      await tester.tap(find.byKey(const Key('alphabet-Z')));
      await tester.pumpAndSettle();
      final firstZ = find.byKey(const Key('song-z-0'));
      expect(firstZ, findsOneWidget);
      expect(tester.getTopLeft(firstZ).dy, greaterThan(130));
      expect(tester.getTopLeft(firstZ).dy, lessThan(250));
      expect(find.byType(SongTile).evaluate().length, lessThan(30));
      expect(
        tester.getTopLeft(find.byKey(const Key('library-search'))).dy,
        lessThan(230),
      );
      await tester.tap(find.byKey(const Key('alphabet-E')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('song-accent')), findsOneWidget);
      await tester.tap(find.byKey(const Key('alphabet-#')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('song-symbol')), findsOneWidget);
      expect(find.byKey(const Key('song-unicode')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dragging the alphabet shows a letter to the left of the finger',
    (tester) async {
      library.songs = largeLibrary();
      await openLibrary(tester);
      final a = tester.getCenter(find.byKey(const Key('alphabet-A')));
      final z = tester.getCenter(find.byKey(const Key('alphabet-Z')));
      final gesture = await tester.startGesture(a);
      await tester.pump();
      await gesture.moveTo(z);
      await tester.pump();
      final bubble = find.byKey(const Key('alphabet-bubble'));
      expect(bubble, findsOneWidget);
      expect(tester.getRect(bubble).right, lessThan(z.dx - 12));
      expect(
        find.descendant(of: bubble, matching: find.text('Z')),
        findsOneWidget,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(bubble, findsNothing);
      expect(find.byKey(const Key('song-z-0')), findsOneWidget);
    },
  );

  testWidgets('missing alphabet letters are disabled', (tester) async {
    await openLibrary(tester);
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byKey(const Key('alphabet-Z'))),
      matchesSemantics(
        label: 'Z, no songs',
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    semantics.dispose();
  });

  testWidgets('index and song rows fit a small display with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    library.songs = largeLibrary();
    await openLibrary(tester);
    await tester.tap(find.byKey(const Key('alphabet-Z')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('song-z-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
