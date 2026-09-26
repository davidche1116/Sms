# 权限与短信访问 · Kotlin 设计（Android 29–37）v3

> 变更：**移除 API 28**；默认短信统一 **RoleManager + ROLE_SMS**（删除功能需要）。  
> 状态：待确认实现，设计已按此锁定。

## 0. 范围

- **minSdk = 29**（Android 10），target/compile 至 37。
- 不使用 `ACTION_CHANGE_DEFAULT`（Q 起官方废弃）。
- **申请 ROLE_SMS**：删除短信库必须是默认短信应用。

## 1. 权限与组件

### 运行时

| 权限 | 用途 |
|------|------|
| `READ_SMS` | 查询短信列表（在成为默认短信之后 request，符合 Play 顺序） |

**不要**：`INTERNET`、存储/媒体、通讯录、通话记录、`READ_PHONE_STATE`、可选收信权限（见组件说明）。

### ROLE_SMS 清单组件（AOSP 要求，申请角色的资格）

| 组件 | 要求 |
|------|------|
| Activity | `ACTION_SENDTO` + `sms/smsto/mms/mmsto`（发送入口，可只弹提示） |
| Service | `RESPOND_VIA_MESSAGE`，`android:permission="android.permission.SEND_RESPOND_VIA_MESSAGE"` |
| Receiver | `SMS_DELIVER`，`android:permission="android.permission.BROADCAST_SMS"`（默认应用负责写入短信库；**空实现或忽略即可**） |
| Receiver | `WAP_PUSH_DELIVER` + `application/vnd.wap.mms-message`，`android:permission="android.permission.BROADCAST_WAP_PUSH"`（占位） |

Manifest 仅声明上述组件 + `READ_SMS`；**不申请** `SEND_SMS`/`RECEIVE_*` 作为运行时权限（清理器不收发新信）。  
`SMS_DELIVER` 仅投递给默认短信应用，无需 `RECEIVE_SMS` 运行时权限。

## 2. 能力与判定

| 能力 | 判定 | 说明 |
|------|------|------|
| 读列表/搜索/导出 | `hasReadSms()` = `checkSelfPermission(READ_SMS)` **且** `AppOps OPSTR_READ_SMS == MODE_ALLOWED` | 掉默认后角色特权可能被收回（含 AppOps），**禁止缓存结果** |
| 删除 | `isDefaultSms()` = `RoleManager.isRoleHeld(ROLE_SMS)` | 非默认：UI 引导「设为默认」，不调删除 |

**产品流**

```
启动 → hasReadSms?
  ├─ true  → querySms
  └─ false → requestReadSms → 成功后 querySms
                └─ 失败/仍无数据 → 引导设置页

删除
  └─ isDefaultSms ? deleteSmsBatch : setDefaultSms()
```

## 3. 通道 `com.dc16.sms/smsApp`

| Method | 返回 / 说明 |
|--------|-------------|
| `hasReadSmsPermission` | `bool`（checkSelf + AppOps） |
| `requestReadSms` | 触发系统 READ_SMS 弹窗；结果由 Dart 侧重查 |
| `isDefaultSms` | `true` / `false` / `null`（RoleManager 异常） |
| `setDefaultSms` | `had` / `no`（已拉起 `createRequestRoleIntent`） / `error` |
| `openDefaultSmsSettings` | `ok` / `no`（`ACTION_MANAGE_DEFAULT_APPS_SETTINGS`） |
| `querySms` `{address?}` | `{messages, error: null\|"permission"\|"unknown"}` |
| `deleteSmsBatch` `[ids]` | 行数 / `null`（非默认或失败） |

### querySms

1. `!hasReadSms() && !isDefaultSms()` → `error: "permission"`（不返回假空列表）。  
2. 合并 `content://sms` + `inbox` + `sent` + `draft`，按 `_id` 去重。  
3. 投影：`_id, thread_id, address, body, date, date_sent, read, type, sub_id`。  
4. 按列名安全取值；任何异常 → `error: "unknown"`。

### deleteSmsBatch

- 非默认短信 → `null`。  
- 默认：`ContentResolver.delete`，`id IN (...)`，chunk ≤ 900。

## 4. Kotlin 落点

```
com.dc16.sms/
  MainActivity.kt          # MethodChannel + try/catch → result.error
  sms/SmsAccess.kt         # 全部短信/权限/角色逻辑
```

```kotlin
class SmsAccess(private val activity: Activity) {
  fun hasReadSms(): Boolean
  fun requestReadSms(launcher: ActivityResultLauncher<String>)
  fun isDefaultSms(): Boolean?
  fun setDefaultSms(): String          // had | no | error
  fun openDefaultSmsSettings(): Boolean
  fun querySms(address: String?): Map<String, Any?>
  fun deleteSmsBatch(ids: List<Int>): Int?
}
```

- 角色：`activity.getSystemService(RoleManager::class.java)`  
  `isRoleHeld(RoleManager.ROLE_SMS)` / `createRequestRoleIntent(RoleManager.ROLE_SMS)`。  
- 读权限：`ActivityResultContracts.RequestPermission`。  
- 全路径 catch；channel 统一 error，禁止裸抛。

## 5. Dart 侧

`SmsRepository` 薄封装上表；**不以** `permission_handler` 的 isGranted 作为最终真值。  
UI：设置页显示 `hasReadSmsPermission` / `isDefaultSms`；删除前 `isDefaultSms`。

## 6. 风险（真机已验证）

| 现象 | 对策 |
|------|------|
| 改掉默认 → 进程被杀 | 系统行为；冷启动后重新 `hasReadSms` |
| checkSelf=true、AppOps=ignore | hasRead 必须含 AppOps |
| request() 不弹窗 | 不用插件 isGranted 短路；以 AppOps 为准 |

## 7. 实现顺序（待你点头后）

1. Manifest：`READ_SMS` + 4 个短信组件（空实现）。  
2. `SmsAccess.kt` + channel。  
3. Dart `SmsRepository` + 设置/删除引导。  
4. 魅族真机：设默认 → 读/删 → 改掉默认 → 重开 → 再申请权限。

## 8. 来源

- RoleManager（API 29+；角色特权授予/撤销）  
- Telephony.Sms.Intents（ACTION_CHANGE_DEFAULT 自 Q 废弃）  
- 默认处理程序权限指南（先默认后 READ_SMS）  
- AOSP Role / android-roles（SMS 角色组件与读写特权）
