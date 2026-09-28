# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 格式，
版本号遵循语义化版本（`major.minor.patch+YYMMDD` 构建号）。

## [Unreleased]

### Fixed

- **筛选弹层键盘裁切按钮**：「重置/完成」移出滚动区做固定底栏，键盘下始终完整可点
- **弹层安全区**：筛选 / 动作 Sheet / 删除确认统一 `SafeArea(top:false)`，适配手势导航等底部非安全区
- **导出/导入状态串用**：设置页与首页拆分 `_exporting` / `_importing`，导出时不再误显「导入中…」

- **空态按钮溢出**（真机横/矮屏）：`EmptyView` 改为可滚 + 有界高度撑开；`home_page`
  去掉写死的 `0.55 * 屏高`，改 `minHeight`，按钮不再被裁切（BORDER OVERFLOWED）
- **筛选弹层被键盘挡住「重置/完成」**：`AnimatedPadding` 跟随 `viewInsets`，
  内容限高可滚；点「完成」先 `unfocus` 收起键盘
- **切换语言后设置行仍显示旧值**：`SettingsPage` 用本地 `_locale` 即时刷新，
  不再依赖 push 时捕获的 `widget.locale`

### Added

- **应用内语言切换**：设置 → 外观「语言」四档（跟随系统 / 简体中文 / 繁體中文 / English），
  `LocaleStore` 持久化；`localeListResolutionCallback` 先精确匹配 language+country
- **关于组补全**：开源许可（`showLicensePage`）、问题反馈（GitHub Issues）、
  隐私说明改为对话框（不再只有一句 toast）
- **导入失败文案本地化**：`InsertRowError.labelOf` 按通道 `code` 映射中/繁/英，
  不再透出原生 `message`（可能是系统异常英文）；Kotlin 侧无用户可见 Toast，
  线协议 `warnings[].message` 保持固定英文（契约锁定），UI 一律按 code 本地化

### Fixed

- **繁体中文（zh_TW）回归**：补齐 `lib/l10n/app_zh_TW.arb` 全量文案；`localeListResolutionCallback`
  改为先精确匹配 language+country 再回落同语言，避免 `zh_TW` 被错配成简中
- **英文 README**（`README_en.md`）；中文 README 语言切换与 CI / 发布表
- 恢复社区文件：`SECURITY.md`（密钥不入库策略）、`AGENTS.md`、dependabot、
  issue / PR 模板
- 恢复 `publish.yml`（tag 发版）与 `manual.yml`（手动通道 / 可选 release）

### Fixed

- **`kotlin.incremental=false` 回归**：Windows 下 pub cache（C:）与工程（D:）跨盘时
  Kotlin 增量编译会炸（`:shared_preferences_android:compileDebugKotlin` 缓存写失败）；
  main 已修，2.0 重写时丢失。恢复后 `:app:testDebugUnitTest` 可过
- **启动图标降级**：恢复品牌 icon / adaptive icon（`mipmap-anydpi-v26`）/ `assets/icon` 源图；
  补 `flutter_launcher_icons` 配置便于再生成
- **应用名资源化**：`@string/app_name` + `values` / `values-zh` / `values-zh-rTW`
- **ABI 过滤**：release 回归 `arm64-v8a` 单 ABI（AGP 9 需在 `defaultConfig.ndk` 清空再设）
- 版本构建号回归 `+YYMMDD` 约定：`2.0.0+260928`

### Fixed (previous)

- **`querySms` 部分失败上报（P1-2）**：不再「静默不完整」。各子查询（SMS/MMS 主表与
  子箱、`mms/addr` 过滤与号码富化、`mms/part` 正文富化）独立收集异常，单路失败不丢
  其它路已有行。线协议新增 `partial: bool` + `warnings: [{code, message}]`（code 见
  CHANNEL_CONTRACT §3）；`error` 仍只在**完全无数据且失败**时非 null，与 `partial`
  互斥。`warnings[].message` 为固定文案，不含 URI/路径/异常信息。
  Dart `SmsQueryPage` 带 `partial`/`warnings`；首页 `partial` 时横幅轻提示
  「部分短信可能未加载」+ 点按/下拉重试，不阻断使用。旧客户端忽略新字段仍可见已加载行

### Performance

- **`querySms` 真分页（P0-1）**：SMS/MMS 各自按 `date DESC, _id DESC` 从 Provider 取流，
  `LIMIT offset+limit` 下推 sortOrder，读取短路 + 两流归并，只物化本页；
  5k 假数据 `limit=20, offset=30` 行消费 ≤50（旧路径全量 LinkedHashMap）
- **去掉 4 重 URI 重复扫描**：默认只查 `content://sms` / `content://mms` 整表；
  仅当整表为空才回落 inbox/sent/draft（保留掉默认后空列表的 OEM 兼容，git `8aa3f62`）
- `total` 改用 count 与切页解耦；`limit=0` 不扫行；地址过滤小集合下推 `_id IN`
- MMS 富化仍只对本页 addr/part，不做全库 N+1

### Added

- **默认短信应用时彩信通知入库**（R2 / P0-2）：`MmsReceiver` 不再空实现。解析 `WAP_PUSH_DELIVER` 的 MMS PDU（`MmsPduParser`），把通知元数据写入 `content://mms/inbox` + `addr`（可选主题 text part），新彩信不丢条；完整 smil/媒体不下载重建（无公开 `PduPersister`），README / PERMISSION_DESIGN / 设置页明示限制
- **彩信（MMS）纳入统一数据面**（P3-17）：浏览 / 筛选 / 删除 / 导出；wire 身份为 `_id` + `is_mms` 二元组，删除按 `is_mms` 路由到 `content://sms` / `content://mms`，绝不跨表
- `SmsItem.isMms` / `hasMedia` / `uid`（MMS id + 2^30 偏移，多选/隐藏/去重专用）；卡片「彩信」徽章 + 「含附件」标注；筛选类型新增「仅彩信」
- CSV 导出新增 `is_mms` 列；导入**跳过彩信行**（smil/pdu/媒体无法用 insertSmsBatch 重建）
- 彩信正文摘要：`content://mms/part` 文本 part 拼接；无文本时本地化占位「[彩信]」

