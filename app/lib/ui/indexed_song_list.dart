import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/music_controller.dart';
import 'music_theme.dart';
import 'song_widgets.dart';

const songAlphabet = [
  '#',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
];

final _latinInitials = <String, String>{
  for (final entry in {
    'A': 'ÀÁÂÃÄÅĀĂĄǍẠẢẤẦẨẪẬẮẰẲẴẶÆ',
    'C': 'ÇĆĈĊČ',
    'D': 'ÐĎĐ',
    'E': 'ÈÉÊËĒĔĖĘĚẸẺẼẾỀỂỄỆ',
    'G': 'ĜĞĠĢ',
    'H': 'ĤĦ',
    'I': 'ÌÍÎÏĨĪĬĮİǏỈỊ',
    'J': 'Ĵ',
    'K': 'Ķ',
    'L': 'ĹĻĽĿŁ',
    'N': 'ÑŃŅŇŊ',
    'O': 'ÒÓÔÕÖØŌŎŐǑỌỎỐỒỔỖỘỚỜỞỠỢŒ',
    'R': 'ŔŖŘ',
    'S': 'ŚŜŞŠȘẞß',
    'T': 'ŢŤŦȚ',
    'U': 'ÙÚÛÜŨŪŬŮŰŲǓỤỦỨỪỬỮỰ',
    'W': 'ŴẀẂẄ',
    'Y': 'ÝŶŸỲỴỶỸ',
    'Z': 'ŹŻŽ',
  }.entries)
    for (final rune in entry.value.runes) String.fromCharCode(rune): entry.key,
};
final _combiningMarks = RegExp('[\u0300-\u036f]');

String _titleKey(String title) => title
    .trim()
    .toUpperCase()
    .runes
    .map(
      (rune) =>
          _latinInitials[String.fromCharCode(rune)] ??
          String.fromCharCode(rune),
    )
    .join()
    .replaceAll(_combiningMarks, '');

String _initial(String normalizedTitle) {
  if (normalizedTitle.isEmpty) return '#';
  final first = normalizedTitle.codeUnitAt(0);
  return first >= 65 && first <= 90 ? normalizedTitle[0] : '#';
}

String songInitial(String title) => _initial(_titleKey(title));

List<Song> alphabetizeSongs(List<Song> songs) {
  final keyed = [
    for (final song in songs) (song: song, title: _titleKey(song.title)),
  ];
  keyed.sort((a, b) {
    final section = songAlphabet
        .indexOf(_initial(a.title))
        .compareTo(songAlphabet.indexOf(_initial(b.title)));
    if (section != 0) return section;
    final title = a.title.compareTo(b.title);
    if (title != 0) return title;
    return a.song.id.compareTo(b.song.id);
  });
  return [for (final entry in keyed) entry.song];
}

// Song equality only checks id. A refreshed song's title can change its section.
bool sameSongInstances(List<Song> a, List<Song> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!identical(a[i], b[i])) return false;
  }
  return true;
}

class IndexedSongList extends StatefulWidget {
  const IndexedSongList({
    super.key,
    required this.scrollKey,
    required this.controller,
    required this.header,
    required this.songs,
    required this.collection,
    this.showAlphabet = false,
    this.onRemove,
  });

  final Key scrollKey;
  final MusicController controller;
  final Widget header;
  final List<Song> songs;
  final List<Song> collection;
  final bool showAlphabet;
  final void Function(Song)? onRemove;

  @override
  State<IndexedSongList> createState() => _IndexedSongListState();
}

class _IndexedSongListState extends State<IndexedSongList> {
  final _scroll = ScrollController();
  final _header = GlobalKey();
  Map<String, int> _firstByLetter = {};
  Map<String, int> _indexById = {};
  String? _activeLetter;
  int? _pointer;
  double _fingerY = 0;

  @override
  void initState() {
    super.initState();
    _indexSongs();
  }

  @override
  void didUpdateWidget(IndexedSongList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!sameSongInstances(oldWidget.songs, widget.songs)) {
      _indexSongs();
      _activeLetter = null;
      _pointer = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
  }

