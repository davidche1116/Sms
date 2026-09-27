# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 格式，
版本号遵循语义化版本（`major.minor.patch+YYMMDD` 构建号）。

## [Unreleased]

### Added

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

- Kotlin 侧字符串（通道/原生 toast）本次未抽取
- 设置页暂无手动语言切换（跟随系统；不支持时回退中文）；后续可加 in-app locale 选择

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
