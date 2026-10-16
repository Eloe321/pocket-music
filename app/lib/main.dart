import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/music_controller.dart';
import 'core/platform_library.dart';
import 'core/json_state_store.dart';
import 'core/assets_playback.dart';
import 'player_app.dart';
export 'player_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF101B2D),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final controller = MusicController(
    library: PlatformLibrary(),
    playback: AssetsPlayback(),
    store: JsonStateStore(),
  );
  runApp(PocketMusicApp(controller: controller));
  unawaited(controller.initialize());
}
