import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/music_controller.dart';
import 'music_theme.dart';

class CoverArt extends StatelessWidget {
  const CoverArt({super.key, this.song, this.size = 52, this.round = false});
  final Song? song;
  final double size;
  final bool round;
  @override
  Widget build(BuildContext context) {
    final fallback = CustomPaint(
      painter: _RecordPainter(),
      size: Size.square(size),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(round ? size / 2 : 12),
        child: SizedBox.square(
          dimension: size,
          child: song?.artworkPath != null
              ? Image.file(
                  File(song!.artworkPath!),
                  fit: BoxFit.cover,
                  cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  errorBuilder: (_, error, stack) => fallback,
                )
              : fallback,
        ),
      ),
    );
  }
}

class _RecordPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = panel);
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, size.width * .43, Paint()..color = ink);
    final groove = Paint()
      ..color = muted.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var radius = .22; radius < .43; radius += .045) {
      canvas.drawCircle(center, size.width * radius, groove);
    }
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * .36),
      -math.pi * .8,
      math.pi * .3,
      false,
      Paint()
        ..color = muted.withValues(alpha: .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(center, size.width * .16, Paint()..color = copper);
    canvas.drawCircle(center, size.width * .04, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(_RecordPainter oldDelegate) => false;
}

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.controller,
    required this.collection,
    this.onRemove,
  });
  final Song song;
  final MusicController controller;
  final List<Song> collection;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey('swipe-${song.id}'),
    direction: DismissDirection.endToStart,
    confirmDismiss: (_) async {
      final wasIdle = controller.currentSong == null;
      await controller.addToUpNext(song);
      if (context.mounted && controller.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasIdle
                  ? 'Playing ${song.title}'
                  : 'Added ${song.title} to Up next',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return false;
    },
    background: const SizedBox.shrink(),
    secondaryBackground: Container(
      color: copper.withValues(alpha: .18),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 28),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue_music_rounded, color: copper),
          Text('Play next', style: TextStyle(color: copper)),
        ],
      ),
    ),
    child: ListTile(
      key: Key('song-${song.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CoverArt(song: song),
      selected: controller.currentSong?.id == song.id,
      selectedTileColor: copper.withValues(alpha: .04),
      title: Text(song.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: muted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (MediaQuery.sizeOf(context).width > 360)
            Text(
              timeLabel(song.duration),
              style: const TextStyle(
                color: muted,
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          SongMenu(song: song, controller: controller, onRemove: onRemove),
        ],
      ),
      onTap: () => controller.playSong(song, from: collection),
    ),
  );
}

class SongMenu extends StatelessWidget {
  const SongMenu({
    super.key,
    required this.song,
    required this.controller,
    this.onRemove,
  });
  final Song song;
  final MusicController controller;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'More options for ${song.title}',
    onSelected: (action) {
      switch (action) {
        case 'favorite':
          controller.toggleFavorite(song);
        case 'queue':
          controller.addToUpNext(song);
        case 'playlist':
          choosePlaylist(context, controller, song);
        case 'remove':
          onRemove?.call();
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem(
        value: 'favorite',
        child: Text(
          controller.favorites.contains(song.id)
              ? 'Remove from favorites'
              : 'Add to favorites',
        ),
      ),
      const PopupMenuItem(value: 'queue', child: Text('Play next')),
      const PopupMenuItem(value: 'playlist', child: Text('Add to playlist')),
      if (onRemove != null)
        const PopupMenuItem(
          value: 'remove',
          child: Text('Remove from playlist'),
        ),
    ],
  );
}

Future<String?> playlistName(BuildContext context, {String? initial}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _PlaylistNameDialog(initial: initial),
    );

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({this.initial});
  final String? initial;
  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final input = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'New playlist' : 'Rename playlist'),
    content: TextField(
      key: const Key('playlist-name'),
      controller: input,
      autofocus: true,
      maxLength: 80,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(labelText: 'Playlist name'),
      onChanged: (_) => setState(() {}),
      onSubmitted: (text) {
        if (text.trim().isNotEmpty) Navigator.pop(context, text.trim());
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: input.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, input.text.trim()),
        child: Text(widget.initial == null ? 'Create' : 'Save'),
      ),
    ],
  );
}

Future<void> choosePlaylist(
  BuildContext context,
  MusicController controller,
  Song song,
) async {
  final selected = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .65,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Add to playlist',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              for (final list in controller.playlists)
                ListTile(
                  leading: const Icon(Icons.queue_music),
                  title: Text(list.name),
                  subtitle: Text('${list.songIds.length} songs'),
                  onTap: () => Navigator.pop(context, list.id),
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Create playlist'),
                onTap: () => Navigator.pop(context, '__new__'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (selected == null || !context.mounted) return;
  if (selected == '__new__') {
    final name = await playlistName(context);
    if (name == null) return;
    await controller.createPlaylist(name);
    final list = controller.playlists
        .where((list) => list.name == name)
        .lastOrNull;
    if (list != null) await controller.addToPlaylist(list.id, song);
  } else {
    await controller.addToPlaylist(selected, song);
  }
}
