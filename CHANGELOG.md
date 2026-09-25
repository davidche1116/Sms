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
- fix(export): await CSV 落盘后再分享，避免 saveTo 竞态导致分享到空/半截文件
- fix(default-sms): 还原默认短信应用真正调用 RoleManager 移交角色，而非仅启动设置页
- fix(default-sms): isDefaultSmsApp 区分「无法判定」与「非默认」，平台异常/MissingPlugin 不再误判为非默认
- build(android): debug 构建改回默认调试签名；release 签名在缺少 key.properties 时回退调试签名，贡献者无密钥也可本地出包

### Changed

- build: 最低 Dart SDK 要求提升至 `^3.13.4`（与最新 stable Flutter 3.47.5 自带的 Dart 版本一致）
- build(deps): `flutter pub upgrade` 升级锁文件内 7 个传递依赖（archive 4.3 / code_assets 2.1 / cupertino_ui 1.1.1 / image 4.10.1 / material_ui 1.4 / platform 3.2 / vector_math 2.4.3）；cross_file 0.4、material_color_utilities、test_api、cli_util 受 Flutter SDK 与 share_plus 约束暂无法升级
- refactor: 短信数据访问与过滤逻辑从 UI 层拆分至 `lib/services/`（`SmsRepository` / 纯函数过滤 / CSV 导出）
- ci: PR 触发补齐 `synchronize`/`reopened`，三个 workflow 增加 concurrency 并发控制
- test: 新增过滤逻辑与 CSV 导出单元测试，扩展 widget 测试（列表渲染、菜单项）
- docs(readme): 三语 README 新增隐私说明章节（数据不出设备、逐权限用途、删除不可恢复提示），并同步 CI 触发说明与项目结构
- refactor(export): 导出拆为保存/分享两阶段分别捕获，保存失败提示「保存失败」、分享失败提示「操作失败」（新增 l10n `toast_save_failed` 三语）
- perf(export): 导出改用 File.writeAsBytes 直接落盘，去掉 utf8→Uint8List.fromList→XFile.fromData 冗余全量拷贝，降低内存峰值

## [1.7.0] - 2026-09-05

### Added

- docs(agents): 新增仓库 agent 协作说明（AGENTS.md）

### Fixed

- fix(sms-list): 整表刷新时重建 AnimatedList，修复多轮过滤后灰屏无内容
- fix(android): MainActivity 迁移 Activity Result API 并修正版本判断
- fix(android): 补齐 manifest 声明缺失的短信收发组件
- ci(workflows): 修复 Android SDK 安装步骤的 yes 管道 SIGPIPE 失败

### Changed

- build(deps): 更新依赖至最新并适配 permission_handler 13 / smart_dialog 5.3
- build(android): Kotlin 升级至 2.4.10
- ci(workflows): 升级 Actions 至最新稳定版并切 stable 通道
- test(widget): 重写默认计数器测试为带通道 mock 的冒烟测试

## [1.6.2] - 2026-08-10

### Fixed

- fix(android): 修复 ABI 过滤不生效，APK 仅打包 arm64-v8a

### Changed

- build(android): 升级 Android 工具链至 Gradle 9.1.0 / AGP 9.0.1 / Kotlin 2.3.20 并适配旧插件
- build(deps): 更新依赖至 csv 8 / share_plus 13 等并适配 API 变更；更新 Flutter、Dart 及其他依赖项

### Docs

- docs(readme): 更新开发环境配置和构建说明

## [1.6.1] - 2025-07-25

### Fixed

- fix(main): 优化日期范围选择逻辑

## [1.6.0] - 2025-07-24

### Added

- feat(main): 新增按日期筛选短信功能

### Changed

- refactor(share): 优化短信列表分享功能
- refactor: 优化代码结构和类型
- build(dependencies): 更新多个依赖至最新版本

## [1.5.5] - 2025-04-17

### Changed

- build(dependencies): 更新多个依赖至最新版本

## [1.5.4] - 2025-04-02

### Added

- feat(main): 新增按 SIM 卡筛选短信功能
- ci: 新增 remove-old-artifacts 工作流，自动清理旧 artifact

### Changed

- 跟随 Flutter 官方迁移：本地化消息生成到源码目录，弃用 synthetic package
- docs(readme): README 多语言完善，优化翻译
- 更新依赖项版本

## [1.5.3] - 2024-12-23

### Fixed

- 修正文档拼写

### Changed

- ci: artifact 保留期设置（retention-days）
- 更新依赖

## [1.5.2] - 2024-11-05

### Added

- 一次删除超过 3000 条短信时增加提示

### Changed

- 更新依赖

## [1.5.1] - 2024-10-23

### Changed

- 升级 Flutter，更新依赖

## [1.5.0] - 2024-10-10

### Added

- 新增语言：English、繁體中文

### Changed

- 调整 CI 编译脚本

## [1.3.0] - 2024-10-01

### Added

- 长按短信新增号码复制
- 短信列表新增卡 1 / 卡 2（SIM）标识显示

### Changed

- 发布脚本新增产物上传并优化
- 应用图标大小调整

## [1.2.9] - 2024-09-25

### Added

- 新增发布脚本（fastforge 打包）

### Changed

- 更新依赖

## [1.2.8] - 2024-09-13

### Added

- 短信正文支持文字选择操作，交互改为长按触发

### Changed

- 升级 Flutter 3.24.2，并跟进 3.26.0-0.1.pre beta

## [1.2.7] - 2024-09-02

### Changed

- 升级 AGP 与 Gradle、Flutter 3.24.1，更新依赖

## [1.2.6] - 2024-08-21

### Fixed

- 优化模拟器上"还原默认短信应用"行为
- 无短信时分享操作给出提示

### Changed

- 优化模拟器图标显示
- 移除冗余的全量列表变量，列表改为局部更新

## [1.2.5] - 2024-08-16

### Fixed

- 统一所有插件的 kotlin_version 与 AGP 版本，解决不改插件源码无法编译的问题

### Changed

- 更新依赖

## [1.2.4] - 2024-08-13

### Changed

- 列表分割线增加边距
- 更新依赖

## [1.2.3] - 2024-08-07

### Added

- pubspec 增加 repository 元信息

### Changed

- 升级 Flutter 3.24.0 stable 并启用 Impeller
- Android 系统导航栏样式设置

## [1.2.2] - 2024-08-02

### Added

- 新增短信复制到剪切板功能

### Changed

- 主题色调整得更鲜艳
- 跟进 Flutter 3.24.0-0.2.pre beta，更新依赖

## [1.2.1] - 2024-07-30

### Fixed

- 首次进入且无权限时取消 loading 显示

### Changed

- 跟进 Flutter 3.24.0-0.1.pre beta

## [1.2.0] - 2024-07-25

### Added

- 一键导出短信到 CSV 文件

### Changed

- 优化搜索关闭逻辑

## [1.1.6] - 2024-07-25

### Added

- 列表增删条目加入动画效果（AnimatedList）

## [1.1.5] - 2024-07-24

### Changed

- 删除单条短信时只做局部刷新，不再刷新整个列表

## [1.1.3] - 2024-07-23

### Removed

- 移除误提交到 dist 目录的初版 APK

### Changed

- 界面调整

## [1.1.2] - 2024-07-23

### Added

- 项目首个版本：短信查询、关键字过滤、同号搜索、单条/批量删除等基础功能

（版本号 1.1.4 与 1.4.x 未被使用，历史中不存在对应发布。）
