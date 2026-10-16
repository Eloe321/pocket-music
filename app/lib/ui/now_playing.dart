import 'dart:math' as math;
import 'package:flutter/material.dart' hide RepeatMode;
import '../core/music_controller.dart';
import 'music_theme.dart';
import 'song_widgets.dart';

void showPlayer(BuildContext context, MusicController controller) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => NowPlaying(controller: controller)),
  );
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.controller});
  final MusicController controller;
  @override
  Widget build(BuildContext context) {
    final song = controller.currentSong;
    if (song == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('mini-player'),
          onTap: () => showPlayer(context, controller),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: Row(
                  children: [
                    CoverArt(song: song, size: 40),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: controller.shuffleEnabled
                          ? 'Shuffle on'
                          : 'Ordered playback',
                      onPressed: controller.toggleShuffle,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 44,
                      ),
                      padding: EdgeInsets.zero,
                      iconSize: 22,
                      icon: Icon(
                        controller.shuffleEnabled
                            ? Icons.shuffle_rounded
                            : Icons.format_list_numbered_rounded,
                        color: controller.shuffleEnabled ? copper : muted,
                      ),
                    ),
                    IconButton(
                      tooltip: controller.isPlaying ? 'Pause' : 'Play',
                      onPressed: controller.togglePlayPause,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 44,
                      ),
                      padding: EdgeInsets.zero,
                      iconSize: 25,
                      icon: Icon(
                        controller.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: copper,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next track',
                      onPressed: controller.next,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 44,
                      ),
                      padding: EdgeInsets.zero,
                      iconSize: 24,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                    IconButton(
                      tooltip: 'Show queue',
                      onPressed: () => showQueue(context, controller),
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 44,
                      ),
                      padding: EdgeInsets.zero,
                      iconSize: 22,
                      icon: const Icon(Icons.queue_music_rounded),
                    ),
                  ],
                ),
              ),
              LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                value: controller.duration.inMilliseconds <= 0
                    ? 0
                    : (controller.position.inMilliseconds /
                              controller.duration.inMilliseconds)
                          .clamp(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NowPlaying extends StatefulWidget {
  const NowPlaying({super.key, required this.controller});
  final MusicController controller;
  @override
  State<NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<NowPlaying> {
  double? dragging;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final song = c.currentSong;
      final total = math.max(1.0, c.duration.inMilliseconds.toDouble());
      return Scaffold(
        appBar: AppBar(
          title: const Text('Now playing'),
          leading: IconButton(
            tooltip: 'Close player',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (song != null) SongMenu(song: song, controller: c),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, space) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    children: [
                      CoverArt(
                        song: song,
                        size: math.min(320, math.max(120, space.maxWidth - 80)),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song?.title ?? 'Queue is empty',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  song?.artist ??
                                      'Choose a song from your library',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip:
                                song != null && c.favorites.contains(song.id)
                                ? 'Remove from favorites'
                                : 'Add to favorites',
                            onPressed: song == null
                                ? null
                                : () => c.toggleFavorite(song),
                            icon: Icon(
                              song != null && c.favorites.contains(song.id)
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: copper,
                            ),
                          ),
                        ],
                      ),
                      if (c.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            c.error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 22),
                      Semantics(
                        label: 'Playback position',
                        child: Slider(
                          value:
                              (dragging ?? c.position.inMilliseconds.toDouble())
                                  .clamp(0, total),
                          min: 0,
                          max: total,
                          label: timeLabel(
                            Duration(
                              milliseconds:
                                  (dragging ??
                                          c.position.inMilliseconds.toDouble())
                                      .round(),
                            ),
                          ),
                          onChanged:
                              song == null || c.duration.inMilliseconds <= 0
                              ? null
                              : (value) => setState(() => dragging = value),
                          onChangeEnd: (value) {
                            c.seek(Duration(milliseconds: value.round()));
                            setState(() => dragging = null);
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            timeLabel(
                              Duration(
                                milliseconds:
                                    (dragging ??
                                            c.position.inMilliseconds
                                                .toDouble())
                                        .round(),
                              ),
                            ),
                            style: const TextStyle(color: muted),
                          ),
                          Text(
                            timeLabel(c.duration),
                            style: const TextStyle(color: muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            tooltip: 'Shuffle',
                            isSelected: c.shuffleEnabled,
                            color: c.shuffleEnabled ? copper : muted,
                            onPressed: song == null ? null : c.toggleShuffle,
                            icon: const Icon(Icons.shuffle_rounded),
                          ),
                          IconButton(
                            tooltip: 'Previous track',
                            iconSize: 36,
                            onPressed: song == null ? null : c.previous,
                            icon: const Icon(Icons.skip_previous_rounded),
                          ),
                          SizedBox.square(
                            dimension: 76,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: const CircleBorder(),
                              ),
                              onPressed: song == null
                                  ? null
                                  : c.togglePlayPause,
                              child: Icon(
                                c.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 40,
                                semanticLabel: c.isPlaying ? 'Pause' : 'Play',
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Next track',
                            iconSize: 36,
                            onPressed: song == null ? null : c.next,
                            icon: const Icon(Icons.skip_next_rounded),
                          ),
                          IconButton(
                            tooltip: 'Repeat: ${c.repeatMode.name}',
                            color: c.repeatMode == RepeatMode.off
                                ? muted
                                : copper,
                            onPressed: song == null ? null : c.cycleRepeat,
                            icon: Icon(
                              c.repeatMode == RepeatMode.one
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          const Icon(
                            Icons.album_outlined,
                            size: 16,
                            color: muted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              song?.album ?? 'Local music',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: muted),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Show queue',
                            onPressed: () => showQueue(context, c),
                            icon: const Icon(
                              Icons.queue_music_rounded,
                              color: copper,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> showQueue(
  BuildContext context,
  MusicController c,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Play queue',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (c.isPlayingUpNext || c.upNext.isNotEmpty)
                          const Text(
                            'Up next plays before the normal queue',
                            style: TextStyle(color: muted),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close queue',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (c.isPlayingUpNext || c.upNext.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    c.upNext.isEmpty
                        ? 'Up next'
                        : 'Up next · ${c.upNext.length} waiting',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              if (c.activeUpNextSong case final active?)
                ListTile(
                  selected: true,
                  leading: CoverArt(song: active, size: 44),
                  title: Text(
                    active.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text('Playing from Up next'),
                ),
              if (c.upNext.isNotEmpty)
                SizedBox(
                  height: math.min(220.0, c.upNext.length * 72.0),
                  child: ReorderableListView.builder(
                    itemCount: c.upNext.length,
                    buildDefaultDragHandles: false,
                    onReorderItem: (oldIndex, newIndex) => c.reorderUpNext(
                      oldIndex,
                      newIndex > oldIndex ? newIndex + 1 : newIndex,
                    ),
                    itemBuilder: (context, index) {
                      final song = c.upNext[index];
                      return ListTile(
                        key: ValueKey('up-next-${song.id}-$index'),
                        leading: CoverArt(song: song, size: 44),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Remove ${song.title} from Up next',
                              onPressed: () => c.removeFromUpNext(index),
                              icon: const Icon(Icons.close_rounded, size: 20),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(Icons.drag_handle_rounded),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const Divider(height: 12),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Normal queue · ${c.queue.length} songs',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            if (c.queue.isEmpty)
              const Expanded(
                child: Center(child: Text('Add a song to start your queue.')),
              )
            else
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: c.queue.length,
                  onReorderItem: (oldIndex, newIndex) => c.reorderQueue(
                    oldIndex,
                    newIndex > oldIndex ? newIndex + 1 : newIndex,
                  ),
                  buildDefaultDragHandles: false,
                  itemBuilder: (context, index) {
                    final song = c.queue[index];
                    return ListTile(
                      key: ValueKey('queue-${song.id}-$index'),
                      selected: !c.isPlayingUpNext && index == c.currentIndex,
                      leading: CoverArt(song: song, size: 44),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () =>
                          c.playQueue(List.of(c.queue), startIndex: index),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Remove ${song.title} from queue',
                            onPressed: () => c.removeFromQueue(index),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(
                                Icons.drag_handle_rounded,
                                semanticLabel: 'Drag to reorder',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  ),
);
