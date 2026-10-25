import 'dart:async';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'ports.dart';
import 'platform_library.dart' show isLocalMediaPath;

/// A local-file adapter. Queue order remains in MusicController so notification
/// actions use the same repeat, shuffle and playlist behavior as the app.
class AssetsPlayback implements PlaybackPort, RemotePlaybackPort {
  AssetsPlayback({AssetsAudioPlayer? player})
    : _player = player ?? AssetsAudioPlayer.newPlayer() {
    // Keep Android's foreground service alive between app-owned queue items.
    // The controller explicitly stops it when the queue has no next song.
    _player.autoStopAtPlaylistEnd = false;
    _subscriptions.add(
      _player.isPlaying.listen((playing) {
        if (_hasTrack && !_opening) _emit(PlaybackEvent(isPlaying: playing));
      }, onError: _streamError),
    );
    _subscriptions.add(
      _player.currentPosition.listen((position) {
        if (_hasTrack && !_opening) _emit(PlaybackEvent(position: position));
      }, onError: _streamError),
    );
    _subscriptions.add(
      _player.onReadyToPlay.listen((audio) {
        if (_hasTrack && audio != null) {
          _emit(PlaybackEvent(duration: audio.duration));
        }
      }, onError: _streamError),
    );
    _player.onPlaylistFinished = () async {
      if (_hasTrack && !_opening) _emit(const PlaybackEvent(completed: true));
    };
    _player.onErrorDo = (_) {
      _openingError = StateError(_playbackError);
      _emit(const PlaybackEvent(error: _playbackError, isPlaying: false));
      if (!_opening) unawaited(_player.stop().catchError((Object _) {}));
    };
  }
  static const _playbackError =
      'This song could not be played. Check that the file is still available.';
  final AssetsAudioPlayer _player;
  final _events = StreamController<PlaybackEvent>.broadcast(sync: true);
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Future<void> Function()? _next, _previous, _toggle, _stop, _play, _pause;
  bool _disposed = false, _opening = false, _hasTrack = false;
  Object? _openingError;

  @override
  Stream<PlaybackEvent> get changes => _events.stream;
  void _emit(PlaybackEvent event) {
    if (!_disposed) _events.add(event);
  }

  void _streamError(Object error) =>
      _emit(const PlaybackEvent(error: _playbackError, isPlaying: false));
  void _remote(
    Future<void> Function()? action,
    Future<void> Function() fallback,
  ) {
    if (_disposed) return;
    unawaited(
      Future<void>.sync(
        action ?? fallback,
      ).catchError((Object error) => _streamError(error)),
    );
  }

  @override
  void bindRemoteControls({
    Future<void> Function()? play,
    Future<void> Function()? pause,
    required Future<void> Function() next,
    required Future<void> Function() previous,
    required Future<void> Function() toggle,
    required Future<void> Function() stop,
  }) {
    _play = play;
    _pause = pause;
    _next = next;
    _previous = previous;
    _toggle = toggle;
    _stop = stop;
  }

  @override
  Future<void> open(
    Song song, {
    required bool autoStart,
    required Duration position,
  }) async {
    if (!isLocalMediaPath(song.path)) {
      throw ArgumentError('Only local media files are supported');
    }
    if (_disposed) return;
    _opening = true;
    _hasTrack = true;
    _openingError = null;
    try {
      await _player.open(
        Audio.file(
          song.path,
          metas: Metas(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            image:
                song.artworkPath != null && isLocalMediaPath(song.artworkPath!)
                ? MetasImage.file(song.artworkPath!)
                : null,
          ),
        ),
        autoStart: autoStart,
        seek: position,
        showNotification: true,
        playInBackground: PlayInBackground.enabled,
        headPhoneStrategy: HeadPhoneStrategy.pauseOnUnplug,
        // Android can mix two media streams when we do not claim exclusive
        // audio focus. iOS keeps its existing interruption behavior.
        audioFocusStrategy: defaultTargetPlatform == TargetPlatform.android
            ? AudioFocusStrategy.none()
            : const AudioFocusStrategy.request(resumeAfterInterruption: true),
        loopMode: LoopMode.none,
        notificationSettings: NotificationSettings(
          nextEnabled: true,
          prevEnabled: true,
          playPauseEnabled: true,
          stopEnabled: false,
          seekBarEnabled: true,
          customNextAction: (_) => _remote(_next, () async {}),
          customPrevAction: (_) => _remote(_previous, () async {}),
          customPlayPauseAction: (_) => _remote(_toggle, _player.playOrPause),
          customPlayAction: (_) => _remote(_play, _player.play),
          customPauseAction: (_) => _remote(_pause, _player.pause),
          customStopAction: (_) => _remote(_stop, _player.stop),
        ),
      );
      // The upstream plugin reports PlatformException through onErrorDo instead
      // of throwing it. Convert it back to a failed command for the controller.
      if (_openingError != null) {
        await _player.stop();
        throw StateError(_playbackError);
      }
      _emit(PlaybackEvent(position: position, isPlaying: autoStart));
    } catch (_) {
      _hasTrack = false;
      rethrow;
    } finally {
      _opening = false;
    }
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() async {
    _hasTrack = false;
    await _player.stop();
    _emit(const PlaybackEvent(isPlaying: false));
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _player.onPlaylistFinished = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    try {
      await _player.dispose();
    } finally {
      await _events.close();
    }
  }
}
