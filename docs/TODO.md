# 短信清理 2.0 · 待办与优化清单（TODO）

> 生成日期：2026-09-27
> 适用项目：`/Users/fang/StudioProjects/sms`
> 定位：基于 4 份设计文档（UI / INTERACTION / PERMISSION / QUERY_DELETE）对现有代码的**差距分析**，是接下来的施工清单；完成一项勾掉一项，改动涉及设计决策时回写对应设计文档。

---

## 0. 现状总览

| 层 | 状态 | 说明 |
|----|------|------|
| Kotlin 原生层 | ✅ 基本完成 | `SmsAccess`（多 URI 合并去重、白名单投影、类型安全读取、chunk 900 删除、checkSelf+AppOps、RoleManager）、`MainActivity` 通道分发、Manifest 4 组件 + queries 均已按设计落地 |
| Dart 通道封装 | ✅ 基本完成 | `SmsRepository` 薄封装对齐通道契约 |
| UI 骨架 | 🟡 大体完成 | 列表/多选/动作 Sheet/FilterSheet/确认弹层/设置页/空态三态/主题系统均已成型 |
| 筛选功能 | ✅ 完成 | 关键词/同号/同卡/日期范围/类型均已生效（`SmsFilter.matches`） |
| 数据模型 | ✅ 完成 | `SmsItem` 含 `dateMs`/`type`/`sim`/`read` + `kind` 映射 |
| 演示残留 | ✅ 已接真 | 权限申请、PermissionPage、CSV 导出均为真实现 |
| 测试 / README | ✅ 基本完成 | 11 项测试全过；README 已重写；Kotlin 假 Cursor 可选 |

已拍板（2026-09-26，见 INTERACTION_DESIGN §9）：冷启动不弹系统权限框；设置页做一键检查修复；移出列表保留且 FAB 批量删除不含已移出项；导出保持简单提示。

---

## 1. P0 · 功能补完（2026-09-27 已全部完成 ✅）

### 1.1 `SmsItem` 模型补字段 ✅

已完成：`lib/models/sms_item.dart` —— `dateMs/type/sim/read` + `kind` 映射（§5.8）；`time/dayLabel` 改为模型 getter，并修复跨月「昨天」边界 bug（改用自然日差值）。

### 1.2 Dart 层按 date 降序排序 ✅

已完成：`SmsRepository._query()` 返回前 `list.sort((a,b) => (b.dateMs ?? 0).compareTo(a.dateMs ?? 0))`。

### 1.3 日期范围筛选生效 ✅

已完成：`_visible` 增加日期过滤；`end` 按当天 23:59:59.999 闭区间；`dateMs == null` 的行被日期筛选取舍。

### 1.4 类型筛选生效 ✅

已完成：`_visible` 按 `kind` 过滤（1=仅收件箱 received；2=仅已发送，草稿归入发送侧）；筛选 Chip 行新增类型 Chip。

### 1.5 多选从下标改为 `_id` ✅

已完成：`_selected` 语义为 `_id` 集合；勾选/长按/全选（针对当前可见列表）/删除/导出全链路按 id 匹配；`_id == null` 的行不可选中；刷新后 `_pruneSelection()` 裁剪失效项。

---

## 2. P1 · 演示残留接真（2026-09-27 已完成 2.1 / 2.2）

### 2.1 更多菜单「申请短信权限」✅

~~现状：`_toast('演示：申请短信权限')`。~~
已完成：菜单与空态统一走 `_requestPermission()` → `_repo.requestReadSms()` → toast + `_load()`。

### 2.2 PermissionPage 整页是写死演示 ✅

~~现状：状态硬编码「已授予」、4 个按钮全是演示 toast，且没有任何入口导航到它。~~
已完成（方案 A）：重写为 StatefulWidget 权限子页——实时 `hasReadSms`/`isDefaultSms` 状态卡、刷新按钮、按状态显示「申请短信权限 / 设为默认短信应用」、打开应用设置、打开系统默认应用设置；设置页「短信权限」行导航进入。配套改动：
- 原生新增 `openAppSettings` 通道（`ACTION_APPLICATION_DETAILS_SETTINGS`），修正 Dart 侧原 `openAppSettingsFallback` 调错通道的问题；
- 设置页权限组新增第三行「一键检查并修复」（request → setDefault → 刷新，对齐已拍板 §9.2）。

