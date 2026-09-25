# AGENTS.md — Sms (Flutter Android SMS Cleaner)

An Android SMS read/batch-delete tool built with Flutter. Business state lives
in `lib/controllers/`; platform access and pure logic live in `lib/services/`;
UI lives in `lib/main.dart` and `lib/widgets/`.

## Project layout

```
Sms
├─lib
│  ├─main.dart         # App entry & SMS list page UI
│  ├─controllers       # SmsListController: list state + business rules
│  ├─l10n              # ARB sources + generated localizations
│  ├─services          # sms_repository / sms_filter / csv_exporter
│  ├─utils             # small pure helpers (date formatting)
│  └─widgets           # reusable UI pieces (message_item)
├─test                 # Unit tests (filter, CSV, repository, controller) + widget tests
├─android              # Gradle config (see "Android build")
└─.github/workflows    # CI
```

## Commands

The Flutter SDK is not on PATH. Prefix every Flutter/Dart command with:

```bash
export PATH="$HOME/fvm/versions/stable/bin:$PATH"
```

If `flutter test` fails with `Unable to connect to flutter_tester process`, an
HTTP proxy is hijacking the localhost socket. Add:

```bash
export NO_PROXY="localhost,127.0.0.1"
```

Pinned toolchain: Flutter 3.47.5 / Dart 3.13.4 / AGP 9.1.0 / Gradle 9.3.1 /
KGP 2.4.10 / JDK 17. Do not bump AGP/Gradle beyond what the installed Flutter
template supports (`gradle_utils.dart` in the SDK is the source of truth).

Verify every change, in order:

```bash
dart format lib test
flutter analyze
flutter test                  # no device needed; channels are mocked
flutter build apk --debug     # required for any Gradle/Kotlin/Manifest change
```

After editing any ARB file, regenerate before formatting:

```bash
flutter gen-l10n && dart format lib
```

Release: `dart pub global activate fastforge` then
`fastforge release --name apk` (config: `distribute_options.yaml`).
Do not switch back to `flutter_distributor` — it is discontinued.

## Dart rules

- **Keep business state out of the widget.** `SmsListController`
  (`lib/controllers/`) owns the message list, loading flag, filters and all
  query/delete rules. `lib/main.dart` renders and shows dialogs only.
- **The controller must never hold a `BuildContext`.** Surface user-facing
  messages through its `onMessage` callback; the page turns them into toasts.
- **Item callbacks take `SmsMessage`, never a list index.** Indices drift
  across `await` gaps; passing the object removes the whole bug class.
- Guard every post-`await` UI update with `if (!mounted) return;` — toasts and
  list replacement are funnelled through `_showToast` / the controller.
- Keep platform-channel calls, filtering, and CSV encoding in `lib/services/`,
  with unit tests in `test/`.
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
- Batch deletes must go through `SmsRepository.deleteSmsBatch` first and fall
  back to per-message deletion only when it returns `null`.

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
  Flutter will refuse to build it. Replacing it means writing our own SMS
  query channel — out of scope for routine changes.
- `android/key.properties` + `android/app/key/sms.keystore` are tracked in git
  by owner decision. Never rotate, delete, or clean them without asking
  (see `SECURITY.md` for why this is a known, accepted risk).
- Debug builds use the debug signature. Release falls back to the debug
  signature when `key.properties` is missing.

## Native channel contract (`com.dc16.sms/smsApp`)

| Method | Returns |
| --- | --- |
| `getDefaultSmsApp` | package name, or `""` when unknown |
| `setDefaultSmsApp` | `had` / `ok` / `no` |
| `resetDefaultSmsApp` | `settings` (Android 10+: opened system settings) / `ok` / `no` |
| `deleteSmsBatch` | deleted row count, or `null` on failure |

- Android 10+ cannot hand the default-SMS role back programmatically
  (`ACTION_CHANGE_DEFAULT` is ignored for third parties and RoleManager only
  requests roles for the calling app), hence the `settings` result.
- `QUERY_ALL_PACKAGES` is stripped with `tools:node="remove"`, so probing other
  packages depends entirely on `<queries>` in the manifest. Add any new probe
  target there as well.

## CI

- `build.yml`: format check + analyze + test + APK on push to main and PRs.
- `manual.yml`: same, channel-selectable, manual trigger.
- `publish.yml`: draft Release on version tags (APK + obfuscation symbols).
- All workflows run stable channel and install Android Platform 37.
- Dependabot (`.github/dependabot.yml`) opens weekly PRs for pub packages and
  GitHub Actions.

## Docs

- Update `README.md`, `README_zh.md`, and `README_zh_TW.md` together — they
  mirror each other and document the toolchain versions and CI table.
- Record notable changes in `CHANGELOG.md` (Keep a Changelog format,
  Unreleased section on top).
- `CONTRIBUTING.md` is the human-facing counterpart of this file; keep the
  hard rules in both consistent.

## Git

- Do not change global git config. Commit with one-shot identity flags.
- Follow conventional commits (`fix:`, `build:`, `ci:`, `docs:`, `test:`,
  `refactor:`). Split unrelated areas into separate commits.
- Commit and push only when explicitly asked.
