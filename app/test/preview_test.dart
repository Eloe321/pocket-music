import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_music/core/music_controller.dart';
import 'package:pocket_music/player_app.dart';
import 'core/music_controller_test.dart' as fixtures;

void main() {
  testWidgets('phone layout renders library and player without overflow', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final fonts = Directory('test/fonts');
      final text = FontLoader('Roboto');
      for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
        text.addFont(
          File('${fonts.path}/$name').readAsBytes().then(ByteData.sublistView),
        );
      }
      await text.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            '${fonts.path}/MaterialIcons-Regular.otf',
          ).readAsBytes().then(ByteData.sublistView),
        );
      await icons.load();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final library = fixtures.FakeLibrary()
      ..songs = const [
        Song(
          id: 'a',
          path: '/a.mp3',
          title: 'After the rain',
          artist: 'Juniper',
          album: 'Nightside',
          duration: Duration(minutes: 3, seconds: 42),
        ),
        Song(
          id: 'b',
          path: '/b.mp3',
          title: 'Somewhere, slowly',
          artist: 'The Quiet Hours',
          album: 'Room to breathe',
          duration: Duration(minutes: 4, seconds: 18),
        ),
        Song(
          id: 'c',
          path: '/c.mp3',
          title: 'Side streets',
          artist: 'Juniper',
          album: 'Nightside',
          duration: Duration(minutes: 2, seconds: 56),
        ),
        Song(
          id: 'd',
          path: '/d.mp3',
          title: 'A little longer',
          artist: 'Low Tide',
          album: 'Blue hour',
          duration: Duration(minutes: 3, seconds: 25),
        ),
      ];
    final c = MusicController(
      library: library,
      playback: fixtures.FakePlayback(),
      store: fixtures.MemoryStore(),
    );
    await c.initialize();
    final capture = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: PocketMusicApp(controller: c),
      ),
    );
    await tester.tap(find.byKey(const Key('song-a')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Future<void> screenshot(String name) async {
      await tester.runAsync(() async {
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/previews/$name.fresh');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        await file.rename('build/previews/$name');
        image.dispose();
      });
    }

    await screenshot('pocket-music-library.png');
    final mini = tester.getRect(find.byKey(const Key('mini-player')));
    await tester.tapAt(mini.topLeft + const Offset(30, 30));
    await tester.pumpAndSettle();
    expect(find.text('Now playing'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await screenshot('pocket-music-player.png');
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
}
