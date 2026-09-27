# 通道契约 · MethodChannel `com.davidche1116.sms/smsApp`

> 本文是 Dart ↔ Kotlin 的**唯一权威线协议表**。协议字符串以双端 `ChannelCodes` 为准：  
> [`lib/services/channel_codes.dart`](../lib/services/channel_codes.dart) ↔ [`android/app/src/main/kotlin/com/davidche1116/sms/ChannelCodes.kt`](../android/app/src/main/kotlin/com/davidche1116/sms/ChannelCodes.kt)。  
> 业务代码只准引用常量 / 枚举，禁止散落裸字面量；**改线值必须双端同步**并更新 `test/channel_codes_test.dart`。  
> 权限模型见 [PERMISSION_DESIGN.md](PERMISSION_DESIGN.md)；查询/删除实现细节见 [QUERY_DELETE_DESIGN.md](QUERY_DELETE_DESIGN.md)。

分发层：`MainActivity`（`OnceResult` 保证 success/error/notImplemented 只回一次）→ `SmsAccess`。Dart 封装：`SmsRepository`。

---

## 1. 方法总表

| Method | 参数 | 返回 |
|--------|------|------|
| `hasReadSmsPermission` | — | `bool` |
| `requestReadSms` | — | `bool`（true=已可读） |
| `isDefaultSms` | — | `bool?`（null=无法判定） |
| `setDefaultSms` | — | `"had"` \| `"no"` \| `"error"` |
| `restoreDefaultSms` | — | `"not_default"` \| `"settings"` \| `"error"` |
| `openDefaultSmsSettings` | — | `bool` |
| `openAppSettings` | — | `bool` |
| `isMiui` | — | `bool` |
| `miuiNotificationSmsState` | — | `"allow"` \| `"likely_off"` \| `"ignore"` \| `"deny"` \| `"unknown"` |
| `openMiuiPermissionEditor` | — | `bool` |
| `querySms` | `{address?, limit?, offset?}` | `{messages, total, error, partial, warnings}` |
| `deleteSmsBatch` | `List<Int>` \| `List<Map{id,is_mms}>` | Map（见 §4） |
| `insertSmsBatch` | `List<row>` | Map（见 §5） |
| `insertTestSms` | `{count?, bodyPrefix?}` | `{ok, ids}` |
| `deleteTestSmsByPrefix` | `{bodyPrefix?}` | `{ok, deleted}` |

未知方法 → `notImplemented`。handler 内异常 → `result.error("error", message, null)`（见 §7）。

---

## 2. 权限 / 默认短信

| Method | 语义 | 线值 |
|--------|------|------|
| `hasReadSmsPermission` | `checkSelfPermission(READ_SMS)` **且** AppOps `OPSTR_READ_SMS == MODE_ALLOWED` | `bool`；异常当 false |
| `requestReadSms` | 拉起系统 READ_SMS 弹窗；已有读权限直接 true；已有弹窗在途直接 false（Dart 会再查） | `bool` |
| `isDefaultSms` | `RoleManager.isRoleHeld(ROLE_SMS)`（不可用时退回 `getDefaultSmsPackage`） | `true` / `false` / `null` |
| `setDefaultSms` | **唯一路径** `SmsAccess.setDefaultSms`（MainActivity 只挂 pending / 拉起角色页）：已是默认直接回 `had`；否则 `createRequestRoleIntent` for-result，失败/不可用则打开默认应用页 | 见下表 |
| `restoreDefaultSms` | 还原为系统默认（Q+ 只能打开「默认应用」页） | 见下表 |
| `openDefaultSmsSettings` | `ACTION_MANAGE_DEFAULT_APPS_SETTINGS` | `bool` 是否成功拉起 |
| `openAppSettings` | 本应用系统设置页 | `bool` |

### `setDefaultSms` 线值

