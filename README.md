# 短信清理

本地优先的 Android 短信清理工具（Flutter + Kotlin）。浏览、筛选、多选、导出、删除短信，数据只在本机处理，不上传、不收集。

## 功能

- 短信列表：按日期分组，卡片展示号码 / 正文 / 时间 / SIM
- 筛选搜索：关键词、日期范围、类型（收件箱 / 已发送）、同号、同卡
- 多选操作：长按进入多选，按 `_id` 对齐，筛选后不错位；支持全选当前可见项
- 删除：单条滑删 / 动作 Sheet 删除 / 多选删除 / FAB 批量删除（均有确认）
- 移出列表：本地隐藏，不删系统数据，可重置
- 导出 CSV：全部或选中，RFC 4180 转义 + BOM，系统分享
- 导入 CSV：与导出同格式；**只新增**写入系统短信库（需设为默认短信应用），不覆盖、不删除
- 权限中心：读短信、默认短信应用、一键检查修复；MIUI 附带「通知类短信」引导
- 主题：8 色色盘 + 浅色 / 深色 / 跟随系统

## 权限与系统要求

| 能力 | 依赖 | 说明 |
|------|------|------|
| 读取短信 | `READ_SMS` | 列表、搜索、导出 |
| 删除短信 | 默认短信应用（`ROLE_SMS`） | Android 10+ 走 RoleManager |
| 写入 / 新短信入库 | 默认短信应用 | `SmsReceiver` 在默认时收信入库 |

冷启动不弹系统权限框；在设置或空态里主动申请。

### MIUI 注意

MIUI 在 `READ_SMS` 之外还有私有 **「通知类短信」** 开关（应用信息 → 权限管理 → 其他权限）。不开通时只能读到点对点短信，10086 / 银行等通知类会全部不可见。

该开关**无法用系统 API 代为授权**。应用在申请到读短信权限后会自动弹出引导，一键跳转 MIUI 权限页；首页也会在「可能未开通」时给出可关闭提示。

## 构建与运行

```bash
flutter pub get
flutter run                 # 调试
flutter test                # 单测 / 组件测试
flutter analyze
flutter build apk --debug   # CI 同款：验证可编译（含 Kotlin）
flutter build apk --release # 见下方「发布签名」
```

需要 Flutter 3.47+（Dart 3.13+），Android minSdk 29。

## 发布签名

release 构建**不会**把密钥写进仓库。签名材料只放在本地 `android/key.properties`（已 gitignore）。

### 1. 生成密钥（一次性）

```bash
keytool -genkey -v -keystore ~/keystore/sms-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### 2. 编写 `android/key.properties`

```properties
storeFile=/absolute/path/to/sms-release.jks
storePassword=***
keyAlias=upload
keyPassword=***
```

`storeFile` 支持绝对路径，或相对 `android/app/` 的相对路径。`*.jks` / `*.keystore` / `key.properties` 均已在 `.gitignore` 中，**请勿提交**。

也可用环境变量替代（CI Secrets 常用）：`RELEASE_STORE_FILE` / `RELEASE_STORE_PASSWORD` / `RELEASE_KEY_ALIAS` / `RELEASE_KEY_PASSWORD`。

### 3. 构建

```bash
flutter build apk --release
```

若 `android/key.properties` 与 `RELEASE_*` 环境变量均不存在，release 会**回退 debug 签名**并在 Gradle 日志打印警告——仅方便本地自测。**debug 签名的包禁止上架商店、禁止作为正式升级包分发**；上架前必须配置正式签名。

### 4. 包名说明（Breaking）

`applicationId` / `namespace` / MethodChannel / QA Intent 前缀已从 `com.dc16.sms` 改为 `com.davidche1116.sms`，降低开源后的包名冲突与仿冒风险。**已安装旧包的用户无法直接升级**，需卸载后重装（本地数据在短信系统库中，卸载本应用不影响短信本身）。

## 项目结构

```
lib/
  main.dart                 # 入口
  app.dart                  # 主题与 MaterialApp
  theme/tokens.dart         # 色盘
  models/sms_item.dart      # 短信模型
  services/                 # 通道封装 / CSV / 隐藏列表
  features/
    list/                   # 首页、卡片、动作 Sheet
    filter/                 # 筛选模型与弹层
    delete/                 # 删除确认
    settings/               # 设置 / 主题 / 权限
    widgets/                # 空态
android/app/src/main/kotlin/com/davidche1116/sms/
  MainActivity.kt           # MethodChannel 分发
  SmsAccess.kt              # 查询 / 删除 / 权限 / MIUI
  SmsReceiver.kt            # 默认短信时收信入库
```

## 设计文档

- [UI_DESIGN.md](docs/UI_DESIGN.md) — 视觉与布局
- [INTERACTION_DESIGN.md](docs/INTERACTION_DESIGN.md) — 交互与状态
- [PERMISSION_DESIGN.md](docs/PERMISSION_DESIGN.md) — 权限模型
- [QUERY_DELETE_DESIGN.md](docs/QUERY_DELETE_DESIGN.md) — 查询 / 删除契约
- [TODO.md](docs/TODO.md) — 施工清单与回归记录

## 隐私

短信内容仅用于本机展示、筛选与导出；无网络上传，无统计上报。

## 许可

本项目采用 [MIT License](LICENSE) 开源。
