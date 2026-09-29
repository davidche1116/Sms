# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

SMS Cleaner（短信清理）— local-first Android SMS/MMS browse / filter / export / delete tool. Flutter 3.47+ (Dart 3.13+) UI over a Kotlin MethodChannel bridge. minSdk 29 (Android 10). No network upload; everything stays on device.

## Commands

```bash
flutter pub get
flutter gen-l10n                       # must run after pub get (generated files are not in git)
flutter analyze                        # must be clean (flutter_lints 6)
flutter test                           # all Dart tests
flutter test test/sms_repository_test.dart            # single file
flutter test --plain-name "test name"  # single test
flutter run                            # needs a device/emulator
flutter build apk --debug
flutter build apk --release            # signed via android/key.properties + android/app/key/sms.keystore; falls back to debug signature if key.properties missing
cd android && ./gradlew :app:testDebugUnitTest   # Kotlin/JUnit native tests
dart run flutter_launcher_icons        # regenerate launcher icons
```

CI (`.github/workflows/ci.yml`) runs exactly: gen-l10n → analyze → `flutter test` → `:app:testDebugUnitTest` → debug APK, with Java 17 + Flutter stable.

## Architecture

**Flutter ↔ native boundary (the core of the app).** All SMS/MMS access goes through a single `MethodChannel('com.dc16.sms/smsApp')`:

- Dart side: `lib/services/sms_repository.dart` (thin wrapper `SmsRepository`) + `lib/services/channel_codes.dart` (protocol literals).
- Kotlin side: `android/app/src/main/kotlin/com/dc16/sms/MainActivity.kt` (dispatch) + `SmsAccess.kt` (query/delete/permission/MIUI).
- **Protocol literals must stay in sync** between `channel_codes.dart` and Kotlin `ChannelCodes.kt`. Never scatter raw protocol strings in business code — reference the constants. Comment in `channel_codes.dart` says: 协议字符串保持不变 (wire format, do not change values).

**Unified SMS/MMS data plane.** `lib/models/sms_item.dart` is one model for both; items are keyed by a composite `uid` so SMS and MMS ids never collide — selection, deletion, and export all align on `uid`, and deletes route by `is_mms` (never cross-table). Queries are paged (`queryPage` → `SmsQueryPage`) and may return `partial: true` with `warnings` when one sub-query (SMS URI, MMS URI, addr/part enrichment) failed — the UI must show a light retry hint rather than treating it as total failure.

**Permissions are tiered**, and the app works without all of them:
- `READ_SMS` — list/search/export.
- Default SMS app (`ROLE_SMS` via RoleManager, Android 10+) — required for delete, write, import.
- MIUI has a private "Notification SMS" toggle with **no public API**; the app detects it (`miuiNotificationSmsState` → allow/likely_off/…) and shows a one-tap guide to MIUI's permission editor. See `lib/features/settings/miui_notif_guide.dart`.
- No permission dialog on cold start; requests happen from Settings or the empty state.
- `requestReadSms` returns a tri-state `RequestReadSmsResult` (granted / denied / timeout) — a system dialog that never answers (timeout, activity destroyed) must be distinguished from an actual denial. `SmsRepository` wraps system calls with a 2-minute `systemResponseTimeout` and re-checks state on timeout.

**Batch channel ops are chunked** because a single platform message is limited by Binder (~1MB): `insertChunkSize` / `deleteChunkSize` = 200 rows per `invokeMethod`, with Kotlin-side `INSERT_CHUNK` matching. Keep these paired.

**Native MethodChannel.Results are one-shot** (`OnceResult` wrapper in MainActivity.kt) — system-dialog callback + activity-destroy cleanup can both try to answer the same call; double-answering throws. `pendingRead` / `pendingRole` results are held across the system dialog and completed exactly once.

**New-message receivers** (`SmsReceiver.kt`, `MmsReceiver.kt`, `HeadlessSmsSendService.kt`) are mandatory parts of being a default SMS app. `MmsReceiver` stores only a metadata skeleton into `content://mms/inbox` (no smil/media download — that needs non-public `PduPersister`).

**CSV import/export** (`lib/services/csv_exporter.dart`, `csv_importer.dart`): RFC 4180 + BOM, includes `is_mms` column. Import is **insert-only** (no overwrite/delete) and **skips MMS rows**; requires default-SMS-app role. Import results flow through the single `importMessage()` toast formatter in `sms_data_service.dart`.

**UI layering**: `lib/features/` (list / filter / delete / settings) is plain Flutter + Material 3, theme palette in `lib/theme/tokens.dart`. "Hide from list" (`hidden_store.dart`) is local-only in SharedPreferences and never touches system data.

**i18n**: `l10n.yaml` + `lib/l10n/*.arb` (zh, zh_TW, en) → generated into `lib/generated/app_localizations.dart` (`generate: true` in pubspec). Import localizations from `../generated/app_localizations.dart`, not a hand-written class.

## Conventions

- Code comments and docs are primarily in Chinese; README is trilingual (en/zh/zh_TW — keep all three in sync when editing).
- Release signing material (`android/key.properties`, `android/app/key/sms.keystore`) is **not** committed to the repo (security). Local developers create these files manually; CI injects them from GitHub Secrets (`STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`, `KEYSTORE_BASE64`). Without `key.properties`, release builds fall back to debug signing (local testing only).
