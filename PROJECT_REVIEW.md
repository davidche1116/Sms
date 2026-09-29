# 项目审查报告（PROJECT_REVIEW）

> 审查对象：`sms`（短信清理）Flutter Android 工程
> 审查维度：代码质量 · 性能表现 · 工程结构 · Android 端配置 · 依赖管理
> 审查方式：先独立完成全量排查，再与 `REVIEW_FIXES.md` 比对去重
>
> **比对结论**：`REVIEW_FIXES.md` 在当前工作区中**不存在**（已用文件检索与全盘 `find` 双重确认，仓库中无任何 `*review*` 命名文件）。因此不存在需要排除的既有条目，以下全部为本次独立排查发现的问题。若该文件稍后补上，建议重新做一次比对。

---

## 一、代码质量

### 1. `home_page.dart` 是 783 行的巨型 StatefulWidget，职责严重混合

**问题描述**：`_HomePageState` 同时承担分页加载、权限探测（MIUI 通知类短信）、筛选、多选、隐藏列表、导入导出、删除进度编排以及全部 UI 构建，持有约 20 个可变状态字段（`items`、`_selected`、`_hiddenIds`、`_pageSize`、`_hasMore`、`_loadGen`、`_rowsDirty` 等），`build()` 方法本身超过 240 行且嵌套了 AppBar/FAB/底部栏/三种 Banner/SliverList 的完整构造。任何一处逻辑调整都要通读全文件，回归风险高，也难以写细粒度单测。

**改进方向**：按职责拆分为独立组件与控制器：
- 抽出 `SmsListController`（`ChangeNotifier` 或 `ValueNotifier`）承载数据加载、分页、筛选、多选与删除编排，Widget 只负责渲染；
- UI 侧拆出 `HomeAppBar`、`HomeSelectionBar`、`HomeEmptyBody`、`HomeBannerList` 等私有 Widget；
- 权限/MIUI 探测逻辑下沉到独立的 `PermissionCoordinator`。目标是把单文件压到 200 行以内。

### 2. 缺少统一状态管理方案，依赖硬编码导致不可测试

**问题描述**：主题、语言、仓库实例全部靠构造参数逐层透传：`SmsApp → HomePage → SettingsPage`，`onThemeChanged`/`onLocaleChanged`/`onDataChanged` 回调链一路下钻；`_HomePageState` 内直接 `final _repo = SmsRepository();`、`final _hiddenStore = HiddenStore();`，无法注入替身。结果是业务核心（分页、删除、筛选）几乎没有脱离 Widget 的测试路径，现有测试只能走全局 channel mock。

**改进方向**：引入轻量状态管理（Riverpod / Provider 均可），把 `SmsRepository`、`HiddenStore`、`ThemeStore`、`LocaleStore` 注册为可覆盖的 Provider；首页与设置页改为 `ref.watch`，去掉跨三层回调。最低限度也应改为构造注入（必填 `repo` 参数），让 Widget 测试能直接塞 mock。

### 3. 导出/导入/toast 逻辑在首页与设置页逐字重复

**问题描述**：`_HomePageState._exportAll()` 与 `_SettingsPageState._exportAll()`、`_importCsv()` 与 `_importCsv()` 方法体几乎完全一致（都是「置忙碌位 → 调 `exportAll`/`importCsv` → toast → 重载」）；`_toast()` 在 `home_page`、`settings_page`、`permission_page` 各写一遍，`action_sheet` 里还内联了第四份；`settings_page` 另有一整套 `_section`/`_group`/`_row` 私有 UI helper 与详情页耦合在一起。

**改进方向**：把「忙碌态 + 执行 + toast + 重载」收敛成一个可复用的 `AsyncActionRunner`（或 `useAction` 高阶函数）与全局 `AppMessenger.show(context, msg)`；`_row`/`_section`/`_group` 提取为 `lib/features/widgets/settings_tile.dart` 公共组件。三处 `_toast` 合并为一处后，SnackBar 时长、清除策略也能统一（目前首页固定 2 秒、设置页不设时长，行为已不一致）。

### 4. `SmsFilter` 是可变对象，被 StatelessWidget 就地修改

