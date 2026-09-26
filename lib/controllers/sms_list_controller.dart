import 'package:flutter/material.dart';
import 'package:sms_advanced/sms_advanced.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/sms_filter.dart';
import '../services/sms_repository.dart';

/// 删除过程中的进度阶段回调。
///
/// [done] 为 null 表示"原生批量删除中"，没有逐条进度；
/// 非 null 表示已回退到逐条删除，此时可以显示 x / total。
typedef DeleteProgressCallback = void Function(int? done, int total);

/// 短信列表页的状态与业务逻辑。
///
/// 原先这些逻辑全部堆在页面的 State 里（查询、过滤、删除、默认应用校验、
/// 并发控制），任何一个新特性都只能往那个类里加字段和方法。抽成
/// ChangeNotifier 之后：
///
/// - 页面只负责渲染与弹窗，不再保存业务状态；
/// - 业务规则（过滤链、并发序号、删除失败计数）有了独立的可测试落点；
/// - 提示文案通过 onMessage 回传给页面，控制器不接触 BuildContext。
class SmsListController extends ChangeNotifier {
  SmsListController({
    required this.l10n,
    required this.onMessage,
    SmsRepository? repository,
  }) : _repository = repository ?? SmsRepository();

  final SmsRepository _repository;

  /// 国际化对象。由页面在 didChangeDependencies 中更新（locale 变化时会重建）。
  AppLocalizations l10n;

  /// 需要给用户提示时回调，由页面负责呈现（提示依赖 BuildContext）。
  final void Function(String message) onMessage;

  final TextEditingController keywordController = TextEditingController();
  final ValueNotifier<bool> loading = ValueNotifier<bool>(true);
  final ValueNotifier<List<SmsMessage>> messages =
      ValueNotifier<List<SmsMessage>>(<SmsMessage>[]);

  /// AnimatedList 的条目计数由内部状态维护（只认 insertItem/removeItem，
  /// 会忽略重建时传的新 initialItemCount）。整表刷新（查询/过滤/切回全部）
  /// 必须换一个新 Key 让旧状态丢弃，否则内部计数与新列表长度错位，
  /// 标题显示 n 条但列表灰屏无内容，且多轮操作后越差越多。
  GlobalKey<AnimatedListState> listKey = GlobalKey<AnimatedListState>();

  /// 日期区间上界按次日零点存储，过滤语义 [start, end)。
  DateTime? startDate;
  DateTime? endDate;

  /// 查询序号：每次发起查询自增。
  ///
  /// 快速连点"全部/日期/搜索"会并发跑到多条查询，慢的旧查询后返回时会把
  /// 新结果覆盖掉。用序号丢弃过期结果，保证界面呈现最后一次请求的数据。
  int _queryToken = 0;

  /// 底层数据访问入口。设置/恢复默认短信应用等平台能力仍由页面直接使用。
  SmsRepository get repository => _repository;

  /// 是否处于多选模式。
  bool selectionMode = false;

  final Set<SmsMessage> _selected = <SmsMessage>{};

  int get count => messages.value.length;

  bool get isEmpty => messages.value.isEmpty;

  int get selectedCount => _selected.length;

  bool isSelected(SmsMessage message) => _selected.contains(message);

  bool get hasFilter =>
      keywordController.text.isNotEmpty || startDate != null || endDate != null;

  void _notify(String message) => onMessage(message);

  /// 进入多选模式，可同时选中某一条。
  void enterSelectionMode([SmsMessage? message]) {
    selectionMode = true;
    _selected.clear();
    if (message != null) {
      _selected.add(message);
    }
    notifyListeners();
  }

  /// 退出多选模式并清空选择。
  void exitSelectionMode() {
    selectionMode = false;
    _selected.clear();
    notifyListeners();
  }

  void toggleSelection(SmsMessage message) {
    if (!_selected.remove(message)) {
      _selected.add(message);
    }
    notifyListeners();
  }

  /// 全选当前列表。
  void selectAll() {
    _selected.addAll(messages.value);
    notifyListeners();
  }

