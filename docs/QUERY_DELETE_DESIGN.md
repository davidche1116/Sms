# 短信查询 / 删除 · Kotlin 设计（Android 29–37）v1

> 范围：`querySms` / `deleteSmsBatch` 的完整规格。  
> 参考：老项目 `sms_advanced` 实战坑 + Android 官方 `Telephony.Sms`。  
> **本阶段只定设计，不写实现。**

---

## 1. 目标与非目标

| 目标 | 非目标 |
|------|--------|
| 读 inbox / sent / draft（可按号码过滤） | 发送短信、彩信解析 |
| 批量删除系统短信库 | 会话（threads）UI |
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

### 5.3 URI 策略（合并去重）

| 顺序 | URI | 作用 |
|------|-----|------|
| 1 | `Telephony.Sms.CONTENT_URI` | 整表（含 outbox/failed 等） |
| 2 | `Telephony.Sms.Inbox.CONTENT_URI` | 收件箱 |
| 3 | `Telephony.Sms.Sent.CONTENT_URI` | 已发送 |
| 4 | `Telephony.Sms.Draft.CONTENT_URI` | 草稿 |

- 同一条在整表与分箱会重复 → **按 `_id` 去重**（`LinkedHashMap`）。
- 单 URI 失败（Security/其他）不中断其余 URI；最后汇总 error。

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

### 5.6 排序与过滤

| 层 | 规则 |
|----|------|
| Provider | 不强制 `ORDER BY`（整表默认 `date DESC`；分箱可不带） |
| Kotlin 合并 | **date 降序**（null 最早）+ `_id` 降序稳定次键；再 `drop(offset).take(limit)` |
| Dart | 页内再排同序兜底（避免个别 ROM 列序不稳） |

按 `address` 过滤：`selection = "address = ?"`（与插件「查后内存过滤」一致，SQL 更省）。

**分页切片必须在合并去重 + 全局排序之后**，否则跨页会漏/重。`total` 始终是去重后的库内总数，与是否分页无关。

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

## 6. 删除设计

### 6.1 入参

```json
[1, 2, 3]          // _id 列表
```

### 6.2 权限门闩

```
if (isDefaultSms() != true) return null   // Dart 提示「设为默认短信」
```

- 非默认：Provider 拒绝写；**不要**静默部分成功。
- 判定用 `RoleManager.isRoleHeld(ROLE_SMS)`（29+）。

### 6.3 执行

```
ids.chunked(900)     // SQLITE_MAX_VARIABLE_NUMBER 默认 999
  → contentResolver.delete(
        Telephony.Sms.CONTENT_URI,
        "_id IN (?, ?, …)",
        args
    )
```

| 返回 | 含义 |
|------|------|
| `Int` | 实际删除行数（≥0） |
| `null` | 非默认 / 异常 / 参数非法 |

### 6.4 单条删除

- 同一批量路径：`deleteSmsBatch([id])`，不再走插件 `removeSmsById`。
- UI「快速删除」：先本地移除，再调批量接口；失败 toast（2.0 可不做撤销）。

### 6.5 与查询的一致性

- 删除后 **主动重查**（或按 id 本地移除），避免列表残留。
- `id` 必须来自查询结果的 `_id`，禁止用下标。

---

## 7. 通道方法（与权限设计对齐）

| Method | 参数 | 返回 |
|--------|------|------|
| `querySms` | `{address?, limit?, offset?}` 或 null | 见 §5.7（含 `total`） |
| `deleteSmsBatch` | `List<Int>` | `Int?` |
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
Dart `InsertBatchResult.fromWire` 同时接受 Map / int / null；**旧 int 解析路径仅作
兼容保留**，新代码一律按 Map 解析。`deleteSmsBatch` 仍回 `Int?`（另项任务）。

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
SmsItem { id, threadId, address, body, dateMs, read, type, subId, kind }
```

- `kind` 由 `type` 映射（§5.8），不用 fromJson 强解包 date。
- `dateMs == null` → 排序哨兵，不崩溃。

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

---

## 12. 待确认

1. 查询是否包含 **Outbox/FAILED**（整表 URI 会带上）？建议 **要**，type 映射为 Sent，便于清理。  
2. 批量删除上限 UI（如 >3000 条）是否保留「提示后继续」？（1.x 有）  
3. 快速删除是否要「撤销」？建议 **v1 不做**。

---

## 13. 来源

- [Telephony.Sms](https://developer.android.com/reference/kotlin/android/provider/Telephony.Sms)（CONTENT_URI、子表、date DESC、Retriever 延迟、getDefaultSmsPackage 的 queries）  
- [RoleManager](https://developer.android.com/reference/android/app/role/RoleManager) / [默认处理程序权限](https://developer.android.com/guide/topics/permissions/default-handlers)  
- 本仓库 `docs/PERMISSION_DESIGN.md` v3、老项目 sms_advanced 真机与源码结论
