![LOGO](android/app/src/main/res/mipmap-xhdpi/ic_launcher.png)

# SMS Cleaner

English | [简体中文](README_zh.md) | [繁體中文](README_zh_TW.md)

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

## Screenshots

![UI](assets/screenshot/ui.jpg)

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
flutter run
flutter test
flutter analyze
cd android && ./gradlew :app:testDebugUnitTest
flutter build apk --debug
flutter build apk --release
```

Requires Flutter 3.47+ (Dart 3.13+), Android minSdk 29.

## Release signing

Release builds use signing material shipped with the repo (same as 1.x):

- `android/key.properties` — passwords and alias
- `android/app/key/sms.keystore` — keystore (`storeFile` is relative to `android/app/`)

```bash
flutter build apk --release
```

If `key.properties` is missing, release falls back to the debug signature (local testing only).

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
android/app/src/main/kotlin/com/dc16/sms/
  MainActivity.kt           # MethodChannel dispatch
  SmsAccess.kt              # query / delete / permission / MIUI
  SmsReceiver.kt            # insert new SMS when default
```


## Privacy

SMS content is used only for on-device display, filtering, and export. No network upload, no analytics.

## License

[MIT License](LICENSE)