**问题描述**：`FilterChipsBar` 是 `StatelessWidget`，却在 `onDeleted` 里直接改传入的 `filter.sameAddress = null` 再回调 `onChanged()`；而 `showFilterSheet` 走的是 `current.copy()` + `applyFrom()` 的不可变路径。同一份筛选状态存在「拷贝后回写」和「就地修改」两套语义，很容易出现弹层取消后筛选已被污染、或 Chips 变更未触发 `_ensureFullForFilter()` 补数据的不一致。

**改进方向**：把 `SmsFilter` 改为不可变（`final` 字段 + `copyWith`），所有修改点统一产出新实例并通过回调上抛；`FilterChipsBar` 只接收 `SmsFilter` 与 `ValueChanged<SmsFilter>`。这样弹层与 Chips 两条路径自动对齐，也能给 `matches()` 加缓存友好的相等性判断。

### 5. `main.dart` 没有任何全局错误捕获与崩溃兜底

**问题描述**：`void main() => runApp(const SmsApp());` 一行到底，既没有 `FlutterError.onError`、也没有 `PlatformDispatcher.instance.onError`、没有 `ErrorWidget.builder`。框架外的异步异常（平台通道回调里的未捕获错误、Future 链上的漏网异常）在 release 下静默丢失，用户只看到界面卡死或空白，开发者拿不到任何现场信息。

**改进方向**：在 `main()` 中建立三层兜底：`WidgetsFlutterBinding.ensureInitialized()` → `FlutterError.onError` 收集框架错误 → `PlatformDispatcher.instance.onError` 收集异步错误 → `ErrorWidget.builder` 给出友好降级页；同时把现场写入本地日志文件（在设置页提供「导出诊断日志」），为隐私承诺起见不自动上传。

### 6. 异常被过度宽泛地吞掉，且导出路径静默丢弃「部分失败」标记

**问题描述**：三类问题叠加：
- `sms_repository.dart` 里十余处 `catch (e) { debugPrint(...); return 默认值; }`，`debugPrint` 在 release 下不输出，失败原因彻底不可观测；
- `_HomePageState._loadMore()` 的 `catch (_) {}` 完全静默，加载更多失败后用户无任何提示，只能靠继续下滑碰运气；
- `sms_data_service.exportAll()` 调用 `repo.queryAll()`，而 `queryAll()` 内部走 `_query()` 只取 `page.items`，**丢弃了 `partial` 与 `warnings`**。彩信富化或子箱查询部分失败时，导出的 CSV 会静默缺失数据，而导出恰恰是用户的备份动作——这是最危险的一类静默失败。

**改进方向**：
- 定义分级日志接口（如 `AppLog.w/e`），release 下写入本地循环日志，替换零散 `debugPrint`；
- `exportAll` 改为使用 `queryPage()` 并透传 `partial`：`partial == true` 时返回明确的「导出可能不完整」文案，或在导出文件头追加一行警告注释；
- 加载更多失败时给出可重试的 SnackBar / 行内「加载失败，点击重试」。

### 7. `SmsCard` 在多选模式下仍允许左滑删除

**问题描述**：`SmsCard` 的 `Dismissible` 未受 `selectMode` 约束。进入多选态后，用户本意是勾选，一次误滑就会直接触发 `confirmDismiss → onDelete()`，弹出删除确认层。多选与滑删是两套互斥的交互语义，同时生效必然误操作，且该应用删除是不可逆的写库操作。

**改进方向**：`selectMode == true` 时将 `Dismissible.direction` 设为 `DismissDirection.none`（或整体替换为不带滑动的 `Card`），退出多选后恢复。

### 8. 关键文档与实现已脱节，且 `CLAUDE.md` 未纳入版本库

**问题描述**：`CLAUDE.md` 仍写着「Batch channel ops are chunked because a single platform message is limited by Binder (~1MB)」，但 `sms_repository.dart` 的注释已明确更正为「而非 Binder 大小限制（平台通道为同进程 JNI 直传，不经 Binder IPC）」——两份说法直接冲突，后来者会按错误理由去调分片大小。同时 `git status` 显示 `CLAUDE.md` 处于未跟踪状态（`?? CLAUDE.md`），这份承载架构约定的核心文档并不在版本库里，clone 下来的人看不到。

