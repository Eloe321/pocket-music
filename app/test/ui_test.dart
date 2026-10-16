import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_music/core/music_controller.dart';
import 'package:pocket_music/player_app.dart';
import 'core/music_controller_test.dart' as fixtures;

void main() {
  late MusicController controller;
  late fixtures.FakeLibrary library;
  setUp(() {
    library = fixtures.FakeLibrary();
    controller = MusicController(
      library: library,
      playback: fixtures.FakePlayback(),
      store: fixtures.MemoryStore(),
    );
  });
  tearDown(() => controller.dispose());

  testWidgets('album and artist groups open their own song collections', (
    tester,
  ) async {
    await controller.initialize();
    await tester.pumpWidget(PocketMusicApp(controller: controller));
    await tester.tap(find.text('Albums'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Album'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('song-a')), findsOneWidget);
    expect(find.byKey(const Key('song-b')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Artists'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Artist a'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('song-a')), findsOneWidget);
    expect(find.byKey(const Key('song-b')), findsNothing);
  });
  testWidgets(
    'populated denied library still opens system permission settings',
    (tester) async {
      library.denied = true;
      await controller.initialize();
      await tester.pumpWidget(PocketMusicApp(controller: controller));
      await tester.tap(find.byTooltip('Library options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open app settings'));
      await tester.pumpAndSettle();
      expect(library.settingsCalls, 1);
    },
  );
  testWidgets(
    'song menus add and remove playlist membership and support rename and delete',
    (tester) async {
      await controller.initialize();
      await controller.createPlaylist('Evening');
      await tester.pumpWidget(PocketMusicApp(controller: controller));
      await tester.tap(find.byTooltip('More options for Song a'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evening'));
      await tester.pumpAndSettle();
      expect(controller.playlists.single.songIds, ['a']);
      await tester.tap(find.byKey(const Key('nav-playlists')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evening'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Playlist options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename playlist'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('playlist-name')),
        'Night walk',
      );
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(controller.playlists.single.name, 'Night walk');
      await tester.tap(find.byTooltip('More options for Song a'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from playlist'));
      await tester.pumpAndSettle();
      expect(controller.playlists.single.songIds, isEmpty);
      await tester.tap(find.byTooltip('Playlist options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(controller.playlists, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('queue removal and drag reorder preserve the selected track', (
    tester,
  ) async {
    await controller.initialize();
    await tester.pumpWidget(PocketMusicApp(controller: controller));
    await tester.tap(find.byKey(const Key('song-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mini-player')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Show queue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show queue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove Song a from queue'));
    await tester.pumpAndSettle();
    expect(controller.currentSong?.id, 'b');
    final drag = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_handle_rounded).last),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await drag.moveBy(const Offset(0, -20));
    await tester.pump(const Duration(milliseconds: 500));
    await drag.moveBy(const Offset(0, -220));
    await tester.pump(const Duration(milliseconds: 400));
    await drag.up();
    await tester.pumpAndSettle();
    expect(controller.queue.map((song) => song.id), ['c', 'b']);
    expect(controller.currentSong?.id, 'b');
    final downward = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_handle_rounded).first),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await downward.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 500));
    await downward.moveBy(const Offset(0, 220));
    await tester.pump(const Duration(milliseconds: 400));
    await downward.up();
    await tester.pumpAndSettle();
    expect(controller.queue.map((song) => song.id), ['b', 'c']);
    expect(controller.currentSong?.id, 'b');
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty library explains local access and offers file import', (
    tester,
  ) async {
    library.songs = [];
    library.denied = true;
    await controller.initialize();
    await tester.pumpWidget(PocketMusicApp(controller: controller));
    expect(find.text('Your music, on your phone.'), findsOneWidget);
    expect(find.text('Import files'), findsWidgets);
    expect(find.text('Allow audio access'), findsOneWidget);
    expect(find.text('Pocket Music'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('search filters the library by artist', (tester) async {
    await controller.initialize();
    await tester.pumpWidget(PocketMusicApp(controller: controller));
    await tester.enterText(find.byType(TextField).first, 'Artist b');
    await tester.pump();
    expect(find.byKey(const Key('song-b')), findsOneWidget);
    expect(find.byKey(const Key('song-a')), findsNothing);
  });
  testWidgets(
    'song opens a mini-player and a full player with queue controls',
    (tester) async {
      await controller.initialize();
      await tester.pumpWidget(PocketMusicApp(controller: controller));
      await tester.tap(find.byKey(const Key('song-a')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mini-player')), findsOneWidget);
      await tester.tap(find.byKey(const Key('mini-player')));
      await tester.pumpAndSettle();
      expect(find.text('Now playing'), findsOneWidget);
      expect(find.byTooltip('Next track'), findsWidgets);
      expect(find.byTooltip('Shuffle'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Show queue').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Show queue').last);
      await tester.pumpAndSettle();
      expect(find.text('Play queue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('favorites is a usable destination', (tester) async {
    await controller.initialize();
    await controller.toggleFavorite(library.songs.first);
    await tester.pumpWidget(PocketMusicApp(controller: controller));
    await tester.tap(find.byKey(const Key('nav-favorites')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('song-a')), findsOneWidget);
    expect(find.byKey(const Key('song-b')), findsNothing);
  });
  testWidgets('creates a named playlist from the playlist destination', (
    tester,
  ) async {
    await controller.initialize();
    await tester.pumpWidget(PocketMusicApp(controller: controller));
    await tester.tap(find.byKey(const Key('nav-playlists')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create playlist'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('playlist-name')),
      'Evening walk',
    );
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Evening walk'), findsOneWidget);
    expect(controller.playlists.single.name, 'Evening walk');
  });
}