### 2.3 导出 CSV ✅（2026-09-27 已实现真导出）

已完成：`lib/services/csv_exporter.dart` —— 写入应用文档目录（`path_provider`，无需存储权限）+ `share_plus` 系统分享；RFC 4180 转义（逗号/引号/换行），带 BOM 方便 Excel 中文；列 `address,body,date,kind,sub_id`。三个入口全部接真：更多菜单「导出全部」、多选底栏「导出选中」、设置页「导出短信 CSV」。

---

## 3. 架构 / 代码设计优化（2026-09-27 已完成 3.1–3.4 ✅）

### 3.1 拆分 `home_page.dart` ✅

已完成（原 1669 行 → 按目标结构拆分）：

```
lib/
  main.dart                        # 仅 runApp
  app.dart                         # SmsApp + 主题构建
  theme/tokens.dart                # kSeedPresets
  models/sms_item.dart             # SmsItem + SmsKind + 时间格式化
  services/sms_repository.dart     # 通道封装（不再依赖 UI 层）
  services/csv_exporter.dart       # CSV 导出 + 分享
  services/hidden_store.dart       # 隐藏 id 持久化
  features/
    list/home_page.dart            # 状态机 + _load + 筛选/多选/删除/导出编排
    list/sms_card.dart             # 列表项卡片（含左滑删除）
    list/action_sheet.dart         # 列表项动作 Sheet
    filter/filter_sheet.dart       # SmsFilter 模型 + 筛选弹层
    delete/confirm_sheet.dart      # 删除确认弹层
    settings/settings_page.dart
    settings/theme_page.dart
    settings/permission_page.dart
    widgets/empty_view.dart        # 空态三态
```

### 3.2 修正反向依赖 ✅

已完成：`SmsRepository` 只依赖 `models/sms_item.dart`；`_time/_day` 格式化移入 `SmsItem` getter。

### 3.3 删除 `kDemoSms` 演示数据 ✅

已完成：演示数据与 NeedPerm 分支的死代码一并清除。

### 3.4 隐藏列表持久化 ✅

已完成（选择了做）：`HiddenStore`（SharedPreferences）——启动加载、移出即存、删除自动清理；设置页「数据」组新增「重置本地隐藏列表」行（显示已隐藏条数）。

### 3.5 状态管理边界（维持现状）

`setState` 全局重建可接受；**暂不引入** Provider/Riverpod。拆文件后若 props 传递超过两层再评估。

### 3.6 删除进度（维持现状）

删除为一次批量调用，ConfirmSheet 进度仅作提示（弱化版，符合设计容差）；真实进度需通道改流式，v1 不做。

---

## 4. 测试与收尾

### 4.1 替换 `widget_test.dart`（基本完成 ✅ 2026-09-27 第二轮）