**改进方向**：把 `CLAUDE.md` 加入版本库，并按现有代码修订「Binder 限制」段落；在 CI 或 pre-commit 中对 `CLAUDE.md` 与 `channel_codes.dart`/`sms_repository.dart` 的关键常量（`insertChunkSize`、`deleteChunkSize`、超时时长）做一次一致性校验，避免文档二次腐化。

---

## 二、性能表现

### 9. CSV 导出全量载入内存 + 单 StringBuffer 拼接 + 一次性同步写文件

**问题描述**：`exportAll()` 先 `repo.queryAll()` 把整个短信库（含彩信）一次性拉成 `List<SmsItem>`；`CsvExporter.export()` 再用一个 `StringBuffer` 拼出完整 CSV 文本，最后 `file.writeAsString()` 一次性落盘。对几万条短信的库，峰值内存是「全量对象 + 全量文本」两份，在低端机上极易触发 OOM 或被系统杀进程，且整个过程在 UI isolate 上执行，无任何进度反馈。

**改进方向**：改为流式管线 —— 分页 `queryPage(limit, offset)` 循环取数，用 `file.openWrite()` 的 `IOSink` 逐批 `writeln`，每批之间 `await sink.flush()` 并让出事件循环以驱动进度条；导出中的 `partial` 标记透传给 UI。若仍想保留简单实现，至少把导出放到 `Isolate`/`compute` 中，避免卡 UI。

### 10. 导出后的历史文件清理使用主线程同步 IO，且匹配条件过宽

**问题描述**：`CsvExporter.export()` 尾部用 `dir.listSync()` + `f.deleteSync()` 同步遍历并删除应用文档目录，这段代码跑在 UI isolate 上，目录文件多时会造成明显掉帧；更严重的是删除条件是 `f.path.endsWith('.csv') && f.path.contains('sms_')`，会误删用户自己拷贝进该目录、名字里恰好含 `sms_` 的 CSV 文件，属于静默数据销毁。

**改进方向**：改为异步 `dir.list().whereType<File>()`，并把删除范围严格限定为「本应用本次命名规则生成的文件」（例如维护一个已知导出文件名的记录，或用 `sms_<tag>_<14位时间戳>.csv` 的完整正则匹配）；保留份数从 1 份放宽到最近 N 份（如 3 份），并把清理逻辑移到导出成功之后的空闲时机。

### 11. 分页越深越慢：`maxRows = offset + limit` 导致线性退化

**问题描述**：`SmsAccess.querySms()` 中 `maxRows = offset + limit`，`readRows()` 每次都从流的头部重新读取前 `offset+limit` 行，再 `out.sortedWith(ROW_ORDER)` 整段排序一次，最后 `drop(offset).take(limit)`。翻到第 N 页就要读、排序 N×200 行，总开销是 O(N²)；而且每一页读到的都是已经排好序的数据，排序是纯浪费。用户滑到底部反复触发 `_loadMore()` 时，越往后每一页越卡。

**改进方向**：
- 首选：改用 keyset（游标）分页 —— 记住上一页最后一条的 `(date, is_mms, _id)`，下一页用 `WHERE (date < ?) OR (date = ? AND _id < ?)` 下推，每页代价恒定；
- 退而求其次：既然 Provider 已按 `DATE DESC, _id DESC` 返回有序流，`readRows` 内去掉 `sortedWith`（或只在检测到乱序时才排），并在 Kotlin 侧缓存已扫描的游标位置避免重复读取。

### 12. 每翻一页都做两次全表计数，且可能回落为全投影游标

**问题描述**：`scanStream()` 在分页分支中先调 `countRows(query)`；`countRows` 优先用 `COUNT(*)` 聚合投影，但注释已说明「个别 OEM Provider 不支持聚合投影」时会回落到 `table.query(projection, ...).use { it.count }` —— 那是把整张表灌进 CursorWindow 再取行数。SMS 与 MMS 两条流各一次，等于每翻一页可能触发两次全表游标扫描，大库上这是主导延迟。

**改进方向**：`total` 只在首次加载（offset == 0）时计算一次并缓存到 Dart 侧，后续翻页复用；或在 Kotlin 侧做进程内短时缓存（以「上次写入时间/行数变化」失效）。回落分支应加显式告警日志，便于统计哪些 ROM 触发了慢路径。

### 13. 一旦筛选激活就退化为全量查询，分页收益彻底失效

