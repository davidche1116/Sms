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

## Development Environment
### [Flutter](https://docs.flutter.cn/get-started/install)
- flutter stable 3.29.1
- dart 3.7.0
- gradle 8.3
- gradle-plugin 8.1.4
- kotlin 1.8.22

### Build Commands
- Install flutter_distributor
- `dart pub global activate flutter_distributor`
- Build release
- `flutter_distributor release --name apk`