  /// 清空全部过滤条件（关键词 + 日期区间）。
  void clearFilters() {
    keywordController.clear();
    startDate = null;
    endDate = null;
  }

  /// 全部短信（走当前过滤条件）。
  Future<void> queryAll() => _run(_repository.getAllSms);

  /// 该号码的全部短信（走当前过滤条件）。
  Future<void> querySameAddress(SmsMessage message) =>
      _run(() => _repository.queryByAddress(message.address));

  /// 同 SIM 卡的全部短信（走当前过滤条件）。
  Future<void> querySameSim(SmsMessage message) => _run(() async {
    return filterBySim(await _repository.getAllSms(), message.sim);
  });

  /// 写入日期区间并重新查询。区间语义 [起始日零点, 结束日次日零点)。
  Future<void> applyDateRange(DateTime start, DateTime end) {
    startDate = start;
    endDate = end;
    return queryAll();
  }

  /// 所有查询的统一执行入口：加载态、异常兜底、过滤链、并发序号、
  /// 整表替换都在这里，三条查询路径不再各写一套样板。
  ///
  /// 不再以 `Permission.sms.isGranted` 作为查询门闩：部分 ROM 在交还默认
  /// 短信角色后会把该状态误报为拒绝，但 READ_SMS 仍然可用——此时若直接
  /// 跳过查询，用户会看到"有权限却读不到短信"。改为先查，按异常类型提示。
  Future<void> _run(Future<List<SmsMessage>> Function() query) async {
    final int token = ++_queryToken;
    List<SmsMessage> result = <SmsMessage>[];
    bool notifiedPermission = false;
    bool querySucceeded = false;
    loading.value = true;
    try {
      result = _applyFilters(await query());
      querySucceeded = true;
    } on SmsQueryPermissionException {
      result = <SmsMessage>[];
      notifiedPermission = true;
      _notify(l10n.toast_permission);
    } catch (e) {
      // 平台查询失败（如底层插件异常）时兜底：提示失败、清空列表，
      // 保证 loading 一定复位、界面不挂死。
      debugPrint('querySms failed: $e');
      result = <SmsMessage>[];
      _notify(l10n.operation_failed);
    } finally {
      loading.value = false;
    }
    // 仅在「查询成功但为空」时再判权限：失败路径已提示过，不重复弹。
    // 用原生 checkSelfPermission，不用 Permission.sms.isGranted
    // （掉默认后可能缓存假 true）。
    if (querySucceeded && !notifiedPermission && result.isEmpty) {
      final bool reallyGranted = await _repository.hasReadSmsPermission();
      final bool? isDefault = await _repository.isDefaultSmsApp();
      if (!reallyGranted && isDefault != true) {
        _notify(l10n.toast_permission);
      }
    }
    _replaceAll(result, token);
  }

  /// 统一的过滤链：关键词 + 日期区间 + 日期降序。
  ///
  /// 保证"当前列表 = 数据源 + 过滤条件"的语义一致——下钻换的是数据源，
  /// 过滤条件不应被悄悄丢掉。
  List<SmsMessage> _applyFilters(List<SmsMessage> source) {
    List<SmsMessage> result = filterByKeyword(source, keywordController.text);
    result = filterByDateRange(result, startDate, endDate);
    return sortByDateDesc(result);
  }

  /// 整表替换：丢弃旧 AnimatedList 状态，用正确长度重建。
  void _replaceAll(List<SmsMessage> newList, int token) {
    if (token != _queryToken) return;
    listKey = GlobalKey<AnimatedListState>();
    messages.value = newList;
    // 列表已整体换掉，旧的选择集没有意义；退出多选模式避免选中"看不见"的条目。
    if (selectionMode) {
      selectionMode = false;
      _selected.clear();
      notifyListeners();
    }
  }