| 线值 | `ChannelCodes` | Dart `DefaultSmsResult` | 含义 |
|------|----------------|-------------------------|------|
| `had` | `setDefaultHad` / `SET_DEFAULT_HAD` | `alreadyDefault` | 已是默认短信应用 |
| `no` | `setDefaultNo` / `SET_DEFAULT_NO` | `requested` | 已发起角色请求或已打开系统设置 |
| `error` | `error` / `ERROR` | `error` | 失败（含未知线值） |

Dart 侧另有 **非线值** `DefaultSmsResult.timeout`：系统未在 `SmsRepository.systemResponseTimeout`（默认 2 分钟）内返回，或 Activity 销毁（`lifecycle`）后回查仍非默认。UI 应提示可去设置手动开启。

### `restoreDefaultSms` 线值

| 线值 | `ChannelCodes` | Dart `RestoreDefaultResult` | 含义 |
|------|----------------|-----------------------------|------|
| `not_default` | `restoreNotDefault` / `RESTORE_NOT_DEFAULT` | `notDefault` | 本就不是默认 |
| `settings` | `restoreSettings` / `RESTORE_SETTINGS` | `openedSettings` | 已打开系统「默认应用」页 |
| `error` | `error` / `ERROR` | `error` | 打开失败（含未知线值） |

### MIUI 通知类短信

| Method | 说明 |
|--------|------|
| `isMiui` | `ro.miui.ui.version.name` 非空 |
| `miuiNotificationSmsState` | AppOps 候选 op + 查询启发式 |
| `openMiuiPermissionEditor` | `miui.intent.action.APP_PERM_EDITOR`，失败回落 `openAppSettings` |

| 线值 | `ChannelCodes` | Dart `MiuiNotifState` | 当前 Kotlin 是否产生 |
|------|----------------|----------------------|----------------------|
| `allow` | `miuiAllow` / `MIUI_ALLOW` | `allow` | 是 |
| `likely_off` | `miuiLikelyOff` / `MIUI_LIKELY_OFF` | `likelyOff` | 是 |
| `ignore` | `miuiIgnore` / `MIUI_IGNORE` | `ignore` | **否**（历史兼容，UI 仍分支） |
| `deny` | `miuiDeny` / `MIUI_DENY` | `deny` | **否**（历史兼容） |
| `unknown` | `miuiUnknown` / `MIUI_UNKNOWN` | `unknown` | 是（含非 MIUI / 探测失败 / 未知线值） |

---

## 3. `querySms`

### 入参 Map

| 键 | 类型 | 说明 |
|----|------|------|
| `address` | `String?` | 空/缺省 = 全部号码 |
| `limit` | `Int?` | **缺省 = 全量**；非空时按 date 降序切一页 |
| `offset` | `Int?` | 缺省 0；仅在 `limit` 非空时生效 |

### 返回 Map

| 键 | 类型 | 说明 |
|----|------|------|
| `messages` | `List<Map>` | 本页（或全量）行，date 降序 |
| `total` | `Int` | 去重后的库内总数（与是否分页无关） |
| `error` | `String?` | 见下表 |
| `partial` | `bool` | 有数据但部分子查询失败 = `true`；与 `error` **互斥** |
| `warnings` | `List<Map>` | 部分失败明细 `[{code, message}]`；`partial=false` 时为 `[]` |

行字段（白名单投影）：`_id, thread_id, address, body, date, date_sent, read, type, sub_id, is_mms, has_media`。无 `_id` 的行原生直接丢弃。

| 字段 | 说明 |
|------|------|
| `is_mms` | `0`=短信 / `1`=彩信。**身份 = `_id` + `is_mms` 二元组**（两表 `_id` 独立编号，可能同号） |
| `has_media` | 仅彩信：`1`=含非文本附件（图片/音频/视频）。短信恒 `0` |
| `body` | 彩信为文本 part 摘要（可空串）；展示占位由 Dart `SmsItem.bodyOf` 补 |
| `date` | 一律毫秒。彩信表原生是**秒**，原生层已换算 |

