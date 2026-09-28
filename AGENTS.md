# AGENTS.md — Sms (Flutter Android 短信清理)

本地优先的 Android 短信 / 彩信清理工具（Flutter + Kotlin）。
Dart UI 与业务在 `lib/features/`、`lib/services/`；平台访问在
`android/app/src/main/kotlin/com/davidche1116/sms/`。

## 项目结构

```
Sms
├─lib
│  ├─main.dart                 # 入口
│  ├─app.dart                  # 主题与 MaterialApp
│  ├─theme/tokens.dart         # 色盘
│  ├─models/sms_item.dart      # 短信 / 彩信模型
│  ├─services/                 # 通道封装 / CSV / 隐藏列表 / 主题持久化
│  ├─features/
│  │  ├─list/                  # 首页、卡片、动作 Sheet、横幅
│  │  ├─filter/                # 筛选模型与弹层
│  │  ├─delete/                # 删除确认与进度
│  │  ├─settings/              # 设置 / 主题 / 权限 / MIUI 引导
│  │  └─widgets/               # 空态
│  ├─l10n/                     # ARB（zh / zh_TW / en）
│  └─generated/                # flutter gen-l10n 输出
├─android/app/src/main/kotlin/com/davidche1116/sms/
│  ├─MainActivity.kt           # MethodChannel 分发
│  ├─SmsAccess.kt              # 查询 / 删除 / 权限 / MIUI
│  ├─ChannelCodes.kt           # 线协议常量（与 Dart 对齐）
│  ├─SmsReceiver.kt            # 默认短信时收信入库
│  ├─MmsReceiver.kt            # 默认短信时彩信通知入库
│  └─MmsPduParser.kt           # MMS PDU 解析
├─test                         # 按域拆分的 Dart 测试 + helpers
├─docs                         # 设计与通道契约
└─.github/workflows            # ci / publish / manual
```

## 命令

```bash
flutter pub get
flutter analyze
flutter test
cd android && ./gradlew :app:testDebugUnitTest   # Kotlin 单测
flutter build apk --debug
```

Windows 下 Kotlin 增量编译跨盘会失败，`android/gradle.properties` 必须保持
`kotlin.incremental=false`（pub cache 在 C:，工程在 D:）。

## 测试约定

- helpers 放 `test/helpers/`：通道 mock 走 `app_channel.dart`，
  场景夹具在 `mock_sms_channel.dart`（`pumpHome` / `mockHomeChannel`）。
- 挂载首页用 `pumpHome(tester)`，不要用 `pumpAndSettle`（待机动画会超时）。
- 新增筛选字段必须改 `SmsFilter.applyFrom`，并同步 `reset()` / `active` /
  `matches()` 与 `test/filter/sms_filter_test.dart`。
- 通道断言优先引用 `ChannelCodes` 常量，不要散落裸线值
  （契约测试 `test/channel_codes_test.dart` 除外）。
- 文案改动同步中 / 繁 / 英三份 ARB，再跑 `flutter gen-l10n`。

## 通道契约

线协议、枚举线值、错误码见 [docs/CHANNEL_CONTRACT.md](docs/CHANNEL_CONTRACT.md)。
双端 `ChannelCodes`（Dart / Kotlin）必须同步；改线值先改契约文档。

## 签名

release 签名材料只放本地 `android/key.properties` 或 CI Secrets
（`RELEASE_*`），**绝不入库**。详见 README「发布签名」与 SECURITY.md。
