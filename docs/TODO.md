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
| 筛选功能 | 🔴 半残 | 关键词/同号/同卡生效；**日期范围、类型未参与过滤** |
| 数据模型 | 🔴 缺字段 | `SmsItem` 无 `dateMs`/`type`，导致排序、日期筛选、类型筛选无法实现 |
| 演示残留 | 🟡 3 处 | 菜单「申请短信权限」、PermissionPage 整页、导出 CSV（导出已拍板保持简单提示，可缓） |
| 测试 / README | 🔴 未做 | widget_test 仍是默认计数器测试；README 是 Flutter 模板 |

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

### 4.1 替换 `widget_test.dart`（部分完成 ✅ 2026-09-27）

已覆盖：首页冒烟（mock 通道）、SmsItem type→kind 映射、date null 不崩溃、dayLabel/time 格式、SmsFilter active/reset/copy。仍待补：`error=permission` → NeedPerm 空态、多选筛选后不错位、CSV 转义、Kotlin 侧假 Cursor 单测（§11.4/§11.5）。

### 4.2 真机回归（2026-09-27 已执行，设备：红米 M2104K10AC / Android 13 / MIUI V140）

| # | 路径 | 结果 |
|---|------|------|
| 1 | 首次安装 → 打开 | ✅ NeedPerm 空态，冷启动不弹系统权限框 |
| 2 | 点申请 → 允许 | ✅ 系统弹窗 → 始终允许 → 列表加载 |
| 3 | 筛选关键词 | ✅ 781 → 501 条，Chip「"10086"」+ 清除全部 |
| 4 | 点卡片 → 同号 | ✅ 242 条，双 Chip 叠加（同号 + 关键词） |
| 5 | 非默认快删 | ✅ toast 引导设默认，**数据未被误删**（9 条保持） |
| 6 | 设默认后快删 | ⏸ 真实删除留待用户确认后执行（避免误删真实短信） |
| 7 | FAB 删全部 | ⏸ 同上（781 条真实数据，需明确授权） |
| 8 | 多选导出 | ✅ 全选 242 → 导出选中 → 系统分享 `sms_selected_*.csv`，CSV 内容验证（BOM/转义/kind 列） |
| 9 | 设置改主题色 | ✅ 8 色盘实时换肤（绿→蓝→绿），hex 同步 |
| 10 | 深色模式 | ✅ 深色 token 生效，已恢复跟随系统 |

**附加验证**：清除筛选后多选选中集按 _id 保留（242 条不错位）——多选改 _id 的核心价值在真机确认；设置页权限组/数据组/一键修复渲染完整。

#### ⚠️ MIUI 特有发现（重要）

1. **「通知类短信」私有权限**：MIUI 在 应用信息 → 权限管理 → 其他权限 → **通知类短信**（默认拒绝）。不开通时应用只能读到普通点对点短信（本机 9 条），开通后通知类短信（10086/银行等，770+ 条）全部可见。**这是 MIUI 特有行为，非标准 READ_SMS 能覆盖**。
2. **adb 授予 ROLE_SMS 无效于短信库**：`cmd role add-role-holder` 后 `isRoleHeld=true`、设置页显示"本应用"，但 MIUI 短信库不放行；必须走应用内「设为默认」→ RoleManager 官方弹窗才真正生效。本机 `settings get secure sms_default_application` 始终为 null（MIUI 不写该 legacy 设置）。
3. **产品建议（新增待办）**：权限子页检测 MIUI（`ro.miui.ui.version.name` 非空）时增加「通知类短信」引导行（检测该 AppOps 状态 + 跳转应用详情权限页），否则 MIUI 用户会以为应用"只能读到一部分短信"。

#### 待人工确认后执行

- FAB 全量删除 / 真实单条删除（涉及 781 条真实短信，需用户指定可删对象）
- 收新短信 → SmsReceiver 入库验证（等一条真实新短信即可）

### 4.3 README.md

替换 Flutter 模板：项目简介、功能列表、权限说明（READ_SMS / ROLE_SMS）、构建方式、设计文档索引。

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
| 7 | 测试补齐（§4.1，部分完成） | test/ | 🟡 |
| 8 | 真机回归 + README（§4.2/§4.3） | — | 待做 |

> §4（测试补齐剩余项、真机回归、README）为收尾阶段工作。
