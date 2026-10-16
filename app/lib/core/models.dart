import 'package:flutter/foundation.dart';

enum RepeatMode { off, all, one }

@immutable
class Song {
  const Song({
    required this.id,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.artworkPath,
  });
  final String id, path, title, artist, album;
  final Duration duration;
  final String? artworkPath;
  factory Song.fromJson(Map<String, dynamic> json) => Song(
    id: json['id'].toString(),
    path: json['path'] as String,
    title: _text(json['title'], 'Unknown title'),
    artist: _text(json['artist'], 'Unknown artist'),
    album: _text(json['album'], 'Unknown album'),
    duration: Duration(
      milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0,
    ),
    artworkPath: json['artworkPath'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'title': title,
    'artist': artist,
    'album': album,
    'durationMs': duration.inMilliseconds,
    if (artworkPath != null) 'artworkPath': artworkPath,
  };
  static String _text(dynamic value, String fallback) =>
      value is String && value.trim().isNotEmpty && value != '<unknown>'
      ? value.trim()
      : fallback;
  @override
  bool operator ==(Object other) => other is Song && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

@immutable
class LocalPlaylist {
  LocalPlaylist({
    required this.id,
    required this.name,
    List<String> songIds = const [],
  }) : songIds = List.unmodifiable(songIds);
  final String id, name;
  final List<String> songIds;
  factory LocalPlaylist.fromJson(Map<String, dynamic> json) => LocalPlaylist(
    id: json['id'] as String,
    name: json['name'] as String,
    songIds: (json['songIds'] as List? ?? []).whereType<String>().toList(),
  );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'songIds': songIds};
  LocalPlaylist copyWith({String? name, List<String>? songIds}) =>
      LocalPlaylist(
        id: id,
        name: name ?? this.name,
        songIds: songIds ?? this.songIds,
      );
}
