![LOGO](android/app/src/main/res/mipmap-xhdpi/ic_launcher.png)

# SMS Cleaner

[简体中文](README_zh.md) | [繁體中文](README_zh_TW.md) | English

- SMS Cleaner is a tool for reading and batch deleting SMS messages on Android, built with Flutter framework.
- Although the UI framework Flutter supports cross-platform development, only Android SMS deletion functionality has been implemented.

## Features

- Get SMS permissions
- Copy SMS to clipboard
- Set/restore default SMS app
- Filter SMS messages by keywords
- Search SMS by phone number
- Remove/directly delete SMS from search results
- One-click batch deletion of queried SMS messages
- One-click export of all SMS messages to CSV file

## Screenshot
![UI](assets/screenshot/ui.jpg)

## Privacy

- All SMS data stays **on your device**. The app makes no network requests: nothing is uploaded, synced, or shared automatically.
- Exported CSV files are written to the app's temporary directory and shared only via the system share sheet when you explicitly trigger the export.
- Deleting SMS messages is irreversible — double-check your filters before batch deletion.
- Permissions declared in the Android manifest:
  - `READ_SMS` / `RECEIVE_SMS` / `RECEIVE_MMS` / `RECEIVE_WAP_PUSH` — read and manage SMS/MMS messages.
  - `SEND_SMS` — required by the default-SMS-app role (the app itself does not send messages).
  - `READ_PHONE_STATE` — required by the default-SMS-app role on some Android versions.
  - `READ_CONTACTS` / `READ_PROFILE` / `QUERY_ALL_PACKAGES` — declared alongside the legacy SMS plugin; not used by the app itself.
  - Default SMS app role — Android only allows SMS deletion from the default SMS app; the app asks you to switch temporarily and can restore your previous default.

## Development Environment

- Flutter 3.47.2 (stable)
- Dart 3.13.2
- Gradle 9.3.1
- Android Gradle Plugin 9.1.0
- Kotlin 2.4.10
- compileSdk 37 / minSdk 26
- JDK 17

## Build & Publish

Build the release APK with fastforge:

```bash
dart pub global activate fastforge
fastforge release --name apk
```

Artifacts are output to `dist/`. The APK is signed with the release keystore and packages **arm64-v8a only** (single ABI).

### CI Workflows

| Workflow | Trigger | Flutter Channel | Contents |
| --- | --- | --- | --- |
| `build.yml` | push main (version tags excluded) / PR (opened or updated) | stable | `dart analyze` + `flutter test` + build APK + upload artifact |
| `manual.yml` | manual trigger | beta / master / stable selectable (default stable) | `dart analyze` + `flutter test` + build APK + upload artifact |
| `publish.yml` | version tag (e.g. `1.6.1+250725`) | stable | build APK + create draft Release |

### Build Notes

- `permission_handler` upgraded to `13.0.2`: v13 requires compileSdk 37, so `android/app/build.gradle.kts` pins `compileSdk = 37` (above Flutter 3.47 template 36) with AGP 9.1.0 + Android SDK Platform 37. Permission code follows the v13 request-driven pattern (never derive `permanentlyDenied` from `status`).
- Old plugins (e.g. `sms_advanced 1.1.0`, from the AGP 4.1 era) lack a `namespace` and hardcode `compileSdk 31`. The root `android/build.gradle.kts` auto-fills the namespace from `project.group` and raises the compileSdk of legacy library modules to 37.
- Lint tasks are disabled in `android/build.gradle.kts` (see the Call project note): legacy plugin buildscripts pin old AGP versions and crash the lint worker (`AndroidLintWorkAction`) when mixed with root AGP 9.1.0; `extract*Annotations` tasks are replaced with placeholder outputs.
- `kotlin.incremental=false` is set in `android/gradle.properties`: on Windows, Kotlin incremental compilation cannot handle sources (pub cache on the C: drive) and build output (project on the D: drive) on different drives.
- `sms_advanced` applies the Kotlin Gradle Plugin itself; future Flutter versions will reject this, so keep an eye out for an alternative.
- Code quality is guaranteed by `dart analyze` + `flutter test` in CI.
- Run tests locally with `flutter test` (platform channels are mocked, no device needed).

## Project Structure

```
Sms
├─android              # Android project configuration
├─assets               # Assets
├─lib                  # Flutter source code
│  ├─main.dart         # App entry & UI
│  └─services          # Data access & pure logic (SMS repository / filtering / CSV export)
├─.github/workflows    # CI workflows
└─dist                 # Build output
```
