![LOGO](android/app/src/main/res/mipmap-xhdpi/ic_launcher.png)

# 簡訊清理

[简体中文](README_zh.md) | 繁體中文 | [English](README.md)

- 簡訊清理是使用Flutter框架編寫的Android平台上讀取、批量刪除簡訊的清理工具。
- 雖然UI框架Flutter支援跨平台，但僅實現了Android簡訊刪除功能。

## 功能描述

- 獲取簡訊權限
- 複製簡訊到剪貼簿
- 設置/恢復預設簡訊應用
- 關鍵字過濾簡訊信息
- 同號碼簡訊搜索
- 從搜索結果移除/直接刪除簡訊
- 一鍵批量刪除查詢結果簡訊
- 一鍵導出所有簡訊到csv文件

## 界面截圖
![UI](assets/screenshot/ui.jpg)

## 隱私說明

- 所有簡訊資料僅保存在**本機**。應用程式不發起任何網路請求，不會上傳、同步或自動分享任何資料。
- 匯出的 CSV 檔案僅寫入應用程式暫存目錄，只在主動觸發匯出時透過系統分享面板分享。
- 刪除簡訊不可復原，批次刪除前請確認篩選條件。
- AndroidManifest 中宣告的權限及用途：
  - `READ_SMS` / `RECEIVE_SMS` / `RECEIVE_MMS` / `RECEIVE_WAP_PUSH`：讀取與管理簡訊/多媒體訊息。
  - `SEND_SMS`：預設簡訊應用程式角色所需（應用程式本身不傳送簡訊）。
  - `READ_PHONE_STATE`：部分 Android 版本上預設簡訊應用程式角色所需。
  - `READ_CONTACTS` / `READ_PROFILE` / `QUERY_ALL_PACKAGES`：隨簡訊外掛一併宣告，應用程式本身未使用。
  - 預設簡訊應用程式：Android 僅允許預設簡訊應用程式刪除簡訊，應用程式會引導暫時切換，並可還原原預設應用程式。

## 開發環境

- Flutter 3.47.2 (stable)
- Dart 3.13.2
- Gradle 9.3.1
- Android Gradle Plugin 9.1.0
- Kotlin 2.4.10
- compileSdk 37 / minSdk 26
- JDK 17

## 構建與發佈

使用 fastforge 打包 release：

```bash
dart pub global activate fastforge
fastforge release --name apk
```

產物輸出到 `dist/` 目錄。APK 使用 release 簽名，且僅打包 **arm64-v8a** 單 ABI。

### CI 工作流

| 工作流 | 觸發時機 | Flutter 渠道 | 內容 |
| --- | --- | --- | --- |
| `build.yml` | push main（版本 tag 除外）/ PR 新建或更新 | stable | `dart analyze` + `flutter test` + 構建 APK + 上傳 artifact |
| `manual.yml` | 手動觸發 | beta / master / stable 可選（預設 stable） | `dart analyze` + `flutter test` + 構建 APK + 上傳 artifact |
| `publish.yml` | 版本 tag（如 `1.6.1+250725`） | stable | 構建 APK + 建立草稿 Release |

### 構建注意事項

- `permission_handler` 已升級到 `13.0.2`：v13 要求 compileSdk 37，因此 `android/app/build.gradle.kts` 硬編碼 `compileSdk = 37`（高於 Flutter 3.47 模板的 36），配合 AGP 9.1.0 + Android SDK Platform 37。權限程式碼遵循 v13 request-driven 模式（不從 `status` 推導 `permanentlyDenied`）。
- 老外掛（如 `sms_advanced 1.1.0`，AGP 4.1 時代產物）缺少 `namespace` 且寫死 `compileSdk 31`，根 `android/build.gradle.kts` 中自動用 `project.group` 補全 namespace，並把舊庫模組的 compileSdk 抬升到 37。
- lint 相關任務在 `android/build.gradle.kts` 中被跳過：舊外掛的 buildscript 釘老版本 AGP，與根工程 AGP 9.1.0 混載會導致 lint worker（`AndroidLintWorkAction`）崩潰，因此統一禁用 lint 系列任務，並為 `extract*Annotations` 任務生成佔位產物。
- `android/gradle.properties` 中設定了 `kotlin.incremental=false`：Windows 上 Kotlin 增量編譯無法處理原始碼（C: 碟 pub 快取）與構建產物（D: 碟工程）跨磁碟的情況。
- `sms_advanced` 外掛自身應用了 Kotlin Gradle Plugin，未來版本 Flutter 將拒絕構建，需留意替代方案。
- 程式碼品質由 CI 中的 `dart analyze` + `flutter test` 保證。
- 本地執行測試：`flutter test`（平台通道已 mock，無需真機）。

## 專案結構

```
Sms
├─android              # Android工程配置
├─assets               # 資源檔案目錄
├─lib                  # Flutter原始碼目錄
│  ├─main.dart         # APP入口與介面
│  └─services          # 資料存取與純邏輯（簡訊儲存庫 / 篩選 / CSV匯出）
├─.github/workflows    # CI 工作流
└─dist                 # 構建產物目錄
```