Dart 侧另有 `SmsItem.uid`（`is_mms=1` 时 `id + 2^30`）用于多选/隐藏/去重；**删除仍用原生 `_id` + `is_mms`**，不要用 `uid` 传给删除。

| `error` 线值 | `ChannelCodes` | Dart `QueryError` | 含义 |
|--------------|----------------|-------------------|------|
| `null` | — | `none` | 成功或部分成功（`messages` 可为 `[]`；部分成功见 `partial`） |
| `permission` | `queryErrorPermission` / `QUERY_ERROR_PERMISSION` | `permission` | 无读能力且非默认 |
| `unknown` | `queryErrorUnknown` / `QUERY_ERROR_UNKNOWN` | `unknown` | 其他完全失败 |

**`error` 与 `partial` 互斥**（P1-2 部分失败上报）：

| 场景 | `error` | `partial` | `warnings` |
|------|---------|-----------|------------|
| 全成功（含空库） | `null` | `false` | `[]` |
| 有数据但某路子查询失败 | `null` | `true` | 非空 |
| 完全无数据且失败 | `permission` \| `unknown` | `false` | 可非空（诊断用） |

- **有数据则 `error` 必须为 `null`**（不因单 URI 异常丢已有结果）；此时若还有其它路失败，改用 `partial=true` + `warnings` 上报，UI 轻提示「部分短信可能未加载」+ 可重试。
- `warnings[].message` 为**固定文案**（`sms query restricted` 等），**不含** URI / 文件路径 / `exception.message`，可安全打日志。
- **向后兼容**：旧客户端只读 `messages/total/error` 时行为不变（`error` 语义大体保持：有数据即 null）；`partial`/`warnings` 为新增键，忽略即仍能看到已加载行，只是不提示可能不完整。

`warnings[].code` 线值：

| code | `ChannelCodes` | Dart `QueryWarning.code` | 触发点 |
|------|----------------|--------------------------|--------|
| `sms_uri_security` | `WARN_SMS_URI_SECURITY` / `warnSmsUriSecurity` | `warnSmsUriSecurity` | SMS 表查询 SecurityException |
| `sms_uri_failed` | `WARN_SMS_URI_FAILED` / `warnSmsUriFailed` | `warnSmsUriFailed` | SMS 表查询其它异常 |
| `mms_uri_security` | `WARN_MMS_URI_SECURITY` / `warnMmsUriSecurity` | `warnMmsUriSecurity` | MMS 表查询 SecurityException |
| `mms_uri_failed` | `WARN_MMS_URI_FAILED` / `warnMmsUriFailed` | `warnMmsUriFailed` | MMS 表查询其它异常 |
| `mms_addr_failed` | `WARN_MMS_ADDR_FAILED` / `warnMmsAddrFailed` | `warnMmsAddrFailed` | `mms/addr` 过滤预取 / 号码富化失败 |
| `mms_part_failed` | `WARN_MMS_PART_FAILED` / `warnMmsPartFailed` | `warnMmsPartFailed` | `mms/part` 正文富化失败 |
| `unknown` | `WARN_UNKNOWN` / `warnUnknown` | `warnUnknown` | 保留值：形态异常/未知 code 的安全默认 |

Dart：`QueryError.permission` → `SmsQueryPermissionException`；`unknown` → 普通异常；
`error=null && partial=true` → 正常返回 `SmsQueryPage(partial: true, warnings: […])`，不抛。

分页约定（UI）：启动/刷新 `limit=200, offset=0`，触底按 `offset=已加载条数` 追加并按 `_id` 去重；筛选激活时补齐全量；导出「全部」必须 `queryAll()`。

**真分页（P0-1）**：原生对 SMS/MMS 各自 `ORDER BY date DESC, _id DESC` 并下推 `LIMIT offset+limit`，
归并后只物化本页；`total` 用 count 与切页解耦。默认只查 `content://sms` / `content://mms` 整表，
**仅当整表为空**才回落 inbox/sent/draft（历史 OEM 坑，见 [QUERY_DELETE_DESIGN §5.3](QUERY_DELETE_DESIGN.md)）。
分页不因触底 `_loadMore` 放大总扫描量。