**问题描述**：`_HomePageState._load()` 中 `_filter.active == true` 时走 `_allAsPage() → repo.queryPage()`（不带 limit/offset），即一次性拉全库；`_ensureFullForFilter()` 在每次筛选变更时还会再拉一次。对一个 5 万条短信的库，用户只是想搜一个关键词，就会触发整库物化 —— 而这恰恰绕过了第 11 条里已经付出的分页优化成本。

**改进方向**：把筛选条件下推到原生层：`queryPage` 增加 `keyword`/`type`/`dateFrom`/`dateTo`/`sim` 参数，在 SQL `selection` 里过滤，Dart 侧只保留 `sameAddress` 这种轻量条件做客户端兜底；同时保留真分页，让筛选结果也能一页一页出。若短期无法下推，至少给全量加载加一个上限（如 5000 条）并提示用户「结果过多，请缩小范围」。

### 14. QA 意图处理在主线程同步读写短信库

**问题描述**：`MainActivity.configureFlutterEngine()` 末尾直接调用 `handleQaIntent(intent)`，其中的 `QA_INSERT_TEST`/`QA_DELETE_TEST`/`QA_IMPORT_TEST` 分支同步执行 `access.insertTestSms()`、`access.deleteTestSmsByPrefix()`、`access.insertSmsBatch()` —— 全部是 `contentResolver.insert/delete` 的同步调用，跑在主线程上。虽然只有 debuggable 包生效，但 `insertSmsBatch` 在 QA 场景下会逐行 insert，行数多时直接 ANR，且会污染「release 行为」的性能基线判断。

**改进方向**：把 `handleQaIntent` 的写库分支投递到 `bgExecutor`（或直接改为 `lifecycleScope.launch(Dispatchers.IO)`），结果通过 `writeQaResult` 回写；主线程只做 intent 解析与权限/可调试性校验。

### 15. 原生侧单线程串行执行器成为吞吐瓶颈

**问题描述**：`MainActivity` 用 `Executors.newSingleThreadExecutor()` 承载**所有**重操作：分页查询、批量删除、批量插入共用一条线程。用户在做几千条删除时，首页的刷新查询、下一页加载全部排在删除任务后面，界面表现为「点了刷新没反应」。同时该线程池未设置线程名，调试时无法区分任务来源。

**改进方向**：按用途拆分线程池（查询池 / 写入池），或用带优先级的线程池，保证 UI 触发的查询能插队；给线程命名（`ThreadFactory`）便于 systrace 定位；对批量删除这类长任务，配合 Dart 侧已有的分块进度，考虑在原生侧也加可取消标志。

### 16. 可见列表全量重建，且每行重复调用 `DateTime.now()`

**问题描述**：`_computeVisible()` 在每次 `_rowsDirty` 时对全部已加载条目做一次 `where` 过滤，`buildListRows()` 再全量重建扁平行；对 2000 条已加载数据，一次隐藏/取消隐藏操作就要扫两遍全表。另外 `SmsItem.time` 与 `dayLabelOf()` 内部各自调用 `DateTime.now()`，列表渲染时等于每卡片调用两次，且「今天/昨天」的判定随渲染时刻漂移。

**改进方向**：`buildListRows` 与过滤合并为一次遍历；把「今天零点」作为一次计算的结果缓存（例如在控制器中持有 `_todayStart`，跨分钟/跨日时刷新），传给 `dayLabelOf`/`time` 使用，既省掉 N 次 `DateTime.now()`，也让同一次渲染中的日期判定保持一致。

---

## 三、工程结构

### 17. CI 缺少格式化门禁，且 `flutter analyze` 不把 infos 当失败

**问题描述**：`.github/workflows/ci.yml` 的流程是 `pub get → flutter analyze → flutter test → :app:testDebugUnitTest → build apk --debug`，**没有 `dart format --output=none --set-exit-if-changed`**。而 `analysis_options.yaml` 只启用了 `unawaited_futures` 一条额外规则，`flutter analyze` 默认也不因 infos 失败。结果是代码风格完全依赖开发者自觉，长期必然漂移；同时大量 `catch (_)` 之类的可疑写法不会被拦下。