已覆盖（11 项全过）：首页冒烟、`error=permission` → NeedPerm 空态、筛选后多选按 `_id` 不错位、SmsItem type→kind / date null / dayLabel、SmsFilter active/reset/copy/**matches**、CsvExporter.escapeField（RFC 4180）。`SmsFilter.matches` 已从 `home_page._visible` 抽出，便于单测。

仍可选补：Kotlin 侧假 Cursor 单测（§11.4/11.5，需 Robolectric/androidTest 基建，优先级低）。

### 4.2 真机回归（2026-09-27 已执行，设备：红米 M2104K10AC / Android 13 / MIUI V140）

| # | 路径 | 结果 |
|---|------|------|
| 1 | 首次安装 → 打开 | ✅ NeedPerm 空态，冷启动不弹系统权限框 |
| 2 | 点申请 → 允许 | ✅ 系统弹窗 → 始终允许 → 列表加载 |
| 3 | 筛选关键词 | ✅ 781 → 501 条，Chip「"10086"」+ 清除全部 |
| 4 | 点卡片 → 同号 | ✅ 242 条，双 Chip 叠加（同号 + 关键词） |
| 5 | 非默认快删 | ✅ toast 引导设默认，**数据未被误删**（9 条保持） |
| 6 | 设默认后快删 | ✅ **仅用测试数据验证**（见 4.2.1），真实短信零改动 |
| 7 | FAB 删全部 | ✅ 同上：产品 `deleteSmsBatch` 路径已用测试 id 验证，未对真实数据执行 |
| 8 | 多选导出 | ✅ 全选 242 → 导出选中 → 系统分享 `sms_selected_*.csv`，CSV 内容验证（BOM/转义/kind 列） |
| 9 | 设置改主题色 | ✅ 8 色盘实时换肤（绿→蓝→绿），hex 同步 |
| 10 | 深色模式 | ✅ 深色 token 生效，已恢复跟随系统 |
| 11 | MIUI 通知类短信引导 | ✅ 权限子页检测 MIUI + AppOps 状态 + 跳转权限编辑器（§2.2 产品建议） |
| 12 | 删除链路（测试数据） | ✅ 见 4.2.1，真实库 779 条 id/address 哈希前后一致 |

**附加验证**：清除筛选后多选选中集按 _id 保留（242 条不错位）——多选改 _id 的核心价值在真机确认；设置页权限组/数据组/一键修复渲染完整。

#### 4.2.1 删除链路安全验证（2026-09-27，约束：不碰真实短信）

约定：只插入带唯一前缀 `SMSCLEANUP_QA_20260927` 的测试短信，只删这些；真实 779 条以 `_id`/`address` 哈希作不变量。

| 步骤 | 操作 | 结果 |
|------|------|------|
| 0 | 快照 | count=779，ids_md5=`1d2aefc3…`，addr_md5=`36efeca9…`，marker=0 |
| 1 | `QA_INSERT_TEST` ×3 | ok，ids=[1341,1342,1343]，count=782 |
| 2 | `QA_DELETE_IDS` → `deleteSmsBatch([1341,1342,1343])`（产品路径，前缀过滤后） | deleted=3，count=779，ids_md5 **完全一致** |
| 3 | `QA_INSERT_TEST` ×2 | ok，ids=[1341,1342]，count=781 |
| 4 | `QA_DELETE_TEST` 按前缀删除 | deleted=2，count=779 |
| 5 | 终检 | count=779，ids_md5=addr_md5 与步骤 0 **完全一致**，marker=0 |

结论：插入 / 按 id 删除 / 按前缀清理均可用；**真实短信零丢失、零改动**。测试后已把 `ROLE_SMS` 还原给 `com.android.mms`。

辅助：debug 包 QA Intent（仅 FLAG_DEBUGGABLE）：`com.dc16.sms.QA_INSERT_TEST` / `QA_DELETE_TEST` / `QA_DELETE_IDS`，结果写 `filesDir/qa_result.txt`。

#### ⚠️ MIUI 特有发现（重要）

1. **「通知类短信」私有权限**：MIUI 在 应用信息 → 权限管理 → 其他权限 → **通知类短信**（默认拒绝）。不开通时应用只能读到普通点对点短信（本机 9 条），开通后通知类短信（10086/银行等，770+ 条）全部可见。**这是 MIUI 特有行为，非标准 READ_SMS 能覆盖**。
2. **adb 授予 ROLE_SMS 对「读库」无效、对写入有效**：`cmd role add-role-holder` 后 `isRoleHeld=true`，ContentResolver **insert/delete 可成功**（本次测试数据即走此路径），但 MIUI 短信库 **读列表** 仍可能受「通知类短信」过滤；完整体验仍建议走应用内「设为默认」→ RoleManager 弹窗。本机 `settings get secure sms_default_application` 始终为 null（MIUI 不写该 legacy 设置）。
3. **产品建议** → **已落地（2026-09-27）**：权限子页检测 MIUI（`ro.miui.ui.version.name`）+ 探测通知类短信状态 + `miui.intent.action.APP_PERM_EDITOR` 跳转。
4. **能否在申请短信权限时一并自动处理？（2026-09-27 结论）**
   - **不能自动授权**：「通知类短信」是 MIUI 私有开关，无公开 Permission/AppOps 字符串（本机 `RECEIVE_NOTIFICATION_SMS` 等均为 Unknown），第三方只能跳设置页。
   - **已做成「申请后自动跟一步」**：`requestReadSmsWithMiuiGuide`——READ_SMS 成功后检测状态，非 `allow` 立即弹引导层（「去开启」/「稍后」），一键打开 MIUI 权限编辑器。菜单、空态、权限页、一键修复共用。
   - **额外兜底提示**：首页在 MIUI + 可能未开通时显示可关闭横幅；权限子页保留状态卡与入口。
   - **状态探测**：已知 op 名 + 启发式（已能读到 10086 等服务号 → allow；仅少量点对点号码 → likely_off）。

#### 待人工确认后执行

- 收新短信 → SmsReceiver 入库验证（等一条真实新短信即可）
  - **限制**：`SMS_DELIVER` 为系统保护广播，adb 无法注入；`service call isms` 亦不可用。
  - **已覆盖**：`SmsAccess.insertInbox` 与 QA 插入共用写入路径，insert/delete 已验证；
    `SmsReceiver` 仅 3 行胶水（`getMessagesFromIntent` → `insertInbox`）。
  - **请协助**：本应用设为默认后，由另一部手机发一条测试短信即可闭环。
- FAB 对**真实**全量删除仅在你明确指定可删对象后执行（本次刻意未做）

#### 2026-09-27 最短路径收尾

| 项 | 结果 |
|----|------|
| pubspec 版本 / 描述 | ✅ `2.0.0+2` + 项目简介 |
| push origin/dev | ✅ `5ddfb1c..3ccf07c` |
| MIUI 引导组件测试 | ✅ 未开通弹层 / allow 不弹（共 13 项全过） |
| 真机 MIUI 检测 | ✅ `QA_QUERY_STATE` → `miui=true notif=allow read=true default=false`（与你已开启通知类短信一致） |
| 真实数据 | ✅ 779 条，ids_md5 不变 |

### 4.3 README.md（✅ 2026-09-27）

已替换 Flutter 模板：项目简介、功能列表、权限说明（含 MIUI）、构建方式、项目结构、设计文档索引、隐私说明。

---

## 5. 建议施工顺序

| 序 | 事项 | 文件 | 预估 |
|----|------|------|------|
| 1 | 多选改 `_id`（§1.5，消除误删风险） | home_page.dart | ✅ 已完成 |
| 2 | SmsItem 补字段 + Dart 排序（§1.1/§1.2） | main.dart→models、repository | ✅ 已完成 |
| 3 | 日期 + 类型筛选生效（§1.3/§1.4） | home_page.dart | ✅ 已完成 |
| 4 | 菜单申请权限接真（§2.1） | home_page.dart | ✅ 已完成 |
| 5 | PermissionPage 接真或删除（§2.2） | settings 相关 | ✅ 已完成 |
| 6 | 拆分 home_page + 修反向依赖 + 删演示数据（§3.1–§3.3） | lib/ 整体 | ✅ 已完成 |
| 7 | 测试补齐（§4.1） | test/ | ✅ 11 项（Kotlin 假 Cursor 可选） |
| 8 | 真机回归 + README（§4.2/§4.3） | — | ✅ 删除链路已用测试数据验证 |
| 9 | MIUI 通知类短信引导 | permission_page + SmsAccess | ✅ |
| 10 | 删除安全验证（测试数据） | QA Intent + deleteSmsBatch | ✅ 真实数据哈希不变 |

> 仅剩可选项：Kotlin 假 Cursor 单测、收新短信入库验证、真实全量删除（需明确授权）。
