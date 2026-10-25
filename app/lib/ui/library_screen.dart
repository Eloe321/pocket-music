import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/music_controller.dart';
import 'music_theme.dart';
import 'song_widgets.dart';
import 'now_playing.dart';
import 'playlist_song_picker.dart';
import 'indexed_song_list.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.controller});
  final MusicController controller;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with WidgetsBindingObserver {
  int destination = 0;
  int category = 0;
  final search = TextEditingController();
  List<Song> _sourceSongs = [], _orderedSongs = [];
  MusicController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && c.permissionDenied && !c.isBusy) {
      c.scan(requestPermission: false);
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(c.saveState());
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final source = c.songs;
      if (!sameSongInstances(source, _sourceSongs)) {
        _sourceSongs = source;
        _orderedSongs = alphabetizeSongs(source);
      }
      final favorites = c.favorites;
      final parent = destination == 1
          ? _orderedSongs.where((song) => favorites.contains(song.id)).toList()
          : _orderedSongs;
      final query = c.searchQuery.trim().toLowerCase();
      final visible = query.isEmpty
          ? parent
          : parent
                .where(
                  (song) => '${song.title} ${song.artist} ${song.album}'
                      .toLowerCase()
                      .contains(query),
                )
                .toList();
      return Scaffold(
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.album_rounded, color: copper),
              SizedBox(width: 10),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Pocket Music',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Import files',
              onPressed: c.isBusy ? null : c.importFiles,
              icon: const Icon(Icons.add_rounded),
            ),
            PopupMenuButton<String>(
              tooltip: 'Library options',
              onSelected: (item) {
                if (item == 'refresh') c.scan(requestPermission: false);
                if (item == 'settings') c.openSettings();
                if (item == 'privacy') {
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Made for your music'),
                      content: const Text(
                        'Your library, playlists, favorites, and imported files stay on this phone. No account, ads, analytics, or cloud sync.\n\nOriginal files are never deleted. Imported copies are removed if you uninstall the app.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: Text('Refresh library'),
                ),
                const PopupMenuItem(value: 'privacy', child: Text('Privacy')),
                const PopupMenuItem(
                  value: 'settings',
                  child: Text('Open app settings'),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (c.isBusy) const LinearProgressIndicator(minHeight: 2),
            if (c.error != null)
              MaterialBanner(
                content: Text(c.error!),
                actions: [
                  TextButton(
                    onPressed: () => c.scan(requestPermission: false),
                    child: const Text('Retry'),
                  ),
                  TextButton(
                    onPressed: c.clearError,
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            if (destination != 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 10),
                child: TextField(
                  key: const Key('library-search'),
                  controller: search,
                  onChanged: c.setSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Search songs, artists, albums',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              search.clear();
                              c.setSearchQuery('');
                            },
                          ),
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => c.scan(requestPermission: false),
                child: _libraryBody(context, visible, parent),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MiniPlayer(controller: c),
            NavigationBar(
              selectedIndex: destination,
              onDestinationSelected: (value) => setState(() {
                destination = value;
              }),
              destinations: const [
                NavigationDestination(
                  key: Key('nav-library'),
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music_rounded),
                  label: 'Library',
                ),
                NavigationDestination(
                  key: Key('nav-favorites'),
                  icon: Icon(Icons.favorite_border_rounded),
                  selectedIcon: Icon(Icons.favorite_rounded),
                  label: 'Favorites',
                ),
                NavigationDestination(
                  key: Key('nav-playlists'),
                  icon: Icon(Icons.queue_music_rounded),
                  label: 'Playlists',
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  Widget _libraryBody(
    BuildContext context,
    List<Song> visible,
    List<Song> parent,
  ) {
    final header = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      [
                        'Your library',
                        'Your favorites',
                        'Your playlists',
                      ][destination],
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                ),
                if (destination == 2) ...[
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    tooltip: 'Create playlist',
                    onPressed: () async {
                      final name = await playlistName(context);
                      if (name != null) {
                        await c.createPlaylist(name);
                      }
                    },
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              destination == 2
                  ? '${c.playlists.length} playlists · saved on this phone'
                  : '${parent.length} songs · all yours',
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 22),
            if (destination == 0)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < 3; i++)
                      ChoiceChip(
                        label: Text(['Songs', 'Albums', 'Artists'][i]),
                        selected: category == i,
                        onSelected: (_) => setState(() => category = i),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      if (destination == 2)
        ..._playlists(context)
      else if (c.songs.isEmpty)
        _emptyLibrary(context)
      else if (visible.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
          child: Column(
            children: [
              Icon(
                destination == 1 ? Icons.favorite_border : Icons.search_off,
                color: muted,
                size: 42,
              ),
              const SizedBox(height: 16),
              Text(
                c.searchQuery.isNotEmpty
                    ? 'No songs match your search.'
                    : 'Keep your favorites close.',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                c.searchQuery.isNotEmpty
                    ? 'Try a song title, artist, or album.'
                    : 'Open a song’s menu and add it to favorites.',
                style: const TextStyle(color: muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
      else ...[
        if (c.permissionDenied && destination == 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Card(
              color: panel,
              child: ListTile(
                title: const Text('Showing saved music'),
                subtitle: const Text(
                  'Allow audio access to refresh device songs.',
                ),
                trailing: TextButton(
                  onPressed: () => c.scan(),
                  child: const Text('Allow'),
                ),
              ),
            ),
          ),
        if (destination == 1 || category == 0) ...[
          _playActions(parent),
        ] else
          ..._groups(context, visible),
      ],
    ];
    if (destination != 2 &&
        visible.isNotEmpty &&
        (destination == 1 || category == 0)) {
      return IndexedSongList(
        key: ValueKey('songs-$destination'),
        scrollKey: const Key('library-song-scroll'),
        controller: c,
        songs: visible,
        collection: parent,
        showAlphabet: destination == 0 && c.searchQuery.trim().isEmpty,
        header: Column(children: header),
      );
    }
    return ListView(
      key: const Key('library-song-scroll'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      children: header,
    );
  }

  Widget _playActions(List<Song> songs) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final play = FilledButton.icon(
          onPressed: () => c.playQueue(songs),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Play all'),
        );
        final shuffle = OutlinedButton.icon(
          onPressed: () async {
            if (!c.shuffleEnabled) await c.toggleShuffle();
            await c.playQueue(songs);
          },
          icon: const Icon(Icons.shuffle_rounded),
          label: const Text('Shuffle'),
        );
        final minimumButtonWidth =
            MediaQuery.textScalerOf(context).scale(14) * 5 + 72;
        if (constraints.maxWidth < minimumButtonWidth * 2 + 12) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [play, const SizedBox(height: 8), shuffle],
          );
        }
        return Row(
          children: [
            Expanded(child: play),
            const SizedBox(width: 12),
            Expanded(child: shuffle),
          ],
        );
      },
    ),
  );

  Widget _emptyLibrary(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
    child: Column(
      children: [
        const CoverArt(size: 112),
        const SizedBox(height: 24),
        Text(
          'Your music, on your phone.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          defaultTargetPlatform == TargetPlatform.iOS
              ? 'Import audio from Files to build your private library.'
              : 'Find music already on your device, or import a few files to get started.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 24),
        if (c.permissionDenied &&
            defaultTargetPlatform != TargetPlatform.iOS) ...[
          FilledButton.icon(
            onPressed: c.isBusy ? null : () => c.scan(),
            icon: const Icon(Icons.library_music_outlined),
            label: const Text('Allow audio access'),
          ),
          TextButton(
            onPressed: c.openSettings,
            child: const Text('Open app settings'),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: c.isBusy ? null : c.importFiles,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Import files'),
        ),
        const SizedBox(height: 16),
        const Text(
          'No accounts. No uploads. Just press play.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    ),
  );

  List<Widget> _groups(BuildContext context, List<Song> songs) {
    final visibleNames = songs
        .map((song) => category == 1 ? song.album : song.artist)
        .toSet();
    final groups = <String, List<Song>>{};
    for (final song in _orderedSongs) {
      groups
          .putIfAbsent(category == 1 ? song.album : song.artist, () => [])
          .add(song);
    }
    return groups.entries
        .where((entry) => visibleNames.contains(entry.key))
        .map(
          (entry) => ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 8,
            ),
            leading: CoverArt(
              song: entry.value.first,
              size: 60,
              round: category == 2,
            ),
            title: Text(entry.key),
            subtitle: Text(
              '${entry.value.length} songs',
              style: const TextStyle(color: muted),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: muted),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CollectionPage(
                  controller: c,
                  title: entry.key,
                  songs: entry.value,
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  List<Widget> _playlists(BuildContext context) => c.playlists.isEmpty
      ? [
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'A place for every mood.\nCreate a playlist, then add songs together.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, height: 1.8),
            ),
          ),
        ]
      : c.playlists
            .map(
              (list) => ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                leading: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.queue_music_rounded, color: copper),
                ),
                title: Text(list.name),
                subtitle: Text(
                  '${c.songsForPlaylist(list.id).length} songs',
                  style: const TextStyle(color: muted),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: muted),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CollectionPage(
                      controller: c,
                      title: list.name,
                      playlistId: list.id,
                    ),
                  ),
                ),
              ),
            )
            .toList();
}

class CollectionPage extends StatefulWidget {
  const CollectionPage({
    super.key,
    required this.controller,
    required this.title,
    this.songs = const [],
    this.playlistId,
  });
  final MusicController controller;
  final String title;
  final List<Song> songs;
  final String? playlistId;
  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  final search = TextEditingController();
  String query = '';
  MusicController get controller => widget.controller;
  String get title => widget.title;
  String? get playlistId => widget.playlistId;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      final list = c.playlists
          .where((list) => list.id == playlistId)
          .firstOrNull;
      final collectionIds = widget.songs.map((song) => song.id).toSet();
      final collection = playlistId == null
          ? c.songs.where((song) => collectionIds.contains(song.id)).toList()
          : c.songsForPlaylist(playlistId!);
      final searchQuery = query.trim().toLowerCase();
      final visible = searchQuery.isEmpty
          ? collection
          : collection
                .where(
                  (song) => '${song.title} ${song.artist} ${song.album}'
                      .toLowerCase()
                      .contains(searchQuery),
                )
                .toList();
      return Scaffold(
        appBar: AppBar(
          title: Text(list?.name ?? title),
          actions: [
            if (list != null)
              PopupMenuButton<String>(
                tooltip: 'Playlist options',
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Rename playlist'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete playlist'),
                  ),
                ],
                onSelected: (action) async {
                  if (action == 'rename') {
                    final name = await playlistName(
                      context,
                      initial: list.name,
                    );
                    if (name != null) await c.renamePlaylist(list.id, name);
                  } else if (action == 'delete') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete playlist?'),
                        content: const Text(
                          'Your music files will stay on this phone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await c.deletePlaylist(list.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  }
                },
              ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 10),
              child: TextField(
                key: const Key('collection-search'),
                controller: search,
                onChanged: (value) => setState(() => query = value),
                decoration: InputDecoration(
                  hintText: 'Search this collection',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            search.clear();
                            setState(() => query = '');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: IndexedSongList(
                scrollKey: const Key('collection-song-scroll'),
                controller: c,
                songs: visible,
                collection: collection,
                onRemove: list == null
                    ? null
                    : (song) => c.removeFromPlaylist(list.id, song.id),
                header: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          CoverArt(song: collection.firstOrNull, size: 170),
                          const SizedBox(height: 18),
                          Text(
                            '${collection.length} songs',
                            style: const TextStyle(color: muted),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: collection.isEmpty
                                    ? null
                                    : () => c.playQueue(collection),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Play'),
                              ),
                              OutlinedButton.icon(
                                onPressed: collection.isEmpty
                                    ? null
                                    : () async {
                                        if (!c.shuffleEnabled) {
                                          await c.toggleShuffle();
                                        }
                                        await c.playQueue(collection);
                                      },
                                icon: const Icon(Icons.shuffle_rounded),
                                label: const Text('Shuffle'),
                              ),
                              if (list != null)
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => PlaylistSongPicker(
                                        controller: c,
                                        playlistId: list.id,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Add songs'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (collection.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Use Add songs to build this playlist.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted),
                        ),
                      ),
                    if (collection.isNotEmpty && visible.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No songs match your search.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: MiniPlayer(controller: c),
        ),
      );
    },
  );
}
