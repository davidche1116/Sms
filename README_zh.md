![LOGO](android/app/src/main/res/mipmap-xhdpi/ic_launcher.png)

# 短信清理

简体中文 | [繁體中文](README_zh_TW.md) | [English](README.md)

- 短信清理是Flutter框架编写的在Android上读取、批量删除短信的短信清理工具。
- 虽然UI框架Flutter支持跨平台，但仅实现了Android短信删除功能。

## 功能描述

- 获取短信权限
- 复制短信到剪切板
- 设置/恢复默认短信应用
- 关键字过滤短信信息
- 同号码短信搜索
- 从搜索结果移除/直接删除短信
- 一键批量删除查询结果短信
- 一键导出所有短信到csv文件

## 界面截图
![UI](assets/screenshot/ui.jpg)

## 隐私说明

- 所有短信数据仅保存在**本机**。应用不发起任何网络请求，不会上传、同步或自动分享任何数据。
- 导出的 CSV 文件仅写入应用临时目录，只在主动触发导出时通过系统分享面板分享。
- 删除短信不可恢复，批量删除前请确认过滤条件。
- AndroidManifest 中声明的权限及用途：
  - `READ_SMS` / `RECEIVE_SMS` / `RECEIVE_MMS` / `RECEIVE_WAP_PUSH`：读取与管理短信/彩信。
  - `SEND_SMS`：默认短信应用角色所需（应用本身不发送短信）。
  - `READ_PHONE_STATE`：部分 Android 版本上默认短信应用角色所需。
  - `READ_CONTACTS` / `READ_PROFILE` / `QUERY_ALL_PACKAGES`：随短信插件一并声明，应用本身未使用。
  - 默认短信应用：Android 仅允许默认短信应用删除短信，应用会引导临时切换，并可恢复原默认应用。

## 开发环境

- Flutter 3.47.2 (stable)
- Dart 3.13.2
- Gradle 9.3.1
- Android Gradle Plugin 9.1.0
- Kotlin 2.4.10
- compileSdk 37 / minSdk 26
- JDK 17

## 构建与发布

使用 fastforge 打包 release：

```bash
dart pub global activate fastforge
fastforge release --name apk
```

产物输出到 `dist/` 目录。APK 使用 release 签名，且仅打包 **arm64-v8a** 单 ABI。

### CI 工作流

| 工作流 | 触发时机 | Flutter 渠道 | 内容 |
| --- | --- | --- | --- |
| `build.yml` | push main（版本 tag 除外）/ PR 新建或更新 | stable | `dart analyze` + `flutter test` + 构建 APK + 上传 artifact |
| `manual.yml` | 手动触发 | beta / master / stable 可选（默认 stable） | `dart analyze` + `flutter test` + 构建 APK + 上传 artifact |
| `publish.yml` | 版本 tag（如 `1.6.1+250725`） | stable | 构建 APK + 创建草稿 Release |

### 构建注意事项

- `permission_handler` 已升级到 `13.0.2`：v13 要求 compileSdk 37，因此 `android/app/build.gradle.kts` 硬编码 `compileSdk = 37`（高于 Flutter 3.47 模板的 36），配合 AGP 9.1.0 + Android SDK Platform 37。权限代码遵循 v13 request-driven 模式（不从 `status` 推导 `permanentlyDenied`）。
- 老插件（如 `sms_advanced 1.1.0`，AGP 4.1 时代产物）缺少 `namespace` 且写死 `compileSdk 31`，根 `android/build.gradle.kts` 中自动用 `project.group` 补全 namespace，并把旧库模块的 compileSdk 抬升到 37。
- lint 相关任务在 `android/build.gradle.kts` 中被跳过：旧插件的 buildscript 钉老版本 AGP，与根工程 AGP 9.1.0 混载会导致 lint worker（`AndroidLintWorkAction`）崩溃，因此统一禁用 lint 系列任务，并为 `extract*Annotations` 任务生成占位产物。
- `android/gradle.properties` 中设置了 `kotlin.incremental=false`：Windows 上 Kotlin 增量编译无法处理源码（C: 盘 pub 缓存）与构建产物（D: 盘工程）跨盘符的情况。
- `sms_advanced` 插件自身应用了 Kotlin Gradle Plugin，未来版本 Flutter 将拒绝构建，需留意替代方案。
- 代码质量由 CI 中的 `dart analyze` + `flutter test` 保证。
- 本地运行测试：`flutter test`（平台通道已 mock，无需真机）。

## 项目结构

```
Sms
├─android              # Android工程配置
├─assets               # 资源文件目录
├─lib                  # Flutter源代码目录
│  ├─main.dart         # APP入口与界面
│  └─services          # 数据访问与纯逻辑（短信仓库 / 过滤 / CSV导出）
├─.github/workflows    # CI 工作流
└─dist                 # 构建产物目录
```