### type → 业务 kind

| Telephony `type` | 含义 | `SmsKind` |
|------------------|------|-----------|
| 1 | INBOX | `received` |
| 2, 4, 5, 6 | SENT / OUTBOX / FAILED / QUEUED | `sent` |
| 3 | DRAFT | `draft` |

---

## 4. `deleteSmsBatch`

| 方向 | 形状 |
|------|------|
| 入参 | `List<Int>`（纯 SMS `_id`，旧调用兼容）或 `List<Map>` `[{id: Int, is_mms: 0\|1}]`（混合） |
| 返回 | Map（新契约，见下）；旧 `Int?` 由 Dart `fromWire` 兼容解析 |

### 返回 Map（新契约）

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

| 键 | 类型 | 说明 |
|----|------|------|
| `ok` | `bool` | `false`=整批未执行/整批失败；`true`=已受理（**可含部分失败**） |
| `deleted` | `Int` | 实际删除行数（SMS + MMS 之和）；空数组回 `0` |
| `failed` | `Int` | 失败条数（逐 chunk 计入） |
| `error` | `String?` | 整批级错误，见下表；成功/部分成功为 `null` |
| `errors` | `List<Map>` | 逐条失败明细 |
| `errors[].index` | `Int` | 入参 targets 下标（0-based）；**`-1` = 整批级**（如非默认） |
| `errors[].code` | `String` | `not_default` \| `failed`（同 `error` 线值） |
| `errors[].message` | `String?` | 原生补充说明，可空 |

| `error` 线值 | `ChannelCodes` | Dart `BatchFailure` | 含义 |
|--------------|----------------|---------------------|------|
| `null` | — | —（ok=true） | 成功或部分成功（部分时 `failed>0` + `errors[]`） |
| `not_default` | `deleteErrorNotDefault` / `DELETE_ERROR_NOT_DEFAULT` | `notDefault` | 非默认短信应用，**整批未执行** |
| `failed` | `deleteErrorFailed` / `DELETE_ERROR_FAILED` | `native` | 原生异常导致整批失败（零删零成功） |
| `unknown` | `deleteErrorUnknown` / `DELETE_ERROR_UNKNOWN` | `notDefaultOrError` | 保留值：形态异常/未知 code 的安全默认（Dart 解析兜底） |

- 原生按 `is_mms` 分组后各自 `ids.chunked(900)` 再 `"_id IN (...)"` 删除：SMS 走 `content://sms`，MMS 走 `content://mms`，**绝不跨表**。
- **逐 chunk 计入 failed**：某 chunk 抛异常时该 chunk 内全部目标记失败（`errors[]` 逐条、`index` 对齐入参载荷）并继续后续 chunk（尽量全成）。
- Map 形态缺 `id` 或 `is_mms` 非 0/1/true/false 时：缺 id 丢弃；`is_mms` 缺省按 SMS。
- **部分成功**：`ok=true, deleted=N, failed=M, errors[]`。零删且零失败（全是「本就不在库中」）也算成功。
- Dart `DeleteBatchResult`：`ok(deleted, failed, errors)` / `failed(failure)`；`fromWire` 同时接受 Map / int / null。
- **兼容**：旧调用方可能读 `Int?`（null=失败、int=全成条数）。旧原生 int → `ok(n)`，null → `failed(notDefaultOrError)`。
- 删除入口（单条滑删 / 动作 Sheet / 多选 / FAB）**均先弹确认**；取消或失败时滑删卡片回弹、列表不改。
- UI 失败文案按 `failure` 分支：`notDefault` → 「请先设为默认短信应用」；`native` → 「删除失败，请重试」；部分成功 → 「已删除 X / N 条后失败」。**不再一律提示设为默认**。

---

## 5. `insertSmsBatch`（CSV 导入，只新增）

