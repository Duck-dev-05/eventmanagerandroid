# EventPulse Android

The Flutter client for EventPulse. It connects to the existing EventPulse website
and shares events, tasks, agenda sessions, files, members, notifications and
activity with the web and desktop apps.

## Requirements

- Flutter 3.44+ / Dart 3.12+
- Android 7.0 (API 24) or newer
- Java 17 for the Android Gradle build

## Run locally

```sh
flutter pub get
flutter run
```

The app talks to `https://eventmanager-5dsz.vercel.app` by default. For another
deployment pass the origin to both Dart and the Android background worker:

```sh
flutter build apk --release \
  --dart-define=EVENTPULSE_ORIGIN=https://events.example.com \
  -Peventpulse.origin=https://events.example.com
```

Google sign-in also requires a matching Android OAuth client via
`android/app/google-services.json` and the web/server client id in
`lib/mobile_backend.dart`.

## Checks

```sh
flutter analyze
flutter test
```

CI runs both and builds a release APK on every push and pull request
(`.github/workflows/android-build.yml`).

## Release signing

Local `flutter build apk --release` builds work with the debug signing key. For
Play Store builds:

1. Create a release keystore.
2. Copy `android/key.properties.example` to `android/key.properties` and fill in
   the keystore path and passwords. `key.properties`, `*.jks` and `*.keystore`
   are git-ignored.
3. The release application id defaults to `app.eventpulse.android`, matching
   `android/app/google-services.json`. To publish under a different id, create a
   matching Firebase Android app, replace `google-services.json`, and pass the
   id explicitly:

   ```sh
   flutter build appbundle --release \
     -Peventpulse.applicationId=app.eventpulse.android
   ```

The Play Store upload artifact is
`build/app/outputs/bundle/release/app-release.aab`.

## Notifications

New unread EventPulse notifications are posted as Android system notifications
using the `eventpulse_updates` channel. Android 13+ asks for notification
permission on first launch; the app also respects the system notification
toggle. Foreground sync checks about every 8 seconds, while the background
WorkManager check runs about every 15 minutes and is scheduled by Android.
Instant delivery while the app is fully closed would require FCM push.

## Backup and restore

The workspace owner can export and restore a full backup from **Settings →
Full backup & restore**. Android uses the same `eventpulse-backup` format
(version 1) as the Web and Desktop apps, including workspace tables, uploaded
files and device-local templates. Restoring resets the local sync cursor and
caches so the restored workspace is fetched as a fresh snapshot.

## Android UI flavors

- **Classic** (Android 13 and below) — compact cards with soft shadows, a
  floating bottom navigation bar and the warm EventPulse palette.
- **Expressive** (Android 14 and newer) — larger shapes, flat tonal surfaces,
  pill-shaped actions and a full-width navigation bar.

Detection lives in `lib/ui/flavor.dart`, runtime tokens in `lib/ui/theme.dart`,
and the active style is shown in **Settings → App appearance**. Widget tests can
force a style with `EventPulseApp(uiFlavor: UiFlavor.expressive)`.

## Android compatibility

| Android version | Experience |
| --- | --- |
| Android 14+ | Expressive UI |
| Android 7.0 – 13 | Classic UI |
| Below Android 7.0 | Not supported by the current build |

Supporting Android 5/6 would require replacing or downgrading the current
`file_picker` → `flutter_plugin_android_lifecycle` dependency chain.

## Known limitations

- Task, agenda and file-metadata changes made offline are queued and retried on
  the next work sync. Creating or editing an event and uploading file contents
  still require a connection.
- Release builds use the debug signing key until `android/key.properties` is
  configured. The production Firebase Android app and `google-services.json`
  are already wired to `app.eventpulse.android`.
- Android 8+ uses the adaptive EventPulse icon. Android 7.x falls back to the
  bitmap icons bundled with the Flutter template.
