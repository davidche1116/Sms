# AGENTS.md — Sms (Flutter Android SMS Cleaner)

An Android SMS read/batch-delete tool built with Flutter. UI lives in
`lib/main.dart`; data access and pure logic live in `lib/services/`.

## Project layout

```
Sms
├─lib
│  ├─main.dart         # App entry & UI
│  ├─l10n              # ARB sources + generated localizations
│  └─services          # sms_repository / sms_filter / csv_exporter
├─test                 # Unit tests (filter, CSV) + widget smoke test
├─android              # Gradle config (see "Android build")
└─.github/workflows    # CI
```

## Commands

The Flutter SDK is not on PATH. Prefix every Flutter/Dart command with:

```bash
export PATH="$HOME/fvm/versions/stable/bin:$PATH"
```

Pinned toolchain: Flutter 3.47.5 / Dart 3.13.4 / AGP 9.1.0 / Gradle 9.3.1 /
KGP 2.4.10 / JDK 17. Do not bump AGP/Gradle beyond what the installed Flutter
template supports (`gradle_utils.dart` in the SDK is the source of truth).

Verify every change, in order:

```bash
dart format lib test
flutter analyze
flutter test                  # no device needed; channels are mocked
flutter build apk --debug     # required for any Gradle change
```

Release: `dart pub global activate fastforge` then
`fastforge release --name apk` (config: `distribute_options.yaml`).
Do not switch back to `flutter_distributor` — it is discontinued.

## Dart rules

- Keep UI in `lib/main.dart`. Keep platform-channel calls, filtering, and CSV
  encoding in `lib/services/`, with unit tests in `test/`.
- permission_handler v13 (Android): `status` never returns `permanentlyDenied`.
  Branch only on the `request()` result. See `_requestPermission()`.
- flutter_smart_dialog: use only `observer`/`init`/`show`/`showToast`/`dismiss`.
  None of the v5-removed APIs (`backDismiss`, `replaceBuilder`, `checkExist`).
- L10n source of truth is `lib/l10n/*.arb`. Never hand-edit
  `lib/l10n/generated/`; after `pub get`/gen-l10n re-emits it, run
  `dart format lib`.
- Any startup platform-channel call must get a mock in `test/widget_test.dart`
  (`flutter.baseflow.com/permissions/methods` → granted,
  `plugins.elyudde.com/querySMS` → JSON `[]`), or `flutter test` breaks.

## Android build

All items below were verified the hard way — understand a hack before touching it.

- `android/app/build.gradle.kts` pins `compileSdk = 37` (permission_handler v13
  requirement; the Flutter template still uses 36). Never revert to
  `flutter.compileSdkVersion` or plugin builds fail.
- The SDK ships versioned platforms (`android-37.1`), but AGP looks up
  `android-37`. On `Failed to find target 'android-37'`, symlink it:
  `ln -sfn <sdk>/platforms/android-37.1 <sdk>/platforms/android-37`.
  CI does this automatically in the "Setup Android SDK Platform 37" step.
- Root `android/build.gradle.kts` backfills `namespace`, raises legacy library
  modules to compileSdk 37, and disables lint tasks (old `sms_advanced`
  buildscripts crash the lint worker under AGP 9).
- `sms_advanced 1.1.0` applies the Kotlin Gradle Plugin itself; a future
  Flutter will refuse to build it. Replacing it means writing our own platform
  channel — out of scope for routine changes.
- `android/key.properties` + `android/app/key/sms.keystore` are tracked in git
  by owner decision. Never rotate, delete, or clean them without asking.
- Debug builds use the debug signature. Release falls back to the debug
  signature when `key.properties` is missing.

## CI

- `build.yml`: analyze + test + APK on push to main and PRs.
- `manual.yml`: same, channel-selectable, manual trigger.
- `publish.yml`: draft Release on version tags.
- All workflows run stable channel and install Android Platform 37.

## Docs

- Update `README.md`, `README_zh.md`, and `README_zh_TW.md` together — they
  mirror each other and document the toolchain versions and CI table.
- Record notable changes in `CHANGELOG.md` (Keep a Changelog format,
  Unreleased section on top).

## Git

- Do not change global git config. Commit with one-shot identity flags.
- Follow conventional commits (`fix:`, `build:`, `ci:`, `docs:`, `test:`,
  `refactor:`). Split unrelated areas into separate commits.
- Commit and push only when explicitly asked.