### 入参 `List<row>`

| 键 | 类型 | 说明 |
|----|------|------|
| `address` | `String?` | 号码 |
| `body` | `String?` | 正文 |
| `date` | `Long?` | 毫秒时间戳；缺省 `now` |
| `type` | `Int?` | 1 inbox / 2 sent / 3 draft（2/4/5/6 → Sent URI）；缺省 1 |
| `sub_id` | `Int?` | 可空则不写 SUBSCRIPTION_ID |

**下标对齐（P1-6）**：Kotlin 解析**不得**丢弃非 Map 行（避免 `mapNotNull` 与 Dart `errors[].index` 错位）。非 Map 行按**原下标**记 `errors[{index, code: "invalid"}]` 并计入 `failed`；其余行继续插入。`inserted + failed`（已受理时）恒等于入参长度。

### 返回 Map（新契约）

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

| 键 | 类型 | 说明 |
|----|------|------|
| `ok` | `bool` | `false`=整批未执行（非默认等）；`true`=已受理（**可含部分失败**） |
| `inserted` | `Int` | 成功条数 |
| `failed` | `Int` | 失败条数 |
| `errors` | `List<Map>` | 逐行失败明细 |
| `errors[].index` | `Int` | 入参 rows 下标（0-based）；**`-1` = 整批级**（如非默认） |
| `errors[].code` | `String` | 见下表 |
| `errors[].message` | `String?` | 原生补充说明，可空 |

| `code` 线值 | `ChannelCodes` | 含义 |
|-------------|----------------|------|
| `not_default` | `insertErrorNotDefault` / `INSERT_ERROR_NOT_DEFAULT` | 非默认短信应用，整批未执行 |
| `failed` | `insertErrorFailed` / `INSERT_ERROR_FAILED` | 单行插入失败（insert 回 null 或抛异常） |
| `invalid` | `insertErrorInvalid` / `INSERT_ERROR_INVALID` | 入参行形态非法（非 Map）：按原下标记失败，**不丢弃、不打乱 index** |
| `unknown` | `insertErrorUnknown` / `INSERT_ERROR_UNKNOWN` | 保留值：形态异常/未知 code 的安全默认（Dart 解析兜底） |

**兼容**：旧调用方可能读 `Int?`（null=失败、int=全成条数）。Dart `InsertBatchResult.fromWire` 同时接受 Map / int / null；新代码一律按 Map 解析。

**分片**：Dart `SmsRepository.insertChunkSize = 200` 行/次过通道（Binder ~1MB 上限），`errors[].index` 重映射为**全局**下标（`-1` 不变）；整批失败后不再发后续分片。

**策略**：逐行 `contentResolver.insert` + 尽量全成 + 逐行明细；**不用** `applyBatch`（AOSP SmsProvider 无事务且不暴露失败下标），不做整批回滚。详见 [QUERY_DELETE_DESIGN.md §7.1](QUERY_DELETE_DESIGN.md)。

---

## 6. QA / 测试辅助（debug-only）

仅 `FLAG_DEBUGGABLE` 包生效；需当前为默认短信应用。写库只碰 `bodyPrefix`（默认 `SMSCLEANUP_TEST`）前缀行。

| Method | 参数 | 返回 |
|--------|------|------|
| `insertTestSms` | `{count: int = 3, bodyPrefix: string = "SMSCLEANUP_TEST"}` | `{ok: bool, ids: List<Int>}` |
| `deleteTestSmsByPrefix` | `{bodyPrefix: string = "SMSCLEANUP_TEST"}` | `{ok: bool, deleted: Int}` |

| 键 | `ChannelCodes` |
|----|----------------|
| `ok` | `keyOk` / `KEY_OK` |
| `ids` | `keyIds` / `KEY_IDS` |
| `deleted` | `keyDeleted` / `KEY_DELETED` |

