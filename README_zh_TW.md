![LOGO](android/app/src/main/res/mipmap-xhdpi/ic_launcher.png)

# 簡訊清理

[English](README.md) | [简体中文](README_zh.md) | 繁體中文


本機優先的 Android 簡訊 / 多媒體簡訊清理工具（Flutter + Kotlin）。瀏覽、篩選、多選、匯出、刪除簡訊與多媒體簡訊，資料只在本機處理，不上傳、不收集。

## 功能

- 消息列表：按日期分組，卡片展示號碼 / 正文 / 時間 / SIM；多媒體簡訊帶「多媒體簡訊」徽章，含附件時標註
- 篩選搜索：關鍵字、日期范圍、類型（收件匣 / 已傳送 / 僅多媒體簡訊）、同號、同卡
- 多選操作：長按進入多選，按 `uid` 對齊（SMS/MMS 同號不衝突），篩選後不錯位；支持全選當前可見項
- 刪除：單條滑刪 / 動作 Sheet 刪除 / 多選刪除 / FAB 批量刪除（均有確認）；按 `is_mms` 路由，不會誤刪對方同號行
- 移出列表：本機隱藏，不刪系統資料，可重置
- 匯出 CSV：全部或選中，RFC 4180 轉義 + BOM，系統分享；含 `is_mms` 列
- 匯入 CSV：與匯出同格式；**只新增**寫入系統簡訊庫（需設為預設簡訊應用程式），不覆蓋、不刪除；**多媒體簡訊行跳過**（無法簡單重建）
- 權限中心：讀簡訊、預設簡訊應用程式、一鍵檢查修複；MIUI 附帶「通知類簡訊」引導
- 主題：8 色色盤 + 淺色 / 深色 / 跟隨系統
- 多語言：簡體中文、繁體中文、English

### 多媒體簡訊支援範圍

納入統一資料面：**瀏覽 / 篩選 / 刪除 / 匯出**。正文摘要取 `content://mms/part` 的文本 part（text/plain、vcard 等）；無文本時顯示「[多媒體簡訊]」占位，含圖片/音频/視频附件時另標「含附件」。不做完整渲染（smil 布局 / 圖片音频播放）。

**預設簡訊應用程式時的新多媒體簡訊**：`MmsReceiver` 會把 `WAP_PUSH_DELIVER` 通知 **元資料入庫**（發件人 / 時間 / 主題 / Message-ID / Content-Location）到 `content://mms/inbox` + `addr`，避免新多媒體簡訊整條丟失。完整 smil / 圖片 / 音频正文**不會下載重建**（依賴非公開 `PduPersister`，本應用不實現 MMS 客戶端）；列表正文為占位「[多媒體簡訊]」或主題摘要。需要完整多媒體簡訊內容時，請在系統設定里把預設簡訊應用程式改回系統「信息」後再接收（或用系統應用收下後回到本工具清理）。

## 介面預覽

![UI](assets/screenshot/ui.jpg)

## 權限與系統要求

| 能力 | 依賴 | 說明 |
|------|------|------|
| 讀取簡訊/多媒體簡訊 | `READ_SMS` | 列表、搜索、匯出；多媒體簡訊讀取同權限，無需額外申請 |
| 刪除簡訊/多媒體簡訊 | 預設簡訊應用程式（`ROLE_SMS`） | Android 10+ 走 RoleManager |
| 寫入 / 新簡訊入庫 | 預設簡訊應用程式 | `SmsReceiver` 在預設時收信入庫 |
| 新多媒體簡訊入庫 | 預設簡訊應用程式 | `MmsReceiver` 寫通知元資料骨架（見「多媒體簡訊支援範圍」） |

冷啟動不彈系統權限框；在設定或空態里主動申請。

### MIUI 注意

MIUI 在 `READ_SMS` 之外還有私有 **「通知類簡訊」** 開關（應用信息 → 權限管理 → 其他權限）。不開通時只能讀到點對點簡訊，10086 / 銀行等通知類會全部不可見。

該開關**無法用系統 API 代為授權**。應用在申請到讀簡訊權限後會自動彈出引導，一鍵跳轉 MIUI 權限頁；首頁也會在「可能未開通」時給出可關閉提示。

## 建置與執行

```bash
flutter pub get
flutter run
flutter test
flutter analyze
cd android && ./gradlew :app:testDebugUnitTest
flutter build apk --debug
flutter build apk --release
```

需要 Flutter 3.47+（Dart 3.13+），Android minSdk 29。

## 發佈簽名

release 使用隨倉庫分發的簽名材料（與 1.x 一致）：

- `android/key.properties` — 密碼與別名
- `android/app/key/sms.keystore` — 金鑰庫（`storeFile` 相對 `android/app/`）

```bash
flutter build apk --release
```

若缺少 `key.properties`，release 會回退 debug 簽名（僅本機自測）。

## 專案結構

```
lib/
  main.dart                 # 入口
  app.dart                  # 主題與 MaterialApp
  theme/tokens.dart         # 色盤
  models/sms_item.dart      # 簡訊模型
  services/                 # 通道封裝 / CSV / 隱藏列表
  features/
    list/                   # 首頁、卡片、動作 Sheet
    filter/                 # 篩選模型與彈層
    delete/                 # 刪除確認
    settings/               # 設定 / 主題 / 權限
    widgets/                # 空態
android/app/src/main/kotlin/com/dc16/sms/
  MainActivity.kt           # MethodChannel 分發
  SmsAccess.kt              # 查詢 / 刪除 / 權限 / MIUI
  SmsReceiver.kt            # 預設簡訊時收信入庫
```


## 隱私

簡訊內容僅用於本機展示、篩選與匯出；無網路上傳，無統計上報。

## 許可

本項目采用 [MIT License](LICENSE) 開源。
