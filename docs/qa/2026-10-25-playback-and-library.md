# Playback and library update — 0.1.2

## Reported behavior

- Android playback stopped after long background sessions.
- System media controls and the compact player could disagree after extended playback or pause/resume.
- Playing a search result replaced the queue with only matching results.
- Large libraries needed a quick alphabet index.

## Evidence and fixes

The connected Android 13 phone retained eight application crash records with `ForegroundServiceStartNotAllowedException`, plus a separate excessive-CPU termination. These records establish real failures; they do not establish a fixed two-hour Android timeout.

The app owns its queue in Dart, but the plugin stopped the native player and service at each natural single-file completion before notifying the app. The next track therefore needed to start a new foreground service from the background. Pocket Music now opts out of that intermediate stop. The controller explicitly stops native playback at the actual end of its queue.

Asynchronous cover decoding also replayed old notification snapshots, including their play/pause state. Late artwork could replace a newer track, demote ongoing playback, or restore a hidden notification. Service-owned decoding jobs now use revision checks and cancellation. Artwork only enhances the current notification; lifecycle updates happen synchronously when the current playback state changes. Paused metadata updates never promote a foreground service.

Position polling could create multiple callback chains after repeated Play commands. One cancellable ticker now serves each player, and paused seeking publishes its position immediately. Playback requested during buffering/preparation continues to count as ongoing playback. Explicit media Play and Pause retain their intent through the Dart controller instead of becoming toggles.

Library and collection search filter visible rows while retaining the full parent collection for playback. Global search queues the library; favorites, playlists, albums, and artists queue their own full collections. Song rows are built lazily. The `#` / A–Z rail supports tapping and dragging, shows the selected letter to the left of the finger, disables empty sections, and groups accented Latin initials with their base letters.

## Automated validation

- All 77 Flutter controller, adapter, library navigation, layout, and regression tests passed.
- All 17 Android unit tests passed for media command routing, foreground lifecycle, artwork revisions, and position polling, including a simulated two-hour polling session.
- Flutter analysis, the Android release build, and the unsigned iOS release build passed.

## Device validation

Target: Realme RMX3363, Android 13. Installed as an update with existing music and playlists retained.

- A natural song ending advanced to the next song with the same foreground service and process retained.
- After a 193-second pause, Android had removed the idle service; a system media Play command resumed the song and restored foreground playback without a crash.
- Explicit Play/Pause remained idempotent; Next, Previous, and headset toggle commands worked with the phone locked.
- Selecting the only result of a global search retained the selected song plus 967 other library songs.
- Searching a two-song playlist and selecting one match retained both playlist songs in the queue.
- Tapping M jumped to the M songs; holding M showed the enlarged letter to the left of the finger. Search stayed at the top.

A longer phone-side playback run is being collected. A user-confirmed manual pause interrupted the first 15-minute interval; that pause is not counted as an application failure. No completed two-hour hardware pass is claimed by these initial results. The phone's USB connection was also removed for calls; the phone-side logger can continue without USB.