**改进方向**：在 CI 的 Analyze 步骤前后各加一步：
```
- run: dart format --output=none --set-exit-if-changed .
- run: flutter analyze --fatal-infos --fatal-warnings
```
并在 `analysis_options.yaml` 中补充 `avoid_dynamic_calls`、`discarded_futures`、`use_build_context_synchronously`、`prefer_relative_imports`（当前已是相对导入）等规则，逐条修完再放开。

### 18. CI 缺少缓存、超时保护、覆盖率与 release 验证

**问题描述**：`ci.yml` 相比 `publish.yml` 少了 `setup-java` 的 `cache: gradle`，每次 CI 都冷启 Gradle；整个 job 未设 `timeout-minutes`（GitHub 默认 360 分钟，卡死的任务会长时间占用 runner）；`flutter test` 未带 `--coverage`，测试覆盖度无从度量；最关键的是 CI 只构建 `--debug`，而 release 构建有 `isMinifyEnabled=true` + R8 收缩，**R8 引发的问题（反射、`SystemProperties`、序列化）在 CI 上永远暴露不了**，只能等发版后由用户发现。

**改进方向**：补 `cache: gradle`、给 job 加 `timeout-minutes: 30`、`flutter test --coverage` 并上传产物；增加一个 release 构建步骤（`flutter build apk --release`，签名材料已在仓库内），至少保证 release 变体能编过，最好配合一次冒烟安装测试。

### 19. `.fvmrc` 指向 `master` 通道且未入库，本地与 CI 环境不一致

**问题描述**：`.fvmrc` 内容为 `{"flutter": "master"}`，`android/local.properties` 里 `flutter.sdk=D:\Fvm\versions\master` —— 本地开发跑在**不稳定通道**上；而 CI 用 `channel: stable`。同时 `git status` 显示 `.fvmrc` 是未跟踪文件（`?? .fvmrc`，`.gitignore` 只忽略了 `.fvm/` 目录），也就是说这个把本地锁到 master 的配置既没进版本库，又会持续影响本地开发者的 analyze/构建结果，出现「本地通过、CI 失败」或反之的诡异分歧。

**改进方向**：把 Flutter 版本锁定到明确的 stable 版本（如 `"flutter": "3.35.x"`），将 `.fvmrc` 提交入库，并在 CI 中读取同一版本（或至少在 CI 里加一步断言 `.fvmrc` 与 `flutter --version` 一致）；本地改用 stable 通道，避免用 master 开发面向用户的发布版本。

### 20. 生成物 `lib/generated/` 入库，Python 脚本混入 Dart `test/` 目录

**问题描述**：`lib/generated/`（约 3500 行 l10n 生成代码）被提交进 git，每次 `flutter gen-l10n` 都会产生大段与功能无关的 diff 噪音，也容易出现「生成物与 arb 不同步但没人发现」。另外 `test/device/dump_nodes.py`、`test/device/dump_text.py` 两个**真机 QA 用的 Python 脚本**放在 Dart 的 `test/` 目录下，与该目录的语义（`flutter test` 的用例根目录）冲突，且没有任何说明文档交代其用途与前置依赖。

**改进方向**：`lib/generated/` 加入 `.gitignore`，改由 CI 在构建前执行 `flutter gen-l10n`（本地开发者在 `pub get` 后自动触发）；把 Python 脚本移到 `tool/device/` 或 `scripts/`，并补一个简短 README 说明用途、依赖与执行方式。

### 21. `channel_codes.dart` 单文件 507 行，职责混杂

**问题描述**：该文件同时承担三件事：① 通道方法名/键名常量（约 60 个 `static const`）；② 6 个枚举 + 5 个结果类型的定义；③ 4 个 `fromWire()` 线协议解析函数。协议常量（线格式，严禁改动）与可演进的解析逻辑混在一个文件里，改动解析逻辑时容易误伤常量；`SmsRepository` 又 `export 'channel_codes.dart'`，使所有下游都隐式依赖全部细节。

**改进方向**：拆为 `services/channel/channel_codes.dart`（仅常量）、`services/channel/wire_types.dart`（枚举与结果类型）、`services/channel/wire_parser.dart`（`fromWire` 系列）；加一个单测比对 Dart 常量与 `ChannelCodes.kt` 的字面量一致性（可解析 Kotlin 文件做断言），把「两端协议必须同步」这条约定变成自动化检查。

### 22. `analysis_options.yaml` 规则集偏松，且排除了整个 `android/`

