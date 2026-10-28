# رالیتو — Rallyto player app

Flutter app for finding partners in tennis, padel, badminton and squash. Persian only (`fa_IR`), right-to-left,
Jalali dates. Android first; iOS builds but is not published. Structure and conventions follow AsanRezerve's
customer app: `lib/config`, `lib/core`, `lib/features/<feature>/{data,domain,presentation}`, and `test/` mirrors `lib/`.

## Commands

```sh
flutter pub get
dart run build_runner build      # regenerate *.g.dart and injection.config.dart; commit the output
flutter analyze                  # must report no issues
flutter test
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5000   # default: http://10.0.2.2:5000 (Android emulator)
```

## Push notifications (Firebase)

Push uses Firebase Cloud Messaging. The Firebase configuration is **supplied at build time and never committed**:

1. Download `google-services.json` for the Android app `ir.rallyto.app` from the Firebase console (project
   settings › your apps).
2. Put it at `android/app/google-services.json` before `flutter build` / `flutter run` (CI: write it from a secret in
   the build step). It is in `.gitignore`; never commit it.

`android/app/build.gradle.kts` applies the Google services Gradle plugin only when that file exists, so a build
without it still compiles and runs, with push turned off: `FirebasePushService.initialize()` fails soft and the app
uses the inbox and the realtime hub only. Tests never touch Firebase (`PushService` has a no-op implementation).

What the app does with push:

* registers the FCM token after sign-in and whenever FCM rotates it (`POST /api/v1/device-tokens {token, platform}`),
  and unregisters it before sign-out (`DELETE /api/v1/device-tokens {token}`);
* opens a tapped push's `deepLink` (`/matches/{id}`, `/chat/{conversationId}`, `/saved-searches/{id}`,
  `/availability`, `/profile`); an unknown link opens the notification inbox.

## Realtime

While the player is signed in and the app is in the foreground, it keeps one SignalR connection to
`{API_BASE_URL}/hubs/realtime` (the access token goes in the `access_token` query parameter), reconnecting with backoff
(0, 2, 5, 10, 30 s, then every minute). Chat messages, read receipts, deletions and new notifications arrive over it.
While it cannot connect, open chat screens poll every 15 s and the home badges every 60 s.
