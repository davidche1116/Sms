# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 格式，
版本号遵循语义化版本（`major.minor.patch+YYMMDD` 构建号）。

## [Unreleased]

### Fixed

- fix(app): 首次短信查询推迟到首帧之后，避免国际化对象未初始化导致的潜在崩溃
- fix(default-sms): 查询默认短信应用发生平台异常时按失败处理（fail-safe），不再继续删除
- fix(query): 关键词过滤对 null 正文做空安全处理，不再强解包崩溃
- fix(query): 短信查询路径（全部/同号/同卡）统一捕获平台异常，失败时提示并复位加载状态
- fix(delete): 单条与批量删除增加错误处理；批量删除按快照执行并统计/汇报失败条数；跳过缺失 id 的条目
- fix(export): 导出后只删除本次导出的 CSV 文件，不再递归清空整个临时目录
- fix(export): CSV 中可空字段（id/threadId/sim/address/body/date/dateSent/kind/isRead）写空串而非 "null"
- fix(ui): 系统栏配置从 build 移到 initState，避免每帧触发平台通道调用
- fix(ui): 弹出菜单项文案改用 Expanded 约束，修复长文案横向溢出
- build(android): debug 构建改回默认调试签名；release 签名在缺少 key.properties 时回退调试签名，贡献者无密钥也可本地出包

### Changed

- build: 最低 Dart SDK 要求提升至 `^3.13.4`（与最新 stable Flutter 3.47.5 自带的 Dart 版本一致）
- build(deps): `flutter pub upgrade` 升级锁文件内 7 个传递依赖（archive 4.3 / code_assets 2.1 / cupertino_ui 1.1.1 / image 4.10.1 / material_ui 1.4 / platform 3.2 / vector_math 2.4.3）；cross_file 0.4、material_color_utilities、test_api、cli_util 受 Flutter SDK 与 share_plus 约束暂无法升级
- refactor: 短信数据访问与过滤逻辑从 UI 层拆分至 `lib/services/`（`SmsRepository` / 纯函数过滤 / CSV 导出）
- ci: PR 触发补齐 `synchronize`/`reopened`，三个 workflow 增加 concurrency 并发控制
- test: 新增过滤逻辑与 CSV 导出单元测试，扩展 widget 测试（列表渲染、菜单项）

### Docs

- docs(readme): 三语 README 新增隐私说明章节（数据不出设备、逐权限用途、删除不可恢复提示），并同步 CI 触发说明与项目结构

## [1.7.0] - 2026-09-05

### Changed

- build(deps): 更新依赖至最新并适配 permission_handler 13 / smart_dialog 5.3
- build(android): Kotlin 升级至 2.4.10
- ci(workflows): 升级 Actions 至最新稳定版并切 stable 通道；修复 Android SDK 安装步骤的 yes 管道 SIGPIPE 失败

### Fixed

- fix(sms-list): 整表刷新时重建 AnimatedList，修复多轮过滤后灰屏无内容
- fix(android): MainActivity 迁移 Activity Result API 并修正版本判断
- fix(android): 补齐 manifest 声明缺失的短信收发组件
- test(widget): 重写默认计数器测试为带通道 mock 的冒烟测试

## [1.6.2] - 2026-08-10

### Changed

- build(android): 升级 Android 工具链至 Gradle 9.1.0 / AGP 9.0.1 / Kotlin 2.3.20 并适配旧插件
- build(deps): 更新依赖至 csv 8 / share_plus 13 等并适配 API 变更

### Fixed

- fix(android): 修复 ABI 过滤不生效，APK 仅打包 arm64-v8a

### Docs

- docs(readme): 更新开发环境配置和构建说明

## [1.6.1] - 2025-07-25

### Fixed

- fix(main): 优化日期范围选择逻辑

## [1.6.0] - 2025-07-24

### Added

- feat(main): 新增按日期筛选短信功能

### Changed

- build(dependencies): 更新多个依赖至最新版本
- refactor(share): 优化短信列表分享功能
- refactor: 优化代码结构和类型

（更早版本请查阅 git tag 历史。）
