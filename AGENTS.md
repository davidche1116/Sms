# AGENTS.md — Sms (Flutter Android SMS cleaner)

## Toolchain (do not exceed Flutter template bounds)
- Flutter SDK lives at `~/fvm/versions/stable/bin` (fvm-managed; `~/flutter/bin`
  no longer exists on this machine), **not** on PATH. Prefix every Flutter/Dart
  command: `export PATH="$HOME/fvm/versions/stable/bin:$PATH"`.
- Pinned working set (Flutter 3.47 template): Flutter 3.47.5 / Dart 3.13.4 /
  AGP 9.1.0 / Gradle 9.3.1 / KGP 2.4.10 / JDK 17. Do not bump AGP/Gradle beyond
  what the installed Flutter template supports (`gradle_utils.dart` in the SDK
  is the source of truth).
- Verify, in order: `flutter analyze` → `flutter test` → `flutter build apk --debug`.
  `flutter test` needs no device (platform channels are mocked in
  `test/widget_test.dart`).

## Android gotchas (all verified the hard way)
- `android/app/build.gradle.kts` hardcodes `compileSdk = 37` (permission_handler
  v13 requirement; Flutter template still 36). Never revert to
  `flutter.compileSdkVersion` or plugin builds fail.
- The SDK only ships versioned platforms (`android-37.1`, …), but AGP looks up
  `android-37`. If a build fails with `Failed to find target 'android-37'`,
  symlink it: `ln -sfn <sdk>/platforms/android-37.1 <sdk>/platforms/android-37`.
  CI does this automatically in the "Setup Android SDK Platform 37" step.
- Root `android/build.gradle.kts` backfills `namespace` and raises legacy
  library modules to compileSdk 37, and disables lint tasks (old `sms_advanced`
  buildscripts crash the lint worker under AGP 9). Touch this file only if you
  understand why each hack exists.
- `sms_advanced 1.1.0` is an AGP-4.1-era plugin that applies KGP itself; future
  Flutter will refuse to build it. Replacement means writing our own platform
  channel (query/delete SMS) — out of scope for routine changes.
- `android/key.properties` + `android/app/key/sms.keystore` are tracked in git
  (owner's explicit decision). Never rotate, delete, or "clean" them without asking.

## Dart code rules
- App is essentially one file: `lib/main.dart` (~900 lines). `test/widget_test.dart`
  mocks `flutter.baseflow.com/permissions/methods` (granted=1) and
  `plugins.elyudde.com/querySMS` (JSON codec, `[]`). Any startup channel call
  added to the app must get a mock there or `flutter test` breaks.
- permission_handler v13 (Android): `status` **never** returns
  `permanentlyDenied`. Only branch on the `request()` result; never derive
  permanent-denial from `status`. See `_requestPermission()` for the pattern.
- `flutter_smart_dialog` usage is limited to `observer/init/show/showToast/dismiss`
  — none of the v5-removed APIs (`backDismiss`, `replaceBuilder`, `checkExist`).
- L10n: source of truth is `lib/l10n/*.arb`; generated code in
  `lib/l10n/generated/` is produced via `l10n.yaml`. Don't hand-edit generated files.
- The three READMEs (`README.md`, `README_zh.md`, `README_zh_TW.md`) document the
  toolchain versions and CI table — update all three together.

## Build & release
- Release APK: `dart pub global activate fastforge` then
  `fastforge release --name apk` (config: `distribute_options.yaml`).
  `flutter_distributor` is discontinued — do not switch back.
- Release signing needs local `android/key.properties`; debug builds don't.
- CI (`.github/workflows/`): build.yml = analyze+test+APK on push/PR;
  manual.yml = same, channel-selectable (default stable); publish.yml = draft
  Release on version tags. All run stable + install Android Platform 37.

## Git
- No git identity is configured on this machine and global config must not be
  changed. Commit with one-shot flags:
  `git -c user.name="davidche" -c user.email="davidche@kiloview.com" commit …`
- Commit style is conventional: `fix(android): …`, `build(deps): …`,
  `ci(workflows): …`, `docs(readme): …`, `test(widget): …`. Split unrelated
  areas into separate commits. Only commit/push when explicitly asked.
