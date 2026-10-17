# Pocket Music

Pocket Music is a private, offline MP3 player for Android and iPhone, built with Flutter and Dart. It plays music stored on your own phone. There are no accounts, ads, analytics, cloud sync, or streaming features.

The Flutter application is in [`app/`](app/). The repository also includes the maintained local fork of AssetsAudioPlayer that provides native playback, background audio, and system media controls.

## What it does

- Scans local Android audio or imports files through the system picker.
- Imports audio selected from the iPhone Files app into Pocket Music's private storage.
- Browses songs, albums, and artists, with search, favorites, and playlists.
- Adds many songs to a playlist in one pass, even while searching.
- Plays, seeks, shuffles, repeats, and remembers the queue and playback state.
- Keeps a separate **Up next** list: swipe a song right-to-left to play it before the normal queue.
- Shows the current track, play/pause, next, shuffle, and queue in the compact player.
- Keeps search visible while scrolling the Android library.
- Accepts Android media play/pause, next, and previous commands from the lock screen and compatible Bluetooth accessories.
- Allows Android music to play alongside audio from other apps.
- Supports Android notifications and lock screens, plus iPhone Control Center and lock-screen controls, including local embedded cover artwork.

If an MP3 has no embedded cover image, Pocket Music shows its record placeholder. Your original music files are never changed or deleted.

## Privacy

Pocket Music only plays local files. Android release builds do not request Internet access. Imported files, artwork, playlists, favorites, and playback state remain in app storage. Removing the app also removes its private imports and saved state.

## Requirements

Build on a Mac for both platforms.

- Flutter 3.47.7 or newer, which includes Dart.
- Java 17 and Android SDK 36 for Android.
- Xcode 27.1 or newer and CocoaPods for iPhone.
- An Apple ID added to Xcode to install directly on an iPhone.

Confirm your tools before the first build:

```sh
flutter --version
java -version
xcodebuild -version
```

## Install or update Android

1. Connect one Android phone by data cable, unlock it, enable **Developer options** and **USB debugging**, then approve the computer on the phone.
2. Clone this repository and open the folder:

   ```sh
   git clone https://github.com/Eloe321/pocket-music.git
   cd pocket-music
   ```

3. Build an installable APK:

   ```sh
   ./scripts/build-android-release.sh
   ```

   The APK is written to `app/build/app/outputs/flutter-apk/app-release.apk`.

4. Install it on the connected phone:

   ```sh
   ./scripts/install-android.sh
   ```

To update an Android phone later, pull the latest code and run the same two commands again:

```sh
git pull
./scripts/build-android-release.sh
./scripts/install-android.sh
```

The existing build uses the Mac's local debug signing key for personal sideloading. Keep using the same Mac and do not uninstall the app if you want updates to preserve imports, playlists, and settings. For a distributable release, create and protect your own Android release keystore, configure it locally, and never commit it to Git.

During playback, Android uses a media foreground service and keeps the player engine alive when the app screen is removed from Recents. Playback may still stop if the user force-stops the app or the phone's battery manager kills the process. Pocket Music does not override system-wide audio routing or call audio rules.

You can also copy the APK to a phone and open it there. Android may ask you to allow installs from that file manager. An update must be signed with the same key as the installed app.

## Install or update iPhone

iPhone installation requires a Mac with Xcode because Apple signs each device build. This repository supports direct development installation; it is not an over-the-air installer.

1. Plug the iPhone into the Mac, unlock it, trust the Mac if asked, and enable Developer Mode.
2. Open [`app/ios/Runner.xcworkspace`](app/ios/Runner.xcworkspace) in Xcode.
3. Select the **Runner** target, open **Signing & Capabilities**, and choose your Apple development team. Keep the same team and bundle identifier for future updates to the same app. Use a different bundle identifier for a separate copy of Pocket Music.
4. In a terminal, obtain the connected phone identifier:

   ```sh
   xcrun devicectl list devices
   ```

5. Build and install:

   ```sh
   IPHONE_UDID=YOUR_IPHONE_UDID ./scripts/install-ios.sh
   ```

For later updates, connect the same phone, run `git pull`, and repeat the final command. If iOS blocks the first launch, use **Settings → General → VPN & Device Management** to trust the development profile. Apple provisioning can require periodic renewal; rebuild from Xcode when it does.

To install it on other iPhones, repeat the signing and installation steps for each device. Wider, permanent distribution requires the relevant Apple Developer Program workflow, such as TestFlight or App Store distribution.

## Run while developing

From `app/`:

```sh
flutter pub get
flutter analyze
flutter test -j 1
flutter run -d DEVICE_ID
```

## Verification

The Flutter app has automated coverage for library state, playlist editing, queue order, Up next priority, persistence, and the main player UI. It was tested on an Android 13 phone and an iPhone 12 Pro Max running iOS 26.5. On the iPhone, playback, playlists, queue behavior, mini-player controls, Control Center, and lock-screen media artwork were verified on hardware.

## Credits and license

Pocket Music began as a fork of [Flutter-AssetsAudioPlayer](https://github.com/florent37/Flutter-AssetsAudioPlayer) by Florent Champigny. It retains the upstream Apache-2.0 license in [`LICENSE`](LICENSE).