**问题描述**：除 `include: package:flutter_lints/flutter.yaml` 外只加了 `unawaited_futures` 一条；`analyzer.exclude` 把 `android/**` 整体排除（合理，但意味着 Kotlin 侧无任何静态检查）。Dart 侧因此漏掉了 `use_build_context_synchronously`（本项目大量 `await` 后使用 `context`，目前靠零散的 `mounted` 手工判断，容易漏）、`avoid_dynamic_calls`（`channel_codes.dart` 里满是对 `Map<*, *>` 结果的动态取值）等高价值规则。

**改进方向**：逐步启用上述规则并修复存量告警；Kotlin 侧引入 `ktlint`（或 Android Studio 自带的 ktlint 插件）并接入 CI，与 Dart 侧形成对等的静态检查。

---

## 四、Android 端配置

### 23. 发布签名密钥与明文口令已提交进版本库（最高优先级）

**问题描述**：`git ls-files` 确认 `android/key.properties` 与 `android/app/key/sms.keystore` **均为已跟踪文件**，且 `key.properties` 内容是明文：
```
storePassword=dc16@sms
keyPassword=dc16@sms
keyAlias=sms
storeFile=key\sms.keystore
```
`.gitignore` 里还有一行注释明确写着「发布签名随仓库分发（与 1.x 一致）」，`CLAUDE.md` 也把此做法列为约定。这意味着任何拿到仓库的人都能用同一密钥签发同名包，用于钓鱼替换或中间人分发；一旦仓库泄露，密钥无法「吊销」，只能换包名或换密钥并强制用户手动迁移。

**改进方向**：
- 立即把 `android/key.properties` 与 `*.keystore` 移出版本库（加入 `.gitignore`，用 `git filter-repo`/BFG 清理历史），改用 CI Secrets（`secrets.STORE_PASSWORD` 等）在发布 workflow 中动态生成 `key.properties`；
- CI 已有 `permissions: contents: write`，接入加密 secret 的成本很低；
- 评估现有密钥是否已泄露：若仓库曾公开，应生成新密钥并在 CHANGELOG/README 中告知用户签名变更；
- 若确因「方便贡献者本地出包」必须保留，至少改用环境变量注入（`System.getenv("SMS_STORE_PASSWORD")`），让 `key.properties` 只作为本地可选的覆盖文件。

### 24. `allowBackup` 未关闭，且缺少 Android 12+ 的数据提取规则

**问题描述**：`AndroidManifest.xml` 的 `<application>` 未声明 `android:allowBackup`，默认为 `true`；也没有 `android:dataExtractionRules`（API 31+ 的替代机制）。应用数据（含 `hidden_store` 持久化的本地隐藏短信 uid、主题与语言偏好）会被 `adb backup` 或厂商云备份带走并可在另一台设备还原。对一个以「本地优先、绝不上传」为核心卖点的短信工具，这与产品承诺存在实质冲突。

**改进方向**：设置 `android:allowBackup="false"`；若希望保留备份能力，则显式配置 `android:dataExtractionRules="@xml/data_extraction_rules"`，把 `hidden_sms_ids` 等敏感项排除在备份/设备迁移之外（用 `cloud-backup` 与 `device-transfer` 分别标注 `exclude`）。

### 25. 未声明 `WRITE_SMS` / `RECEIVE_SMS` / `SEND_SMS` 权限

**问题描述**：`AndroidManifest.xml` 只申请了 `android.permission.READ_SMS`。但应用的核心能力依赖 ROLE_SMS 默认短信角色：`SmsReceiver` 收到 `SMS_DELIVER` 后要 `contentResolver.insert` 入库，`deleteSmsBatch`/`insertSmsBatch` 要写库。虽然现代 Android 对持有 ROLE_SMS 的应用会授予相应 AppOps，但各 OEM（尤其本项目已重点适配的 MIUI/HyperOS）的角色资格校验与写库授权实现差异很大，缺少声明可能在部分 ROM 上导致「能读不能写」或「角色申请直接不出现本应用」。此外 `SmsReceiver` 接收 `SMS_DELIVER` 在部分实现中也要求 `RECEIVE_SMS`。

