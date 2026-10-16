import 'package:flutter/material.dart';
import '../core/music_controller.dart';
import 'music_theme.dart';
import 'song_widgets.dart';

class PlaylistSongPicker extends StatefulWidget {
  const PlaylistSongPicker({
    super.key,
    required this.controller,
    required this.playlistId,
  });
  final MusicController controller;
  final String playlistId;

  @override
  State<PlaylistSongPicker> createState() => _PlaylistSongPickerState();
}

class _PlaylistSongPickerState extends State<PlaylistSongPicker> {
  final search = TextEditingController();
  final selected = <String>{};
  String query = '';
  bool saving = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final playlist = controller.playlists
          .where((list) => list.id == widget.playlistId)
          .firstOrNull;
      final existing = playlist?.songIds.toSet() ?? <String>{};
      final filtered = controller.songs.where((song) {
        final needle = query.trim().toLowerCase();
        return needle.isEmpty ||
            song.title.toLowerCase().contains(needle) ||
            song.artist.toLowerCase().contains(needle) ||
            song.album.toLowerCase().contains(needle);
      }).toList();
      return Scaffold(
        appBar: AppBar(
          title: const Text('Add songs'),
          actions: [
            TextButton(
              onPressed: selected.isEmpty || saving || playlist == null
                  ? null
                  : () async {
                      setState(() => saving = true);
                      await controller.addSongsToPlaylist(
                        widget.playlistId,
                        controller.songs.where(
                          (song) => selected.contains(song.id),
                        ),
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
              child: Text(
                selected.isEmpty
                    ? 'Add to playlist'
                    : 'Add ${selected.length} to playlist',
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: TextField(
                key: const Key('playlist-song-search'),
                controller: search,
                onChanged: (value) => setState(() => query = value),
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, albums',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            search.clear();
                            setState(() => query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${selected.length} selected · ${controller.songs.length} songs',
                  style: const TextStyle(color: muted),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No songs match your search.'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final song = filtered[index];
                        final alreadyAdded = existing.contains(song.id);
                        return CheckboxListTile(
                          key: Key('playlist-select-${song.id}'),
                          value: alreadyAdded || selected.contains(song.id),
                          onChanged: alreadyAdded
                              ? null
                              : (_) => setState(() {
                                  if (!selected.add(song.id)) {
                                    selected.remove(song.id);
                                  }
                                }),
                          secondary: CoverArt(song: song, size: 44),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            alreadyAdded ? 'Already in playlist' : song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );
}
