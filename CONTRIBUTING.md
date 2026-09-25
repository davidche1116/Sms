# 贡献指南

感谢你愿意为短信清理出力。这是一份 Android 短信读取/批量删除工具，代码量不大，
但涉及短信数据删除，任何改动都请慎重。

## 开始之前

- 只需要 Flutter SDK（stable 渠道，版本见 [README](README_zh.md) 的"开发环境"）
  与 Android SDK Platform 37。
- 不需要真机即可跑测试：`flutter test` 会把平台通道全部 mock 掉。
- 涉及原生（Kotlin / Gradle / Manifest）的改动**必须**在真机上验证过再提 PR。

## 开发流程

```bash
flutter pub get          # 拉取依赖
flutter gen-l10n         # 改了 ARB 之后重新生成本地化代码
dart format lib test     # 格式化（CI 有门禁）
flutter analyze          # 静态分析
flutter test             # 单元与 widget 测试（通道已 mock，无需设备）
flutter build apk --debug # 改了 Gradle / Kotlin / Manifest 之后必须跑
```

提交信息遵循 [Conventional Commits](https://www.conventionalcommits.org/)，
本项目常用前缀：`fix:`、`feat:`、`perf:`、`refactor:`、`test:`、`docs:`、`ci:`、
`build:`。一个提交只做一件事。

## 代码结构约定

| 目录 | 放什么 |
| --- | --- |
| `lib/main.dart` | 应用入口与短信列表页的界面（渲染、弹窗、导出、权限与默认应用引导） |
| `lib/controllers/` | 列表状态与业务规则（`SmsListController`），不接触 `BuildContext` |
| `lib/services/` | 平台通道封装与纯逻辑（短信仓库 / 过滤 / CSV 导出），可单测 |
| `lib/widgets/` | 可复用界面组件 |
| `lib/utils/` | 小型纯函数 |
| `lib/l10n/*.arb` | 国际化文案源文件（**不要**手改 `generated/`） |
| `test/` | 单元测试与 widget 测试 |

几条硬规则：

- **不要把 `BuildContext` 存进 controller**，需要提示时走 `onMessage` 回调。
- **不要手改 `lib/l10n/generated/`**：改 ARB 后跑 `flutter gen-l10n`，
  生成文件会被重新输出为未格式化状态，记得再跑一次 `dart format lib`。
- **新增启动阶段的平台通道调用，必须在 `test/widget_test.dart` 里补 mock**，
  否则 `flutter test` 会挂。
- **列表项的交互回调传 `SmsMessage` 对象，不要传下标**：下标在异步间隙会
  漂移，历史上为此修过多次。

## 新增/修改文案

文案只改 `lib/l10n/app_en.arb`（模板）、`app_zh.arb`、`app_zh_TW.arb`，
三份键必须一致，然后：

```bash
flutter gen-l10n
dart format lib
```

## 发版

- 改动记到 `CHANGELOG.md` 的 `Unreleased` 段（Keep a Changelog 格式）。
- 版本号写在 `pubspec.yaml` 的 `version`（`major.minor.patch+YYMMDD`）。
- 打 `x.y.z` 标签会触发 `publish.yml`，产出 APK 并创建草稿 Release。

## 报告问题

请附上：Android 版本与机型、是否为默认短信应用、操作步骤、以及
`flutter doctor -v` 的输出。涉及短信丢失的，请说明短信是否在系统短信
应用里也消失了。
