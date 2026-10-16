# Pocket Music

An offline Flutter/Dart music player built on this fork of AssetsAudioPlayer.
The application lives in `app/`; its audio dependency is the plugin in the parent directory.

Features include local songs, albums and artists, search, favorites, named playlists,
a reorderable queue, play/pause, next/previous, seeking, shuffle, repeat, saved playback
position, and native background/lock-screen controls. Restored sessions start paused.

Android scans MediaStore after audio permission and can import audio through the system
file picker. Permission denial still permits private imports. iPhone imports through
its document picker into private app storage; it does not scan Apple Music or DRM media.
Original audio files are never modified or deleted. Library refresh reconciles missing
tracks while retaining favorite and playlist references for files that return later.

## Local development

Use Flutter 3.47.7 / Dart 3.13.5, Java 17, and Android SDK 36. Dart is bundled with Flutter.
From this folder:

```sh
flutter pub get
flutter analyze
flutter test -j 1
flutter run -d DEVICE_ID
flutter build apk --debug
```

In the delivered workspace, `../../flutter-local` from `app/`
wraps the installed SDK. The `outputs/run-android.command` launcher checks for a single
authorized phone and sufficient disk space; `outputs/build-android.command` builds an APK.
Connect an unlocked Android phone over a data cable, enable USB debugging, and accept
its authorization prompt. Developer mode alone is insufficient. Android minimum API 24.

For iOS, install Xcode and the iOS SDK, select a signing team, then build `Runner.xcworkspace`.
iOS source targets version 15.0. No iOS build or runtime QA has been completed here.

## Privacy

No account, advertising, analytics, cloud sync, or upload code is included. The playback
adapter rejects remote URLs. Android release configuration removes INTERNET permission;
debug builds retain Flutter development connectivity. The system document picker may
show user-configured cloud providers; choosing such a file is controlled by the user.
Imports, artwork, favorites, playlists and playback state remain in app storage.
Android backup is disabled; iOS documents/imports are marked excluded from backup.
Uninstalling the app removes its private imported copies and saved state.

## Verification limits

Automated tests exercise Dart state, mocked platform channels, persistence, and widget
interactions. Screenshot fixtures use invented music metadata and no real audio.
These tests do not establish native decoding, audible playback, permissions on hardware,
background survival, Bluetooth behavior, or lock-screen correctness.

As of 16 October 2026, native Android assembly is blocked by insufficient free disk space
and missing cached Gradle dependencies. No authorized Android phone is visible to ADB.
There is no APK yet and no phone MP3 has been accessed. iOS has syntax-only validation,
not a build, because Xcode is unavailable. See the delivered QA.txt for evidence and
remaining device acceptance checks.
