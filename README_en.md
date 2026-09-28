# SMS Cleaner

[简体中文](README.md)

Local-first Android SMS / MMS cleanup tool (Flutter + Kotlin). Browse, filter, multi-select, export, and delete SMS/MMS. Everything stays on your device — nothing is uploaded or collected.

## Features

- **Message list**: grouped by date, cards show number / body / time / SIM; MMS badge and attachment hint
- **Filter & search**: keyword, date range, type (inbox / sent / MMS-only), same number, same SIM
- **Multi-select**: long-press to enter, selection aligned by `uid` (SMS/MMS ids never collide); select all visible
- **Delete**: swipe / action sheet / multi-select / FAB batch (all confirm first); routed by `is_mms`, never cross-table
- **Hide from list**: local-only hide, system data untouched, resettable
- **Export CSV**: all or selected, RFC 4180 + BOM, system share; includes `is_mms` column
- **Import CSV**: same format as export; **insert-only** into the system SMS store (requires default SMS app); **MMS rows skipped**
- **Permission center**: read SMS, default SMS app, one-tap check & repair; MIUI “notification SMS” guide
- **Theme**: 8-color palette + light / dark / follow system
- **i18n**: Simplified Chinese, Traditional Chinese, English

### MMS support scope

Covered by the unified data plane: **browse / filter / delete / export**. Body summary is taken from text parts (`content://mms/part`); placeholder “[MMS]” when empty, “attachment” hint when media parts exist. No full rendering (smil / image / audio playback).

**New MMS while this app is the default**: `MmsReceiver` stores notification metadata (sender / time / subject / Message-ID / Content-Location) into `content://mms/inbox` + `addr`, so messages are not lost. Full smil/media is **not** downloaded (depends on non-public `PduPersister`). For complete MMS content, temporarily switch the default SMS app back to the system “Messages”.

## Permissions & system requirements

| Capability | Depends on | Notes |
|------|------|------|
| Read SMS/MMS | `READ_SMS` | List, search, export |
| Delete SMS/MMS | Default SMS app (`ROLE_SMS`) | Android 10+ via RoleManager |
| Write / new SMS | Default SMS app | `SmsReceiver` inserts when default |
| New MMS metadata | Default SMS app | `MmsReceiver` notification skeleton |

No system permission dialog on cold start; request from Settings or the empty state.

### MIUI note

MIUI adds a private **“Notification SMS”** toggle (App info → Permissions → Other). Without it, only person-to-person SMS is visible — 10086 / bank alerts stay hidden.

This toggle **cannot be granted via public API**. After READ_SMS is granted the app shows a one-tap guide to the MIUI permission editor; the home page also shows a dismissible hint.

## Build & run

```bash
flutter pub get
flutter run                 # debug
flutter test                # unit / widget tests
flutter analyze
cd android && ./gradlew :app:testDebugUnitTest   # Kotlin unit tests
flutter build apk --debug
flutter build apk --release # see “Release signing”
```

Requires Flutter 3.47+ (Dart 3.13+), Android minSdk 29.

## Release signing

Release builds **never** commit signing material. Put it in local `android/key.properties` (gitignored).

### 1. Generate a key (once)

```bash
keytool -genkey -v -keystore ~/keystore/sms-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### 2. Write `android/key.properties`

```properties
storeFile=/absolute/path/to/sms-release.jks
storePassword=***
keyAlias=upload
keyPassword=***
```

`storeFile` accepts an absolute path, or a path relative to `android/app/`. `*.jks` / `*.keystore` / `key.properties` are gitignored — **do not commit them**.

CI Secrets alternative: `RELEASE_STORE_FILE` / `RELEASE_STORE_PASSWORD` / `RELEASE_KEY_ALIAS` / `RELEASE_KEY_PASSWORD`.

### 3. Build

```bash
flutter build apk --release
```

If neither `key.properties` nor `RELEASE_*` exists, release falls back to the **debug signature** with a Gradle warning — local testing only. **Never ship a debug-signed APK to a store or as an official upgrade.**

### 4. Package id (Breaking)

`applicationId` / `namespace` / MethodChannel / QA Intent prefix changed from `com.dc16.sms` to `com.davidche1116.sms`. **Existing installs cannot upgrade in place** — uninstall and reinstall (messages live in the system SMS store and are not affected).

## Project structure

```
lib/
  main.dart                 # entry
  app.dart                  # theme + MaterialApp
  theme/tokens.dart         # palette
  models/sms_item.dart      # SMS/MMS model
  services/                 # channel / CSV / hidden list
  features/
    list/                   # home, cards, action sheet
    filter/                 # filter model + sheet
    delete/                 # delete confirm
    settings/               # settings / theme / permission
    widgets/                # empty states
android/app/src/main/kotlin/com/davidche1116/sms/
  MainActivity.kt           # MethodChannel dispatch
  SmsAccess.kt              # query / delete / permission / MIUI
  SmsReceiver.kt            # insert new SMS when default
```

## Design docs

- [UI_DESIGN.md](docs/UI_DESIGN.md) — visual & layout
- [INTERACTION_DESIGN.md](docs/INTERACTION_DESIGN.md) — interaction & state
- [PERMISSION_DESIGN.md](docs/PERMISSION_DESIGN.md) — permission model
- [QUERY_DELETE_DESIGN.md](docs/QUERY_DELETE_DESIGN.md) — query / delete contract
- [CHANNEL_CONTRACT.md](docs/CHANNEL_CONTRACT.md) — MethodChannel wire protocol
- [TODO.md](docs/TODO.md) — work log

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution and testing conventions.

## Privacy

SMS content is used only for on-device display, filtering, and export. No network upload, no analytics.

## License

[MIT License](LICENSE)
