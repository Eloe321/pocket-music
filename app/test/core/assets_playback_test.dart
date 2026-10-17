import 'dart:async';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_music/core/assets_playback.dart';
import 'package:pocket_music/core/models.dart';
import 'package:pocket_music/core/ports.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('assets_audio_player');
  const local = Song(
    id: 'a',
    path: 'content://media/external/audio/media/4',
    title: 'Title',
    artist: 'Artist',
    album: 'Album',
    duration: Duration(seconds: 90),
  );
  late AssetsAudioPlayer player;
  late AssetsPlayback adapter;
  late List<MethodCall> calls;
  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    player = AssetsAudioPlayer.newPlayer();
    adapter = AssetsPlayback(player: player);
  });
  tearDown(() async {
    await adapter.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  Future<void> native(String method, dynamic arguments) async {
    final done = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'assets_audio_player/${player.id}',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, arguments),
          ),
          (_) => done.complete(),
        );
    await done.future;
  }

  test(
    'opens content URI with metadata notification background and seek',
    () async {
      await adapter.open(
        local,
        autoStart: true,
        position: const Duration(seconds: 12),
      );
      final args =
          calls.singleWhere((call) => call.method == 'open').arguments as Map;
      expect(args['path'], local.path);
      expect(args['audioType'], 'file');
      expect(args['seek'], 12000);
      expect(args['displayNotification'], isTrue);
      expect(args['headPhoneStrategy'], 'pauseOnUnplug');
      expect((args['audioFocusStrategy'] as Map)['request'], isFalse);
      expect(args['song.title'], 'Title');
    },
  );
  test('rejects network URLs before calling native player', () async {
    const remote = Song(
      id: 'x',
      path: 'https://example.com/a.mp3',
      title: 'x',
      artist: 'x',
      album: 'x',
      duration: Duration.zero,
    );
    await expectLater(
      adapter.open(remote, autoStart: true, position: Duration.zero),
      throwsArgumentError,
    );
    expect(calls.where((call) => call.method == 'open'), isEmpty);
  });
  test('native open error becomes recoverable playback failure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'open') throw PlatformException(code: 'missing');
          return null;
        });
    await expectLater(
      adapter.open(local, autoStart: true, position: Duration.zero),
      throwsStateError,
    );
  });
  test('notification next calls app queue handler', () async {
    var next = 0;
    adapter.bindRemoteControls(
      next: () async {
        next++;
      },
      previous: () async {},
      toggle: () async {},
      stop: () async {},
    );
    await adapter.open(local, autoStart: true, position: Duration.zero);
    await native('player.next', null);
    expect(next, 1);
  });
  test('native position and completion feed controller events', () async {
    final events = <PlaybackEvent>[];
    final subscription = adapter.changes.listen(events.add);
    await adapter.open(local, autoStart: true, position: Duration.zero);
    await native('player.current', {'totalDurationMs': 90000});
    await native('player.position', 21000);
    await native('player.current', null);
    expect(events.where((event) => event.completed), isEmpty);
    await native('player.finished', null);
    await Future<void>.delayed(Duration.zero);
    expect(
      events.any((event) => event.position == const Duration(seconds: 21)),
      isTrue,
    );
    expect(events.any((event) => event.completed), isTrue);
    expect(events.where((event) => event.completed).length, 1);
    await subscription.cancel();
  });
  test(
    'completion is emitted after the old native player has stopped',
    () async {
      final atCompletion = <String>[];
      final subscription = adapter.changes.listen((event) {
        if (event.completed) atCompletion.add(calls.last.method);
      });
      await adapter.open(local, autoStart: true, position: Duration.zero);
      await native('player.current', {'totalDurationMs': 90000});
      await native('player.finished', null);
      expect(atCompletion, ['stop']);
      await subscription.cancel();
    },
  );
}
