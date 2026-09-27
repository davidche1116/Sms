# 短信 / 彩信查询 · 删除 · Kotlin 设计（Android 29–37）v2

> 范围：`querySms` / `deleteSmsBatch` 的完整规格（**v2 起含彩信 MMS**）。  
> 参考：老项目 `sms_advanced` 实战坑 + Android 官方 `Telephony.Sms` / `Telephony.Mms`。  
> 线协议字面量与枚举对照以 [CHANNEL_CONTRACT.md](CHANNEL_CONTRACT.md) 为准。

---

## 1. 目标与非目标

| 目标 | 非目标 |
|------|--------|
| 读 inbox / sent / draft（可按号码过滤） | 发送短信/彩信 |
| **彩信纳入同一查询/删除/导出数据面** | 彩信完整渲染（smil / 媒体播放） |
| 批量删除系统短信/彩信库 | 会话（threads）UI |
| 掉默认后可恢复、不崩溃 | 云同步、验证码自动提取 |
| 与 Dart 层简单契约 | 保留 sms_advanced 插件 |

---

## 2. 官方事实（Telephony.Sms）

来源：[Telephony.Sms | Android Developers](https://developer.android.com/reference/kotlin/android/provider/Telephony.Sms)

- 表：`content://sms`，子 URI：`Inbox` / `Sent` / `Draft` / `Outbox` / `Conversations`。
- 默认排序：`DEFAULT_SORT_ORDER = "date DESC"`。
- 列：`_id, thread_id, address, body, date, date_sent, read, type, sub_id` 等（`Telephony.TextBasedSmsColumns`）。
- **读**：`READ_SMS`；带 SMS Retriever hash 的短信对普通应用 **延迟 3 小时**，默认短信/拨号/助理等可立即读。
- **删 / 写**：仅 **默认短信应用** 可对 `content://sms` 做写/删（角色 `ROLE_SMS`，见权限设计 v3）。
- `getDefaultSmsPackage`：Android 11+ 需在 Manifest `<queries>` 声明 `SMS_DELIVER`，否则可能查不到默认包名。

---

## 3. 老项目 sms_advanced 的坑（必须避开）

| 问题 | 后果 | 本设计对策 |
|------|------|------------|
| 对**所有列** `getInt`（含 `creator` 文本列） | `NumberFormatException`/`IllegalState` → **进程崩溃** | 只按**已知列名**取值，类型安全读取 |
| 查询用 `null` 投影（全列） | 多出 `creator` 等列，放大上条问题 | **白名单投影**，不查未知列 |
| 仅 `content://sms/inbox` 等，或 OEM 对整表 URI 返回空 | 非默认/掉默认后读不到 | **多 URI 合并 + `_id` 去重** |
| 无权限时 MethodChannel **不回包** | Future 挂死、UI 假死 | **必须** success/error 二选一 |
| `SmsMessage.compareTo` 对 null `_id` 强解包 | 排序崩溃 | 不用插件排序；Dart 按 `date` 排 |
| 权限 requestCode 错位（请求 ID 与回调 ID 不一致） | 申请成功也不查询 | 权限统一走 `ActivityResult` + `checkSelf`/AppOps |
| `permission_handler.isGranted` 掉默认后假 true | 「申请成功却读不到」 | 判定用 **原生 checkSelf + AppOps** |
| SecurityException 未捕获 | 闪退 | 通道层统一 try/catch |

---

## 4. 架构

```
Dart  SmsRepository
        │  MethodChannel  com.davidche1116.sms/smsApp
        ▼
MainActivity  ──►  SmsAccess
                      ├─ querySms()
                      ├─ deleteSmsBatch()
                      ├─ insertSmsBatch()   （导入；见 §7.1）
                      └─ hasReadSms() / isDefaultSms()  （见权限设计）
```

查询/删除/导入**不**再经过 sms_advanced；Dart 只保留 `SmsItem` 模型。

---

## 5. 查询设计

### 5.1 入参

```json
{ "address": "10086", "limit": 200, "offset": 0 }
```

| 键 | 类型 | 说明 |
|----|------|------|
| `address` | String? | 可选；空/缺省 = 全部号码 |
| `limit` | Int? | 可选；**缺省 = 全量**（兼容旧调用）。非空时按 date 降序切一页 |
| `offset` | Int? | 可选；缺省 0。仅在 `limit` 非空时生效，跳过前 N 条 |

推荐 UI 使用 `limit+offset`（与 date 降序一致）；不推荐 `beforeDateMs` 游标（同 date 边界易漏/重）。

### 5.2 权限门闩

```
if (!hasReadSms() && !isDefaultSms())
  return { messages: [], error: "permission" }
```

- `hasReadSms` = `checkSelfPermission(READ_SMS) && AppOps==MODE_ALLOWED`
- 仅默认短信时无 READ_SMS 也可读（角色特权）；掉默认后特权可能被收回

### 5.3 URI 策略（单 URI 优先 + 空表回落）

| 顺序 | URI | 作用 |
|------|-----|------|
| 1 | `Telephony.Sms.CONTENT_URI` | **默认唯一**：整表（含 inbox/sent/draft/outbox/failed） |
| 2* | `Telephony.Sms.Inbox.CONTENT_URI` | 仅当整表结果为空 |
| 3* | `Telephony.Sms.Sent.CONTENT_URI` | 同上 |
| 4* | `Telephony.Sms.Draft.CONTENT_URI` | 同上 |

**为何不无条件查 4 个 URI**：AOSP 上 `content://sms` 已是 inbox/sent/draft/outbox 并集，
同批数据查 4 遍再去重是纯重复扫描（触底 `_loadMore` 会放大成本）。

**为何仍保留回落**（git `8aa3f62`，修「掉默认后空列表」）：部分 OEM（HyperOS/MIUI）
在**非默认短信应用**下对整表 URI 返回空游标，而 `inbox|sent|draft` 在仅有 READ_SMS 时仍可读。
因此：**先查整表，仅当结果为空才回落子箱**（子箱互斥，归并后按 `_id` 去重）。
回落不含 outbox/failed（那些只在整表可见；整表空时通常也读不到）。

- 单 URI 失败（Security/其他）不中断其余；最后汇总 error。
- 「整表空」以**游标是否出现过原始行**为准（无 `_id` 被丢弃的行不算空表，不触发回落）。

### 5.4 投影（白名单，禁止 null=全列）

```
_id, thread_id, address, body, date, date_sent, read, type, sub_id
```

`sub_id` 若某 ROM 无此列：`getColumnIndex == -1` 跳过，不让整次 query 失败。

### 5.5 行读取（类型安全）

| 字段 | 读取 | 空值 |
|------|------|------|
| `_id` | `getLong` → Int | 丢弃该行（无 id 无法删） |
| `thread_id` | `getLong` | null |
| `address` | `getString` | null |
| `body` | `getString` | null |
| `date` / `date_sent` | `getLong` | null |
| `read` | `getInt` | null |
| `type` | `getInt` | null → 按 Received 映射 |
| `sub_id` | `getInt` | null |

**禁止**对未在表中声明的列调用 `getInt`/`getString`。

### 5.6 排序、真分页与过滤

| 层 | 规则 |
|----|------|
| Provider | `sortOrder = "date DESC, _id DESC"`；分页时追加 `" LIMIT offset+limit"` 下推 |
| Kotlin 归并 | SMS + MMS 两条有序流归并：date 降序（null 最早）+ `is_mms` 降序 + `_id` 降序 |
| 读取短路 | 无论 LIMIT 是否被 OEM 接受，每条流最多物化 `offset+limit` 条即停 |
| Dart | 页内再排同序兜底（避免个别 ROM 列序不稳） |

按 `address` 过滤：`selection = "address = ?"`（SMS/MMS 主表可下推 SQL）。
彩信 address 在 addr 表：先取匹配 `msg_id` 集合；集合 ≤900 时下推 `_id IN (?)`，
过大则内存收窄（此时**不**下推 LIMIT，短路按命中数计）。

**真分页（P0-1）**：

```
每流:  count(整表) → rows(LIMIT offset+limit, 短路)
归并:  各流前 offset+limit 条做有序归并 → drop(offset).take(limit)
total: 分页 = 两流 count 之和；全量 = 可用行数
```

- `offset+limit` 取前缀即可保证归并后切页正确（全局前 N 条里任一条流贡献不超过 N 条）。
- **绝不**再全量读进 `LinkedHashMap` 再 drop/take。
- LIMIT 下推失败（OEM 忽略）由读取短路兜底，成本 O(offset+limit) 而非 O(全库)。
- 边界：`limit=0` 只 count 不扫行；`offset` 越界回空页 + 真 `total`；负 `offset` 按 0。

**分页切片必须在归并之后**，否则跨页会漏/重。`total` 始终是去重后的库内总数，与是否分页无关。

### 5.7 返回契约

```json
{
  "messages": [
    {
      "_id": 1, "thread_id": 10,
      "address": "10086", "body": "…",
      "date": 1789000000000, "date_sent": 1789000000000,
      "read": 1, "type": 1, "sub_id": 0
    }
  ],
  "total": 12345,
  "error": null
}
```

| 字段 | 含义 |
|------|------|
| `messages` | 本页（或全量）行，date 降序 |
| `total` | 去重后总数；便于 UI「已加载 X / total 条」 |
| `error` | 见下表 |

| error | 含义 | Dart |
|-------|------|------|
| `null` | 成功（messages 可为 []） | 列表 / 空态 |
| `"permission"` | 无读能力且非默认 | 提示申请权限 |
| `"unknown"` | 其他失败 | 提示操作失败 / 重试 |

**有数据则 error 必须为 null**（不因单 URI 异常而丢已有结果）。

### 5.8 type → 业务 kind（Dart）

| Telephony type | 含义 | kind |
|----------------|------|------|
| 1 | INBOX | Received |
| 2,4,5,6 | SENT/OUTBOX/FAILED/QUEUED | Sent |
| 3 | DRAFT | Draft |

---

## 5M. 彩信（MMS）查询（P3-17）

### 5M.1 身份与 id 策略

- **wire 身份 = `_id` + `is_mms` 二元组**。SMS / MMS 各自独立编号，`_id` 可能同号，合并时必须分表去重。
- Dart `SmsItem.uid = isMms ? id + (1<<30) : id`，用于多选 / 隐藏 / 去重 / 卡片 key；**删除传原生 `id` + `is_mms`**，不用 `uid`。
- 返回行在 §5.7 基础上增加 `is_mms`（0/1）与 `has_media`（0/1）。

### 5M.2 URI 策略

与 SMS 同构：**默认只查 `Telephony.Mms.CONTENT_URI`**，仅当整表为空才回落
`Inbox` / `Sent` / `Draft`（路径是 `drafts`），归并后按 `_id` 去重。
地址过滤经 `content://mms/addr` 预取 `msg_id`，小集合下推 `_id IN`（见 §5.6）。
`readMmsRow` 需有 `msg_box` 列，否则跳过（防误喂 SMS Cursor）。

### 5M.3 列与换算

| 字段 | 来源 | 说明 |
|------|------|------|
| `_id` | `_id` | 表内 id |
| `thread_id` | `thread_id` | |
| `date` / `date_sent` | `date` / `date_sent` | **彩信表是秒**，`< 1e11` 视为秒并 ×1000，否则原样 |
| `read` | `read` | |
| `type` | `msg_box` | 1..5，与 SMS type 同构 |
| `sub_id` | `sub_id` | |
| `address` | `content://mms/addr` | 页面级补全，见 §5M.4 |
| `body` | `content://mms/part` | 页面级补全，见 §5M.5 |

### 5M.4 address（addr 表）

- 收件优先 `type=137`（FROM），否则 `151`（TO），再否则首个非空。
- **地址过滤**：`content://mms/addr` 按 `address=?` 先取 `msg_id` 集合，再收窄 MMS 行（addr 表无法用 selection 直接过滤主表）。过滤集为空则跳过 MMS 主表扫描。
- 只对**本页**彩信批量补全（`msg_id IN (...)`，900 分片），不做全库 N+1。

### 5M.5 body 摘要（part 表）

- 文本 part：`ct ∈ {text/plain, text/x-vcard, text/x-vcalendar, text/html}`，取 `text` 列拼接（`\n` 连接）。
- 媒体 part：`image/*`、`audio/*`、`video/*`，或带 `_data` 的 `application/*`（除 smil）→ `has_media=1`。
- 无文本 part → `body=""`，由 Dart `SmsItem.bodyOf(l10n)` 显示本地化占位「[彩信]」/「[彩信]·含附件」。
- **不读 part 文件 `_data` 正文**（图片/音频不解析），只做计数标记。

### 5M.6 排序

date 降序（null 最早）→ `is_mms` 降序 → `_id` 降序。与 Dart `uid` 序一致，保证分页稳定。

---

## 6. 删除设计

### 6.1 入参

```json
[1, 2, 3]                              // 旧：纯 SMS _id 列表
[{"id": 1, "is_mms": 0}, {"id": 2, "is_mms": 1}]   // 新：混合
```

### 6.2 权限门闩

```
if (isDefaultSms() != true) return null   // Dart 提示「设为默认短信」
```

- 非默认：Provider 拒绝写；**不要**静默部分成功。
- 判定用 `RoleManager.isRoleHeld(ROLE_SMS)`（29+）。

### 6.3 执行

```
splitDeleteTargets(targets) → (smsIds, mmsIds)
  smsIds.chunked(900) → contentResolver.delete(Telephony.Sms.CONTENT_URI, "_id IN …")
  mmsIds.chunked(900) → contentResolver.delete(Telephony.Mms.CONTENT_URI, "_id IN …")
```

| 规则 | 说明 |
|------|------|
| **绝不跨表** | `is_mms=0` 只进 sms URI，`=1` 只进 mms URI |
| 未知形态丢弃 | 无 `id`、`is_mms` 非 0/1/bool 的 Map 不猜测路由 |
| `is_mms` 缺省 | 按 SMS 处理（兼容旧 `List<Int>`） |

| 返回 | 含义 |
|------|------|
| Map `{ok, deleted, failed, error, errors}` | 见 §7.2；`deleted` = 实际删除行数（SMS+MMS，≥0） |
| （旧）`Int` | 兼容：全成条数 |
| （旧）`null` | 兼容：非默认 / 异常（不可区分） |

### 6.4 单条删除

- 同一批量路径：`deleteSmsBatch([id])`，不再走插件 `removeSmsById`。
- UI 单条删除（左滑 / 动作 Sheet）与多选 / FAB **一律先弹确认**（P0-2）：确认成功才删，取消或失败**回弹** UI（滑删卡片滑回）；无撤销。

### 6.5 与查询的一致性

- 删除后 **主动重查**（或按 id 本地移除），避免列表残留。
- `id` 必须来自查询结果的 `_id`，禁止用下标。

---

## 7. 通道方法（与权限设计对齐）

| Method | 参数 | 返回 |
|--------|------|------|
| `querySms` | `{address?, limit?, offset?}` 或 null | 见 §5.7（含 `total`、`is_mms`） |
| `deleteSmsBatch` | `List<Int>` 或 `List<{id, is_mms}>` | 见 §7.2 Map |
| `insertSmsBatch` | `List<{address, body, date, type, sub_id}>` | 见 §7.1 Map |
| `hasReadSmsPermission` | — | `bool` |
| `isDefaultSms` | — | `bool?` |
| （已有）`setDefaultSms` 等 | — | 见 PERMISSION_DESIGN v3 |

所有 handler **try/catch** → `result.error("error", …)`，禁止裸抛。

### 7.1 insertSmsBatch 返回契约（P2-12）

```json
{
  "ok": true,
  "inserted": 16,
  "failed": 2,
  "errors": [
    { "index": 3,  "code": "failed", "message": "insert returned null" },
    { "index": 17, "code": "failed", "message": "…" }
  ]
}
```

| 字段 | 含义 |
|------|------|
| `ok` | false=整批未执行（非默认等）；true=已受理（**可含部分失败**） |
| `inserted` | 成功条数 |
| `failed` | 失败条数（= errors 中行级条目数） |
| `errors[]` | 逐行失败明细 |
| `errors[].index` | 入参 rows 下标（0-based）；**-1=整批级**（如非默认） |
| `errors[].code` | `not_default` \| `failed` \| `unknown` |
| `errors[].message` | 原生补充说明，可空 |

| code | 含义 | Dart |
|------|------|------|
| `not_default` | 非默认短信应用，整批未执行 | toast「导入需先设为默认短信应用」 |
| `failed` | 单行插入失败（insert 回 null 或抛异常） | 计入 failed，文案「已导入 X / Y 条（N 条失败）」 |
| `unknown` | 保留值：形态异常/未知 code 的安全默认（Dart 解析兜底） | 同上 |

**兼容**：旧调用方读 `Int?`（null=失败、int=成功条数）。新契约返回 Map，
Dart `InsertBatchResult.fromWire` / `DeleteBatchResult.fromWire` 同时接受
Map / int / null；**旧 int 解析路径仅作兼容保留**，新代码一律按 Map 解析。

### 7.2 deleteSmsBatch 返回契约（P1-1）

```json
{
  "ok": true,
  "deleted": 12,
  "failed": 2,
  "error": null,
  "errors": [
    { "index": 3, "code": "failed", "message": "…" }
  ]
}
```

| 字段 | 含义 |
|------|------|
| `ok` | false=整批未执行/整批失败；true=已受理（**可含部分失败**） |
| `deleted` | 实际删除行数（SMS+MMS，contentResolver 返回值之和） |
| `failed` | 失败条数（逐 chunk 计入） |
| `error` | `null` \| `not_default` \| `failed` \| `unknown`（整批级） |
| `errors[]` | 逐条失败明细；`index` 对齐入参 `{id,is_mms}` 载荷下标（-1=整批级） |

| error | 含义 | Dart / UI |
|-------|------|-----------|
| `null` | 成功或部分成功 | 部分时 toast「已删除 X / N 条后失败」 |
| `not_default` | 非默认，整批未执行 | toast「删除失败：请先设为默认短信应用」 |
| `failed` | 原生异常导致整批失败 | toast「删除失败，请重试」（**不**误报设为默认） |
| `unknown` | 解析兜底 | 同 notDefaultOrError（不可区分） |

**逐 chunk 失败隔离**：SMS / MMS 各自 `chunked(900)` 独立 try/catch；一侧抛异常
不影响另一侧已删计数，`errors[].index` 精确到入参下标。零删且零失败（全是
「本就不在库中」）也算成功。

**事务策略与系统限制（必读）**：

1. **逐行 insert + 尽量全成 + 逐行明细**：每行独立 `contentResolver.insert`，
   失败只影响该行并记录 `index/code/message`，其余行继续，不中途放弃。
2. **为何不用 `applyBatch` 整批提交**（调研后否决）：
   - AOSP `SmsProvider` 不覆写 `applyBatch`，默认实现**逐条 apply、无事务**，
     中途失败已成功的行不回滚——「批」本身并不原子；
   - `OperationApplicationException` **不暴露失败下标**（公开 API 只有
     `getNumSuccessfulYieldPoints`，语义是 yield 点数而非操作数），失败后无法
     安全定位续插起点；盲目重试整片会**重复插入**真实短信。
3. 因此不做整批回滚（回滚需按 _id 删，存在二次失败与误删风险），
   改为保证 `inserted` 计数准确、错误可对应 CSV 行。
4. index 对应 CSV `parse()` 后行下标（表头已跳过），可直接映射回导入行定位。
5. 大列表：Dart 侧按 `SmsRepository.insertChunkSize=200` 行分片过通道
   （单条 platform message 受 Binder ~1MB 上限），errors[].index 重映射为
   **全局**下标；内存上不整表复制，只切片 sublist。

**UI 增量加载约定（P1-6）**：
- 启动/下拉刷新拉第一页（`limit=200, offset=0`）；滚动触底按 `offset=已加载条数` 追加，按 `_id` 去重。
- **筛选仍是客户端过滤**：筛选条件激活时一次性 `queryAll()` 补齐全量，保证结果完整；补全失败则退化为「筛选基于已加载数据」。
- **导出「全部」必须 `queryAll()` 全量**，不得用已加载分页当全库。

---

## 8. 模块划分（Kotlin）

```
com.davidche1116.sms/
  MainActivity.kt     # 仅分发
  SmsAccess.kt        # query / delete / hasRead / isDefault   ← 本设计主体
  SmsReceiver.kt      # 默认时收信入库（已实现）
  MmsReceiver.kt
  HeadlessSmsSendService.kt
```

`SmsAccess` 内聚查询/删除，**不**再拆一层「查询器」除非超过 ~200 行。

---

## 9. 边界与错误

| 场景 | 行为 |
|------|------|
| 无 READ_SMS 且非默认 | error=`permission` |
| 仅默认、无 READ_SMS | 仍查询（角色特权） |
| 掉默认后进程被杀 | 冷启动重判权限 |
| 单 URI SecurityException | 记 error 候选，继续其他 URI |
| 全部 URI 空且无异常 | messages=[]，error=null |
| delete 非默认 | return null |
| delete 空数组 | return 0 |
| `_id` 缺失行 | 查询丢弃，不进列表 |

---

## 10. Dart 映射（查询结果）

```
SmsItem { id, threadId, address, body, dateMs, read, type, subId, kind, isMms, hasMedia, uid }
```

- `kind` 由 `type` 映射（§5.8），不用 fromJson 强解包 date。
- `dateMs == null` → 排序哨兵，不崩溃。
- `uid` = `isMms ? id + (1<<30) : id`：多选 / 隐藏 / 去重专用；删除用 `id` + `isMms`。
- `bodyOf(l10n)`：彩信无文本时回本地化占位。

---

## 11. 测试要点（实现阶段）

1. 原生 query 返回多行 → 列表、日期降序。  
2. `error=permission` → UI 权限提示。  
3. 批量 delete 成功 / 非默认 null。  
4. 投影缺 `sub_id` 仍返回其他字段。  
5. 回归：不对 `creator` 等列 getInt（可用带该列的假 Cursor 测读取函数）。  
6. 真机：设默认 → 读/删 → 改默认 → 重开 → 权限/查询。  
7. insertSmsBatch：mock 新 Map 形状 → Dart 解析 inserted/failed/errors；旧 int/null 兼容。  
8. CsvImporter 端到端：全成 / 部分失败 / 非默认 / 原生失败 → toast 文案与错误摘要。  
9. 真机：QA_IMPORT_TEST 走同一通道，核对 IMPORT_BATCH 的 inserted/failed/errors。
10. **真分页（P0-1）**：5k 假数据 `limit=20, offset=30` → 行消费 ≤50（短路）；
    sortOrder 带 `LIMIT 50`；整表有数据时**不**查子箱 URI；整表空时回落子箱并去重。
11. 边界：`limit=0` 只 count、`offset` 越界空页 + total、负 offset 归零。

---

## 12. 待确认

1. 查询是否包含 **Outbox/FAILED**（整表 URI 会带上）？建议 **要**，type 映射为 Sent，便于清理。  
2. 批量删除上限 UI（如 >3000 条）是否保留「提示后继续」？（1.x 有）  
3. 快速删除是否要「撤销」？建议 **v1 不做**（已落地：无撤销；所有删除入口先确认，失败回弹）。

---

## 13. 来源

- [Telephony.Sms](https://developer.android.com/reference/kotlin/android/provider/Telephony.Sms)（CONTENT_URI、子表、date DESC、Retriever 延迟、getDefaultSmsPackage 的 queries）  
- [RoleManager](https://developer.android.com/reference/android/app/role/RoleManager) / [默认处理程序权限](https://developer.android.com/guide/topics/permissions/default-handlers)  
- 本仓库 `docs/PERMISSION_DESIGN.md` v3、老项目 sms_advanced 真机与源码结论
