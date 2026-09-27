# 贡献指南

感谢参与「短信清理」。本文约定开发环境、常用命令、测试与提交规范；通道协议细节见 [docs/CHANNEL_CONTRACT.md](docs/CHANNEL_CONTRACT.md)。

## 开发环境

| 依赖 | 要求 | 说明 |
|------|------|------|
| Flutter | stable（3.47+ / Dart 3.13+） | 推荐 [fvm](https://fvm.app/)：`fvm use stable`；或官方安装后 `flutter channel stable` |
| Android SDK | minSdk 29，compile/target 以 `android/app/build.gradle.kts` 为准 | Android Studio SDK Manager 或 `sdkmanager` |
| JDK | **17** | 与 CI（`temurin 17`）对齐；Gradle 不支持更旧主版本 |

自检：

```bash
flutter --version    # channel: stable
java -version        # 17
```

## 常用命令

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug   # CI 同款：验证可编译（含 Kotlin）
```

Kotlin 单独编译（改原生代码时快速反馈；在 `android/` 下执行）：

```bash
cd android && ./gradlew :app:compileDebugKotlin
```

## 测试约定

- **helpers 放 `test/helpers/`**：通道 mock 统一走 `app_channel.dart`（`setAppChannelHandler` / `clearAppChannelHandler`），场景夹具在 `mock_sms_channel.dart`（`mockHomeChannel` / `setUpHomeHarness` / `sampleRows`）。用例 `tearDown` 必须清 handler，避免泄漏到下一条。
- **挂载首页用 `pumpHome(tester)`，不要用 `pumpAndSettle`**：首页可能有待机动画，`pumpAndSettle` 会超时。`pumpHome` 已 pump 首帧 + 300ms 主题动画。弹层展开后仍可对局部动画用 `pumpAndSettle`。
- **新增筛选字段必须改 `SmsFilter.applyFrom`**（`lib/features/filter/filter_sheet.dart`）：`applyFrom` 是全字段拷贝的唯一落点，漏字段会导致弹层「重置/应用」后丢条件。同步检查 `reset()`、`active`、`matches()`，并在 `test/filter/sms_filter_test.dart` 的 `applyFrom` 用例里补字段断言。
- 通道相关断言优先引用 `ChannelCodes` 常量 / 枚举 `fromWire`，不要在测试里散落裸线值（契约测试 `test/channel_codes_test.dart` 除外，它专门锁线值）。

## 提交风格

[Conventional Commits](https://www.conventionalcommits.org/zh-hans/v1.0.0/)：

```
feat: 支持按 SIM 筛选
fix: 滑删取消后卡片回弹
refactor: 抽出删除确认入口
perf: 查询分页减少首屏耗时
test: 补全 insertSmsBatch 部分失败用例
docs: 贡献指南与通道契约
chore: 升级 CI Flutter 版本
```

- type 用小写英文：`feat` / `fix` / `refactor` / `perf` / `test` / `docs` / `chore`。
- 摘要可用中文，一句话说清「为什么」；正文（可选）补充影响面与验证方式。
- 一个提交只做一件事；文档与代码可分开提交。

## Pull Request 期望

1. **`flutter analyze` 与 `flutter test` 全绿**（与 CI 相同）；改原生代码时至少 `flutter build apk --debug` 或 `./gradlew :app:compileDebugKotlin` 能过。
2. **涉及通道契约必须双端同步**：方法名、参数键、返回形状、枚举线值改动要同时改
   - `lib/services/channel_codes.dart`（`ChannelCodes` + 枚举 `fromWire`）
   - `android/.../ChannelCodes.kt`（`ChannelCodes`）
   - `docs/CHANNEL_CONTRACT.md`
   并更新 `test/channel_codes_test.dart`。**协议字符串保持不变**是默认约束；确需改线值请在 PR 里显式标 Breaking。
3. 涉及交互/视觉变更时，回写对应设计文档（`docs/UI_DESIGN.md` / `INTERACTION_DESIGN.md` / `QUERY_DELETE_DESIGN.md` / `PERMISSION_DESIGN.md`）。
4. 不要提交密钥材料（`android/key.properties`、`*.jks`、`*.keystore` 已 gitignore）。

## 调试 QA Intent（仅 debug 包）

`MainActivity.handleQaIntent` 提供 adb 可触发的自检入口，**只操作带测试前缀的短信**（默认 `SMSCLEANUP_TEST`），且非 debuggable 包直接忽略。Action 前缀：`com.davidche1116.sms.QA_*`。

| Action | extras | 作用 |
|--------|--------|------|
| `com.davidche1116.sms.QA_INSERT_TEST` | `count` int（默认 3）、`bodyPrefix` string | 插入带前缀测试短信 |
| `com.davidche1116.sms.QA_DELETE_TEST` | `bodyPrefix` | 按前缀删除测试短信 |
| `com.davidche1116.sms.QA_DELETE_IDS` | `ids` int[]、`bodyPrefix` | 删除指定 id（仅保留前缀匹配的） |
| `com.davidche1116.sms.QA_QUERY_STATE` | — | 读 MIUI / 通知类短信 / 读权限 / 默认应用状态 |
| `com.davidche1116.sms.QA_IMPORT_TEST` | `bodyPrefix` | 走 `insertSmsBatch` 导入两行，核对 Map 明细 |

示例：

```bash
# 插入 3 条测试短信
adb shell am start -n com.davidche1116.sms/.MainActivity \
  -a com.davidche1116.sms.QA_INSERT_TEST --ei count 3 --es bodyPrefix SMSCLEANUP_TEST

# 回读结果（写入 filesDir/qa_result.txt）
adb shell run-as com.davidche1116.sms cat files/qa_result.txt

# 清理
adb shell am start -n com.davidche1116.sms/.MainActivity \
  -a com.davidche1116.sms.QA_DELETE_TEST --es bodyPrefix SMSCLEANUP_TEST
```

前置：debug 包 + 已设为默认短信应用（写库需要）。结果只追加到日志与 `qa_result.txt`，不弹 UI。

## 许可

贡献内容默认按 [MIT License](LICENSE) 授权。
