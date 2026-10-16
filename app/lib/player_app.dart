import 'package:flutter/material.dart';
import 'core/music_controller.dart';
import 'ui/library_screen.dart';
import 'ui/music_theme.dart';

class PocketMusicApp extends StatelessWidget {
  const PocketMusicApp({super.key, required this.controller});
  final MusicController controller;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pocket Music',
    debugShowCheckedModeBanner: false,
    theme: musicTheme(),
    home: LibraryScreen(controller: controller),
  );
}