**改进方向**：显式声明 `WRITE_SMS`、`RECEIVE_SMS`、`SEND_SMS`（`SEND_SMS` 是 `HeadlessSmsSendService` 响应 `RESPOND_VIA_MESSAGE` 所需的语义能力，即便当前是空实现），并在真机矩阵（MIUI/HyperOS、ColorOS、OriginOS、原生 AOSP）上验证角色申请与入库写库两条链路；把验证结论写进 README 的兼容性章节。

### 26. 主题样式与启动 Activity 未适配 Android 15+ 强制 edge-to-edge

**问题描述**：`compileSdk`/`targetSdk` 跟随 `flutter.*`（当前为 36），已处于 Android 16 的强制 edge-to-edge 范围；但 `res/values/styles.xml` 与 `values-night/styles.xml` 仍是模板遗留的 `@android:style/Theme.Light.NoTitleBar` / `Theme.Black.NoTitleBar`，未做 `WindowCompat` 相关处理。同时 `MainActivity` 使用 `FlutterFragmentActivity`，AppBar 背景是自定义的 `scheme.primary`（深色时是 `Colors.white` 前景），在 15/16 上状态栏与手势导航条区域可能出现 AppBar 被裁切、内容与系统栏重叠、`SafeArea` 误判等问题。

**改进方向**：在 `MainActivity.onCreate()`（或 `configureFlutterEngine` 之前）显式调用 `WindowCompat.enableEdgeToEdge()`（或按需 `setDecorFitsSystemWindows`），并把 `styles.xml` 的 LaunchTheme/NormalTheme 迁移到 `Theme.Material3`/`Theme.AppCompat` 系或 Flutter 新版模板提供的样式；随后在 Android 15/16 真机与模拟器上回归首屏、设置页、底部多选栏三处布局。

### 27. `gradle.properties` 的 Windows 专用配置污染 CI，JVM 内存硬编码 8G

**问题描述**：`android/gradle.properties` 中有：
```
# Source plugins live on the C: drive (pub cache) while the project is on the D: drive;
kotlin.incremental=false
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G ...
```
`kotlin.incremental=false` 是为了绕开**某位开发者本机**跨盘符的增量编译问题，却随仓库提交，导致 **Linux 上的 CI 与所有其他开发者都被强制关闭 Kotlin 增量编译**，全量重编 Kotlin，CI 时长显著变长。`-Xmx8G` 同样是按开发者机器配置的，GitHub runner 标准内存为 7GB，Gradle 直接按 8G 预留会触发 OOM 或频繁 GC。

**改进方向**：把这两项从仓库的 `gradle.properties` 移出，改放到开发者本机的 `~/.gradle/gradle.properties`（`kotlin.incremental=false` 只影响本机），或在仓库内加 OS 条件判断；CI 侧把 `org.gradle.jvmargs` 降到 `-Xmx4G` 左右（可通过 `GRADLE_OPTS` 环境变量在 workflow 中覆盖）。

### 28. ABI 只保留 `arm64-v8a`，且 R8 规则对本包等于不混淆

**问题描述**：`build.gradle.kts` 中 `abiFilters.clear()` 后只 `+= "arm64-v8a"`，放弃 32 位 ARM 设备与 x86 模拟器（调试时 `flutter run` 到 x86 模拟器可能受影响），但这一取舍未在 README/CHANGELOG 中说明，容易被误认为遗漏。另一方面 `proguard-rules.pro` 首行就是 `-keep class com.dc16.sms.** { *; }`，在 `isMinifyEnabled = true` 下等于本包代码完全不混淆、不裁剪，R8 只作用于依赖库，混淆带来的体积与安全收益基本没有，却仍承担了 R8 引入问题的风险。

**改进方向**：在 README 明确写出「仅发布 arm64-v8a」及原因（体积/维护成本），若目标用户包含老旧 32 位设备则补回 `armeabi-v7a`；`proguard-rules.pro` 改为精确 keep —— 只保留 `MainActivity`、`SmsReceiver`、`MmsReceiver`、`HeadlessSmsSendService` 及反射目标（`android.os.SystemProperties`），其余交给 R8，并在 release 构建后跑一次冒烟验证（尤其通道调用与广播接收）。

---

## 五、依赖管理

### 29. 依赖版本约束全部开放上界，且无任何依赖健康检查门禁

