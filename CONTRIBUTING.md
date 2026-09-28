# 贡献指南

感谢参与「短信清理」。本文约定开发环境、常用命令、测试与提交规范。

## 开发环境

| 依赖 | 要求 | 说明 |
|------|------|------|
| Flutter | stable（3.47+ / Dart 3.13+） | 推荐 [fvm](https://fvm.app/) |
| Android SDK | minSdk 29 | Android Studio SDK Manager 或 `sdkmanager` |
| JDK | **17** | 与 CI 对齐 |

## 常用命令

```bash
flutter pub get
flutter analyze
flutter test
cd android && ./gradlew :app:testDebugUnitTest   # Kotlin 单测
flutter build apk --debug
```

## 测试约定

- 通道 mock 走 `test/helpers/app_channel.dart`，场景夹具用 `mock_sms_channel.dart`；`tearDown` 必须清 handler。
- 挂载首页用 `pumpHome(tester)`，不要用 `pumpAndSettle`（待机动画会超时）。
- 新增筛选字段必须改 `SmsFilter.applyFrom`，并同步 `reset()` / `active` / `matches()` 与对应测试。
- 通道断言优先引用 `ChannelCodes` 常量，不要散落裸线值。

## 提交风格

[Conventional Commits](https://www.conventionalcommits.org/zh-hans/v1.0.0/)：`feat` / `fix` / `refactor` / `perf` / `test` / `docs` / `chore`。摘要可用中文，一句话说清「为什么」。

## Pull Request 期望

1. `flutter analyze` 与 `flutter test` 全绿；改原生时 `flutter build apk --debug` 能过。
2. 通道契约双端同步：`lib/services/channel_codes.dart` 与 `android/.../ChannelCodes.kt`，并更新 `test/channel_codes_test.dart`。线值默认不变，确需修改请标 Breaking。
3. 文案改动同步中 / 繁 / 英三份 ARB，再跑 `flutter gen-l10n`。

## 调试 QA Intent（仅 debug 包）

只操作带测试前缀的短信（默认 `SMSCLEANUP_TEST`），非 debuggable 包忽略。前缀：`com.dc16.sms.QA_*`。

| Action | extras | 作用 |
|--------|--------|------|
| `QA_INSERT_TEST` | `count`、`bodyPrefix` | 插入测试短信 |
| `QA_DELETE_TEST` | `bodyPrefix` | 按前缀删除 |
| `QA_DELETE_IDS` | `ids`、`bodyPrefix` | 按 id 删除（仅前缀匹配） |
| `QA_QUERY_STATE` | — | 查询权限 / 默认应用状态 |
| `QA_IMPORT_TEST` | `bodyPrefix` | 走 `insertSmsBatch` 导入两行 |

```bash
adb shell am start -n com.dc16.sms/.MainActivity \
  -a com.dc16.sms.QA_INSERT_TEST --ei count 3 --es bodyPrefix SMSCLEANUP_TEST
adb shell run-as com.dc16.sms cat files/qa_result.txt
```

前置：debug 包 + 已设为默认短信应用。结果写 `filesDir/qa_result.txt`。

## 许可

贡献内容默认按 [MIT License](LICENSE) 授权。