  void _indexSongs() {
    _firstByLetter = {};
    _indexById = {};
    for (var i = 0; i < widget.songs.length; i++) {
      _firstByLetter.putIfAbsent(songInitial(widget.songs[i].title), () => i);
      _indexById[widget.songs[i].id] = i;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double _rowExtent(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return math.max(88, scaler.scale(16) * 3 + scaler.scale(14) * 1.5 + 16);
  }

  void _jumpTo(String letter) {
    final index = _firstByLetter[letter];
    if (index == null || !_scroll.hasClients) return;
    final headerHeight = _header.currentContext?.size?.height ?? 0;
    final offset = headerHeight + index * _rowExtent(context);
    _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
  }

  void _selectAt(Offset position, double railHeight) {
    final index = (position.dy / railHeight * songAlphabet.length)
        .floor()
        .clamp(0, songAlphabet.length - 1);
    final letter = songAlphabet[index];
    if (!_firstByLetter.containsKey(letter)) return;
    if (letter != _activeLetter) _jumpTo(letter);
    setState(() {
      _activeLetter = letter;
      _fingerY = position.dy + 8;
    });
  }

  void _endPointer(int pointer) {
    if (_pointer != pointer) return;
    setState(() {
      _pointer = null;
      _activeLetter = null;
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      children: [
        CustomScrollView(
          key: widget.scrollKey,
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                key: _header,
                padding: EdgeInsets.only(right: widget.showAlphabet ? 28 : 0),
                child: widget.header,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(
                right: widget.showAlphabet ? 28 : 0,
                bottom: 16,
              ),
              sliver: SliverFixedExtentList(
                itemExtent: _rowExtent(context),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = widget.songs[index];
                    return Center(
                      key: ValueKey(song.id),
                      child: SongTile(
                        song: song,
                        controller: widget.controller,
                        collection: widget.collection,
                        onRemove: widget.onRemove == null
                            ? null
                            : () => widget.onRemove!(song),
                      ),
                    );
                  },
                  childCount: widget.songs.length,
                  findChildIndexCallback: (key) =>
                      key is ValueKey<String> ? _indexById[key.value] : null,
                ),
              ),
            ),
          ],
        ),
        if (widget.showAlphabet) ...[
          Positioned(
            top: 8,
            bottom: 8,
            right: 0,
            width: 32,
            child: LayoutBuilder(
              builder: (context, rail) => Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  _pointer = event.pointer;
                  _selectAt(event.localPosition, rail.maxHeight);
                },
                onPointerMove: (event) {
                  if (_pointer == event.pointer) {
                    _selectAt(event.localPosition, rail.maxHeight);
                  }
                },
                onPointerUp: (event) => _endPointer(event.pointer),
                onPointerCancel: (event) => _endPointer(event.pointer),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: panel.withValues(alpha: .65),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      for (final letter in songAlphabet)
                        Expanded(
                          child: Semantics(
                            key: Key('alphabet-$letter'),
                            container: true,
                            excludeSemantics: true,
                            label: _firstByLetter.containsKey(letter)
                                ? letter == '#'
                                      ? 'Numbers, symbols, and other letters'
                                      : 'Songs beginning with $letter'
                                : '$letter, no songs',
                            enabled: _firstByLetter.containsKey(letter),
                            button: _firstByLetter.containsKey(letter),
                            onTap: _firstByLetter.containsKey(letter)
                                ? () => _jumpTo(letter)
                                : null,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  letter,
                                  textScaler: TextScaler.noScaling,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _firstByLetter.containsKey(letter)
                                        ? copper
                                        : muted.withValues(alpha: .35),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_activeLetter != null)
            Positioned(
              right: 52,
              top: (_fingerY - 32).clamp(
                0,
                math.max(0, constraints.maxHeight - 64),
              ),
              child: IgnorePointer(
                child: Container(
                  key: const Key('alphabet-bubble'),
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: copper,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 16),
                    ],
                  ),
                  child: Text(
                    _activeLetter!,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    ),
  );
}