**问题描述**：`pubspec.yaml` 中 7 个直接依赖全部是 caret 约束（`file_picker: ^13.1.0`、`share_plus: ^13.3.0`、`shared_preferences: ^2.5.5` 等），虽然 `pubspec.lock` 已提交（app 项目的正确做法，这点值得肯定），但 CI 中没有 `flutter pub outdated`、没有依赖漏洞扫描、没有「lock 文件与 pubspec 是否一致」的校验；`.github/dependabot.yml` 只负责每周开 PR，不做安全审计，PR 也可能长期堆积（`open-pull-requests-limit: 5`）。

**改进方向**：在 CI 增加一步 `flutter pub outdated`（或 `dart pub deps`）并把「存在 major 版本落后」作为报告项而非失败项；接入 `osv-scanner` 或 GitHub 的 Dependabot alerts 做漏洞扫描；给 dependabot 的 pub/gradle/actions 三类更新分别加 `groups`，避免每周 5 个 PR 分散精力。

### 30. `environment` 只有下界，Flutter/Dart 版本不可复现

**问题描述**：`pubspec.yaml` 声明 `environment: sdk: ^3.13.4`，无上界；配合第 19 条（`.fvmrc` 未入库且指向 master），整个项目实际上**没有任何一处能确定「该用哪个 Flutter 版本构建」**。CI 用 stable 的最新版，本地用 master，两者都可能随时间漂移；`flutter_lints: ^6.0.0` 与 Dart 3.13+ 的组合也依赖具体版本。发版时无法回答「这个包是用哪个 SDK 编出来的」。

**改进方向**：`.fvmrc` 锁定具体 stable 版本并入库；在 CI 中输出并归档 `flutter --version` 结果；考虑在 `pubspec.yaml` 增加 `environment: sdk: '>=3.13.0 <4.0.0'` 这样的显式区间，避免未来 Dart 4 静默进入约束范围。

### 31. `pubspec.yaml` 依赖无分组注释，`intl` 的必要性未被说明

**问题描述**：`dependencies` 区块是一份扁平列表，没有按「UI / 存储 / 文件与分享 / 国际化」分组的注释，新加入的贡献者难以判断某个能力该用哪个包（例如已有 `path_provider` 又要加文件操作时容易重复引入）。其中 `intl: ^0.20.3` 在 `lib/` 手写代码中**没有任何直接引用**（仅 `lib/generated/` 的三个生成文件 import），它是 `flutter gen-l10n` 产物的隐含依赖 —— 这一点若不注明，很容易被后续「清理未使用依赖」的 PR 误删，导致生成代码编译失败。

**改进方向**：给 `pubspec.yaml` 的依赖按用途加分组注释；在 `intl` 一行后加注释 `# 必需：flutter gen-l10n 生成代码依赖，勿删`；顺带核对 `assets/` 目录（含 `icon/`、`screenshot/`）虽已入库但未在 `flutter.assets` 中声明，若将来需要在运行时读取需补声明（当前仅供 `flutter_launcher_icons` 与 README 使用，可保持不变）。

---

## 附：本次审查确认为「做得好」的部分

为避免后续重构误伤，记录几处明确值得保留的设计：

- `OnceResult` 一次性回包包装 + `pendingRead`/`pendingRole` 的 teardown 收尾，正确规避了系统弹窗与 Activity 销毁对同一 `MethodChannel.Result` 的二次回包；
- `SmsItem.uid` 用 `mmsUidOffset = 1 << 30` 统一 SMS/MMS 键空间，删除时再按 `is_mms` 路由，避免了跨表同号误删；
- `querySms` 的 `error` 与 `partial` 互斥语义清晰，部分失败不丢其它路已有行，Dart 侧用 Banner 轻提示而非阻断；
- `csv_exporter.escapeField()` 的 CSV 公式注入防护（`=` `+` `-` `@` 前缀加 `'`）与导入侧 `_unescapeFormulaPrefix()` 成对，round-trip 有测试覆盖；
- 三份 `arb` 文案键完全齐平（各 211 个键，无缺失），`l10n.yaml` 已设 `nullable-getter: false`；
- `insertSmsBatch` 放弃 `applyBatch` 改用逐行 insert 的取舍有充分注释（`OperationApplicationException` 不暴露失败下标，重试会重复插入），是正确且有依据的决策。