### Changed

- **`deleteSmsBatch` 线协议改为 Map 明细**（P1-1）：返回 `{ok, deleted, failed, error, errors}`，
  与 `insertSmsBatch` 对齐。区分 `not_default`（整批未执行）与 `failed`（原生异常）；
  部分成功 `ok=true, deleted=N, failed=M, errors[]`（逐 chunk 计入，index 对齐 `{id,is_mms}` 载荷）。
  Dart `DeleteBatchResult.fromWire` 仍兼容旧 `int?`。UI 失败文案精确分支：
  非默认 → 「请先设为默认短信应用」，原生异常 → 「删除失败，请重试」（不再一律误报设为默认），
  部分成功 → 「已删除 X / N 条后失败」
- `deleteSmsBatch` 入参支持 `List<{id, is_mms}>` 混合目标（旧 `List<Int>` 仍兼容，按纯 SMS 处理）；Dart `SmsRepository.deleteSmsBatch` 改为接收 `List<SmsItem>`
- 查询 `querySms` 合并彩信元数据（`content://mms` + inbox/sent/drafts），`date` 秒→毫秒换算；地址过滤经 `content://mms/addr` 预取 msg_id；正文/号码只对**本页**彩信批量补全
- 多选 / 隐藏列表 / 去重改用 `uid`（避免 SMS/MMS 同号 `_id` 互撞）

### Added (previous)

- **i18n 基建**（P3-15）：`flutter_localizations` + `intl` + ARB/`flutter gen-l10n`（`l10n.yaml`，模板 `lib/l10n/app_zh.arb`，生成 `lib/generated/`）
- 中文（默认）+ 英文两套文案，覆盖首页/筛选/删除/空态/toast/设置/权限/MIUI 引导/主题页/CSV 导入导出
- `test/i18n/i18n_smoke_test.dart`：中英文 locale 关键文案冒烟
- GitHub Actions CI（`.github/workflows/ci.yml`）：push / PR 到 `main`、`dev` 时跑 `flutter analyze` → `flutter test` → `flutter build apk --debug`
- 发布签名配置：`android/key.properties`（已 gitignore）或 `RELEASE_*` 环境变量驱动 release 签名；README 新增「发布签名」一节

### Changed

- UI 文案改为 `AppLocalizations`，主路径不再硬编码中文；`SmsItem.dayLabel` → `dayLabelOf(l10n)`，`importMessage` / `errorSummary` / 导出分享文案改为接收 `AppLocalizations`
- **Breaking**：`applicationId` / `namespace` 从 `com.dc16.sms` 改为 `com.davidche1116.sms`，MethodChannel 由 `com.dc16.sms/smsApp` 改为 `com.davidche1116.sms/smsApp`，QA Intent action 前缀同步为 `com.davidche1116.sms.QA_*`。已装旧包无法覆盖升级，需卸载重装
- release 构建不再无条件使用 debug 签名：有 `key.properties` / `RELEASE_*` 时用正式签名；否则回退 debug 签名并在 Gradle 日志明确警告（禁止上架）

### TODO

- 真机验证：收新短信（SMS_DELIVER）入库闭环、非 MIUI 机型 ROLE_SMS 资格

### Security

- `.gitignore` 增加 `key.properties` / `*.jks` / `*.keystore` 等密钥文件忽略规则

## [2.0.0] - 2026-09-27

2.0 全面重写：Material 3 界面、原生查询 / 删除通道、RoleManager 默认短信应用、默认时收信入库。

### Added

- 筛选搜索：关键词、日期范围、类型（收件箱 / 已发送）、同号、同卡，Chip 叠加可清除
- 多选操作：长按进入多选，选中集按短信 `_id` 对齐（筛选后不错位），支持全选当前可见项
- 导出 CSV：全部或选中，RFC 4180 转义 + UTF-8 BOM，系统分享
- 导入 CSV：与导出格式互逆（`address,body,date,kind,sub_id`），只新增写入短信库，需设为默认短信应用
- 权限中心：读短信、默认短信应用状态卡、一键检查并修复；冷启动不弹系统权限框
- MIUI 引导：申请读短信后自动检测「通知类短信」私有开关，一键跳转 MIUI 权限编辑器；首页提供可关闭提示
- 移出列表：本地隐藏不删系统数据，HiddenStore 持久化，可重置
- 主题：8 色色盘 + 浅色 / 深色 / 跟随系统
- 默认短信应用下通过 `SmsReceiver` 收新短信入库

### Changed

- 架构拆分：`home_page` 拆为 list / filter / delete / settings / widgets；`SmsRepository` 不再依赖 UI 层
- 查询改走 Kotlin 原生多 URI 合并去重（`querySms` / `deleteSmsBatch` / `insertSmsBatch`）
- 删除确认、滑删、动作 Sheet、FAB 批量删除均带确认
- 删除链路以测试数据验证，真实短信零改动

### Fixed

- 多选从列表下标改为 `_id`，刷新 / 筛选后不再误选
- 跨月「昨天」日期标签边界
- 日期区间按自然日闭区间取舍
- READ_SMS 判定结合 AppOps，避免 OEM 掉默认后假授予

## [1.8.0] - 2026-09-26

多选删除、原生 `querySms` 兜底、掉默认短信后的权限 / 查询 / 闪退修复。详见历史提交。