adb QA Intent（action 前缀 `com.davidche1116.sms.QA_*`）用法见 [CONTRIBUTING.md](../CONTRIBUTING.md)。Intent 侧走同一套 `SmsAccess` API，**不是** MethodChannel 方法。

---

## 7. 错误码（PlatformException）

| `PlatformException.code` | `ChannelCodes` | 来源 | Dart 处理 |
|--------------------------|----------------|------|-----------|
| `error` | `error` / `ERROR` | handler catch-all：`result.error("error", e.message, null)` | 视方法：多为失败态 / 打印后回退 |
| `lifecycle` | `errorLifecycle` / `ERROR_LIFECYCLE` | Activity 销毁 / 引擎换绑时收尾挂起的 `Result`（`requestReadSms` / `setDefaultSms`） | 映射为 timeout 语义，**回查一次真实状态**，绝不永久 pending |

注意区分：

- **载荷内 `error` 字段**（`querySms`）：业务错误，走成功回包，线值 `permission` / `unknown`。
- **PlatformException.code**：通道层错误，`error` / `lifecycle`。

---

## 8. `ChannelCodes` 双端对应

业务代码只引常量；下表供实现 / Review 对照。**字符串值不得口头改写，以源文件为准。**

| 线值 | Dart（`channel_codes.dart`） | Kotlin（`ChannelCodes.kt`） | 用途 |
|------|------------------------------|-----------------------------|------|
| `had` | `setDefaultHad` | `SET_DEFAULT_HAD` | setDefaultSms |
| `no` | `setDefaultNo` | `SET_DEFAULT_NO` | setDefaultSms |
| `error` | `error` | `ERROR` | setDefault / restore / 通用 |
| `not_default` | `restoreNotDefault` | `RESTORE_NOT_DEFAULT` | restoreDefaultSms |
| `settings` | `restoreSettings` | `RESTORE_SETTINGS` | restoreDefaultSms |
| `allow` | `miuiAllow` | `MIUI_ALLOW` | miuiNotificationSmsState |
| `likely_off` | `miuiLikelyOff` | `MIUI_LIKELY_OFF` | 同上 |
| `ignore` | `miuiIgnore` | `MIUI_IGNORE` | 同上（历史） |
| `deny` | `miuiDeny` | `MIUI_DENY` | 同上（历史） |
| `unknown` | `miuiUnknown` | `MIUI_UNKNOWN` | 同上 |
| `permission` | `queryErrorPermission` | `QUERY_ERROR_PERMISSION` | querySms.error |
| `unknown` | `queryErrorUnknown` | `QUERY_ERROR_UNKNOWN` | querySms.error |
| `lifecycle` | `errorLifecycle` | `ERROR_LIFECYCLE` | PlatformException.code |
| `ok` | `keyOk` | `KEY_OK` | insertTest / deleteTest / insertBatch |
| `ids` | `keyIds` | `KEY_IDS` | insertTestSms |
| `deleted` | `keyDeleted` | `KEY_DELETED` | deleteTestSmsByPrefix |
| `messages` | `keyMessages` | `KEY_MESSAGES` | querySms |
| `total` | `keyTotal` | `KEY_TOTAL` | querySms |
| `error` | `keyError` | `KEY_ERROR` | querySms |
| `partial` | `keyPartial` | `KEY_PARTIAL` | querySms |
| `warnings` | `keyWarnings` | `KEY_WARNINGS` | querySms |
| `sms_uri_security` | `warnSmsUriSecurity` | `WARN_SMS_URI_SECURITY` | querySms warnings[].code |
| `sms_uri_failed` | `warnSmsUriFailed` | `WARN_SMS_URI_FAILED` | querySms warnings[].code |
| `mms_uri_security` | `warnMmsUriSecurity` | `WARN_MMS_URI_SECURITY` | querySms warnings[].code |
| `mms_uri_failed` | `warnMmsUriFailed` | `WARN_MMS_URI_FAILED` | querySms warnings[].code |
| `mms_addr_failed` | `warnMmsAddrFailed` | `WARN_MMS_ADDR_FAILED` | querySms warnings[].code |
| `mms_part_failed` | `warnMmsPartFailed` | `WARN_MMS_PART_FAILED` | querySms warnings[].code |
| `unknown` | `warnUnknown` | `WARN_UNKNOWN` | querySms warnings[].code 兜底 |
| `inserted` | `keyInserted` | `KEY_INSERTED` | insertSmsBatch |
| `failed` | `keyFailed` | `KEY_FAILED` | insertSmsBatch |
| `errors` | `keyErrors` | `KEY_ERRORS` | insertSmsBatch |
| `index` | `keyIndex` | `KEY_INDEX` | errors[] |
| `code` | `keyCode` | `KEY_CODE` | errors[] |
| `message` | `keyMessage` | `KEY_MESSAGE` | errors[] |
| `not_default` | `insertErrorNotDefault` | `INSERT_ERROR_NOT_DEFAULT` | errors[].code |
| `failed` | `insertErrorFailed` | `INSERT_ERROR_FAILED` | errors[].code |
| `invalid` | `insertErrorInvalid` | `INSERT_ERROR_INVALID` | errors[].code（非 Map 行） |
| `unknown` | `insertErrorUnknown` | `INSERT_ERROR_UNKNOWN` | errors[].code |
| `not_default` | `deleteErrorNotDefault` | `DELETE_ERROR_NOT_DEFAULT` | deleteSmsBatch error / errors[].code |
| `failed` | `deleteErrorFailed` | `DELETE_ERROR_FAILED` | deleteSmsBatch error / errors[].code |
| `unknown` | `deleteErrorUnknown` | `DELETE_ERROR_UNKNOWN` | deleteSmsBatch error |

