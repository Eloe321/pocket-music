import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_music/core/models.dart';
import 'package:pocket_music/core/platform_library.dart';
import 'package:pocket_music/core/json_state_store.dart';
import 'package:pocket_music/core/ports.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pocket_music/library');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('native library normalizes metadata and permission response', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'scan');
          expect(call.arguments, {'requestPermission': false});
          return {
            'permissionDenied': true,
            'songs': [
              {
                'id': 5,
                'path': 'content://media/5',
                'title': '',
                'artist': '<unknown>',
                'album': 'Local',
                'durationMs': 9000,
              },
            ],
          };
        });
    final result = await PlatformLibrary().scan(requestPermission: false);
    expect(result.permissionDenied, isTrue);
    expect(result.songs.single.id, '5');
    expect(result.songs.single.title, 'Unknown title');
    expect(result.songs.single.artist, 'Unknown artist');
    expect(result.songs.single.duration.inSeconds, 9);
  });

  test('native library excludes remote media and malformed entries', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => [
            {'id': 'remote', 'path': 'https://example.com/song.mp3'},
            {'id': 'bad'},
            {'id': 'local', 'path': '/safe/song.mp3', 'title': 'Local'},
          ],
        );
    final result = await PlatformLibrary().importFiles();
    expect(result.map((s) => s.id), ['local']);
  });

  test(
    'partial native import retains completed local songs and failure count',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(
              code: 'partial_import',
              details: {
                'songs': [
                  {'id': 'done', 'path': '/local/done.mp3', 'title': 'Done'},
                  {'id': 'remote', 'path': 'https://example.com/no.mp3'},
                ],
                'failedCount': 2,
              },
            );
          });
      await expectLater(
        PlatformLibrary().importFiles(),
        throwsA(
          isA<PartialImportException>()
              .having((error) => error.failedCount, 'failedCount', 2)
              .having(
                (error) => error.songs.map((song) => song.id).toList(),
                'completed songs',
                ['done'],
              ),
        ),
      );
    },
  );

  test(
    'unrelated native import errors preserve their platform error code',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: 'import_failed');
          });
      await expectLater(
        PlatformLibrary().importFiles(),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'import_failed',
          ),
        ),
      );
    },
  );

  test('cancelled native import returns an empty selection', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    expect(await PlatformLibrary().importFiles(), isEmpty);
  });

  test(
    'JSON state is replaced atomically and survives new store instance',
    () async {
      final dir = await Directory.systemTemp.createTemp('pocket_music_test');
      try {
        final store = JsonStateStore(directory: dir);
        expect(await store.read(), isNull);
        await store.write({
          'version': 1,
          'songs': [
            const Song(
              id: 'a',
              path: '/a.mp3',
              title: 'Song',
              artist: 'Artist',
              album: 'Album',
              duration: Duration(seconds: 1),
            ).toJson(),
          ],
        });
        await store.write({
          'version': 1,
          'favorites': ['a'],
        });
        expect(await JsonStateStore(directory: dir).read(), {
          'version': 1,
          'favorites': ['a'],
        });
        expect(dir.listSync().whereType<File>().length, 1);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  test('corrupt JSON surfaces a readable recoverable storage error', () async {
    final dir = await Directory.systemTemp.createTemp('pocket_music_corrupt');
    try {
      await File('${dir.path}/pocket_music.json').writeAsString('{broken');
      await expectLater(
        JsonStateStore(directory: dir).read(),
        throwsFormatException,
      );
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
