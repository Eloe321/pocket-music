# Pocket Music

The user approved the clean offline player on 16 October 2026. Build a Flutter/Dart application in `app/`, using this fork's audio plugin through a local path dependency. Keep the original plugin and demo as reference. Android is the executable target; iPhone source is included and explicitly unverified without Xcode.

## Behavior

Show a searchable song library, grouped albums/artists, favorites, named playlists, a persistent mini-player, a full player, and an editable queue. Support play/pause, next/previous, seeking, shuffle, and repeat off/all/one. Restore library selections, favorites, playlists, queue, and playback position locally; never autoplay at launch. Explain permission denial, an empty library, missing files, and playback errors with a recovery action.

Android queries MediaStore after requesting the version-appropriate audio permission. Also support importing multiple audio documents into private storage. iPhone imports through its document picker and lists those private copies. Retain metadata and local artwork where available. Never alter or delete original music. Background audio and media controls use the fork's native implementations.

## Privacy

No accounts, analytics, remote artwork, streaming, or cloud sync. Android release has no INTERNET permission and backup is disabled. Metadata and imported files stay in application storage. Debug tooling may use Flutter's development connection. Do not commit phone files or library databases.

## Structure

`core/models.dart` defines songs and playlists. Ports separate library access, playback, and persistence. `MusicController` owns user state and serialized operations. Native Kotlin/Swift bridges implement media discovery/import. UI observes the controller and presents recoverable states. Unit tests use fake ports; native playback requires a device.

## Visual design

Deep blue background #101B2D, raised surfaces #1D2B42, copper accent #EDAA7D, cool white #F2F5F9, muted blue-gray #9DAFC6. Use platform sans-serif with large bold library headings and restrained monospace duration labels. Artwork is local only; missing artwork uses a record motif. Large touch controls, system safe areas, adaptable text and layouts, and screen-reader labels are required.

## Verification

Test permission results, search/grouping, favorites/playlists and persistence, restore without autoplay, queue changes, rapid command ordering, repeat/shuffle state, missing media, and playback failures. Widget tests cover onboarding/empty states, searching, navigation, mini-player/full-player controls, and playlist interactions. Analyze Dart and build Android when disk permits. On a connected Android phone verify real MP3 metadata and playback, seek, track completion, queue, library persistence, airplane mode, background/lock-screen controls, and supported hardware interruptions. Mark each unexercised hardware/iPhone case as unverified.