线值在多个语境复用（如 `error`、`not_default`、`unknown`）：常量按语境拆分，字符串相同。

---

## 9. Dart 类型化封装

| 类型 | 对应方法 | 说明 |
|------|----------|------|
| `DefaultSmsResult` | `setDefaultSms` | `alreadyDefault` / `requested` / `timeout`（非线值）/ `error` |
| `RestoreDefaultResult` | `restoreDefaultSms` | `notDefault` / `openedSettings` / `error` |
| `MiuiNotifState` | `miuiNotificationSmsState` | `allow` / `likelyOff` / `ignore` / `deny` / `unknown` |
| `QueryError` | `querySms` | `none` / `permission` / `unknown` |
| `QueryWarning` | `querySms` | `code` / `message`（`SmsQueryPage.warnings` 项） |
| `DeleteBatchResult` | `deleteSmsBatch` | `ok(deleted, failed, errors)` / `failed(failure)`；`fromWire` 兼容 Map/int/null |
| `InsertBatchResult` | `insertSmsBatch` | `ok(inserted, failed, errors)` / `failed` |
| `InsertRowError` | `insertSmsBatch` / `deleteSmsBatch` | `index` / `code` / `message` |
| `BatchFailure` | 批量写 | `notDefaultOrError` / `notDefault` / `native` |
| `RequestReadSmsResult` | `requestReadSms` | `granted` / `denied` / `timeout` |

所有 `fromWire` 对未知线值落到安全默认（`error` / `unknown` / 失败态），禁止崩溃。

---

## 10. 变更检查单

改通道时按序核对：

1. [ ] `lib/services/channel_codes.dart` 常量 + 枚举 `fromWire`
2. [ ] `android/.../ChannelCodes.kt` 同名常量
3. [ ] `MainActivity` / `SmsAccess` 分发与实现
4. [ ] `SmsRepository` 封装（含分片 / 超时）
5. [ ] `docs/CHANNEL_CONTRACT.md` 本表
6. [ ] `test/channel_codes_test.dart` 线值锁
7. [ ] 相关设计文档（`QUERY_DELETE_DESIGN.md` 等）

线值本身默认 **只增不改**；修改 = Breaking，需在 PR 与 CHANGELOG 标明。