  /// 从列表移除（不触达平台），返回被移除项的原下标供 AnimatedList 播放
  /// 离场动画；-1 表示该项已不在列表中。
  ///
  /// 先复制再删除、最后整体替换：已发布的列表不会被就地修改，导出与批量
  /// 删除持有的快照语义可预期。
  int removeFromList(SmsMessage message) {
    final int index = messages.value.indexOf(message);
    if (index < 0) return -1;
    final List<SmsMessage> next = List<SmsMessage>.of(messages.value)
      ..removeAt(index);
    messages.value = next;
    return index;
  }

  /// 删除前校验默认短信应用身份，三态判定见 SmsRepository.isDefaultSmsApp。
  Future<bool> ensureDefaultSmsApp() async {
    final bool? isDefault = await _repository.isDefaultSmsApp();
    if (isDefault == true) return true;
    // false = 明确不是默认；null = 无法判定，按失败拦截而不是误报。
    _notify(isDefault == false ? l10n.toast_default : l10n.operation_failed);
    return false;
  }

  /// 删除单条短信，成功返回 true。
  Future<bool> deleteMessage(SmsMessage message) async {
    final int? id = message.id;
    final int? threadId = message.threadId;
    if (id == null || threadId == null) return false;
    try {
      final bool? ok = await _repository.removeSmsById(id, threadId);
      if (ok != true) {
        _notify(l10n.operation_failed);
        return false;
      }
      return true;
    } catch (e) {
      // 平台删除调用异常（如系统拒绝）时提示失败，而不是静默崩溃。
      debugPrint('removeSmsById failed: $e');
      _notify(l10n.operation_failed);
      return false;
    }
  }

  /// 删除当前列表的全部短信，返回失败条数。
  ///
  /// 优先走原生批量删除（N 次跨进程调用降到 ceil(N/900) 次）；平台侧返回
  /// null（老版本原生 / MissingPluginException）时回退逐条删除，期间通过
  /// [onProgress] 上报进度、通过 [shouldCancel] 响应取消。
  /// 删除当前列表的全部短信，返回失败条数。
  Future<int> deleteAll({
    DeleteProgressCallback? onProgress,
    bool Function()? shouldCancel,
  }) {
    return deleteMessages(
      messages.value,
      onProgress: onProgress,
      shouldCancel: shouldCancel,
    );
  }

  /// 删除已选中的短信，返回失败条数。
  Future<int> deleteSelected({
    DeleteProgressCallback? onProgress,
    bool Function()? shouldCancel,
  }) {
    return deleteMessages(
      _selected.toList(growable: false),
      onProgress: onProgress,
      shouldCancel: shouldCancel,
    );
  }

  /// 删除给定的一组短信，返回失败条数。
  Future<int> deleteMessages(
    List<SmsMessage> source, {
    DeleteProgressCallback? onProgress,
    bool Function()? shouldCancel,
  }) async {
    // 快照：批量删除耗时较长，期间列表可能被其他操作刷新。
    final List<SmsMessage> items = List<SmsMessage>.of(source);
    final List<int> ids = <int>[
      for (final SmsMessage message in items)
        // id/threadId 缺失的条目无法删除，计入失败而不是 ! 强解包崩溃。
        if (message.id != null && message.threadId != null) message.id!,
    ];
    int failed = items.length - ids.length;

    onProgress?.call(null, items.length);
    final int? deleted = await _repository.deleteSmsBatch(ids);
    if (deleted != null) {
      return failed + (ids.length - deleted);
    }

    for (int i = 0; i < items.length; i++) {
      if (shouldCancel?.call() ?? false) break;
      final SmsMessage message = items[i];
      final int? id = message.id;
      final int? threadId = message.threadId;
      if (id == null || threadId == null) {
        failed++;
      } else {
        try {
          final bool? ok = await _repository.removeSmsById(id, threadId);
          if (ok != true) failed++;
        } catch (e) {
          debugPrint('removeSmsById failed: $e');
          failed++;
        }
      }
      onProgress?.call(i + 1, items.length);
    }
    return failed;
  }

  @override
  void dispose() {
    keywordController.dispose();
    loading.dispose();
    messages.dispose();
    super.dispose();
  }
}
