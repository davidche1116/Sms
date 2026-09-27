import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/sms_item.dart';
import 'channel_codes.dart';

export 'channel_codes.dart';

class SmsQueryPermissionException implements Exception {
  const SmsQueryPermissionException();
}

/// `requestReadSms` 结果：区分「用户拒绝」与「系统未返回」，供 UI 给出不同提示。
enum RequestReadSmsResult {
  /// 已真正可读。
  granted,

  /// 系统明确返回且仍无权限（用户拒绝 / 未授）。
  denied,

  /// 超时或 Activity 被销毁，系统没给结果；回查后仍不可读。
  /// UI 应提示可去设置手动开启，不要当成用户拒绝。
  timeout,
}

/// `queryPage` 结果：本页 items + 库内去重总数。
class SmsQueryPage {
  const SmsQueryPage({required this.items, this.total});

  final List<SmsItem> items;
  final int? total;

  /// 是否还有下一页。`total` 未知（旧原生）时用「本页是否写满」估算。
  bool hasMore(int loadedCount, int pageSize) =>
      total != null ? loadedCount < total! : items.length >= pageSize;
}

/// 薄封装原生通道 `com.davidche1116.sms/smsApp`。
class SmsRepository {
  /// [systemResponseTimeout]：等待系统权限弹窗 / 角色页返回的最长时限。
  /// 超时后回退再查一次真实状态，绝不让 `invokeMethod` 永久 pending。
  /// 测试可注入更短的 Duration。
  SmsRepository({
    this.systemResponseTimeout = defaultSystemResponseTimeout,
  });

  /// 默认等系统回包时限（2 分钟）。
  static const Duration defaultSystemResponseTimeout = Duration(minutes: 2);

  /// `insertSmsBatch` 单次通道分片行数。
  ///
  /// 单条 platform message 受 Binder ~1MB 限制；短信行很小，200 行足够安全，
  /// 也给原生侧 applyBatch 同量级分片（见 Kotlin `INSERT_CHUNK`）留了余量。
  static const int insertChunkSize = 200;

  /// `deleteSmsBatchChunked` 单次通道分片条数（UI 级进度粒度）。
  ///
  /// 小于 Kotlin 内部 900 分片，保证大批次也能看到真实进度步进；
  /// 单条 platform message 载荷很小，200 条远低于 Binder ~1MB 上限。
  static const int deleteChunkSize = 200;

  /// 见构造参数。
  final Duration systemResponseTimeout;

  static const _ch = MethodChannel('com.davidche1116.sms/smsApp');

  /// 等系统回包并套超时；超时抛 [TimeoutException]，由调用方回退再查状态。
  Future<T> _awaitSystem<T>(Future<T> future) =>
      future.timeout(systemResponseTimeout);

  Future<bool> hasReadSmsPermission() async {
    try {
      return await _ch.invokeMethod<bool>('hasReadSmsPermission') ?? false;
    } catch (e) {
      debugPrint('hasReadSmsPermission: $e');
      return false;
    }
  }

  /// 等待系统弹窗结束并返回是否真正可读。
  ///
  /// 通道挂起 / 超时 / Activity 被销毁（`lifecycle`）时回退再查一次
  /// [hasReadSmsPermission]，绝不永久 pending。超时且仍无权限时返回
  /// [RequestReadSmsResult.timeout]，UI 可提示「系统未返回结果，可在设置中手动开启」。
  Future<RequestReadSmsResult> requestReadSms() async {
    try {
      final ok = await _awaitSystem(_ch.invokeMethod<bool>('requestReadSms'));
      return (ok == true || await hasReadSmsPermission())
          ? RequestReadSmsResult.granted
          : RequestReadSmsResult.denied;
    } on TimeoutException {
      debugPrint('requestReadSms: timeout after $systemResponseTimeout');
      return _readAfterNoResult();
    } on PlatformException catch (e) {
      if (e.code == ChannelCodes.errorLifecycle) {
        debugPrint('requestReadSms: cancelled by activity lifecycle');
        return _readAfterNoResult();
      }
      debugPrint('requestReadSms: $e');
      return (await hasReadSmsPermission())
          ? RequestReadSmsResult.granted
          : RequestReadSmsResult.denied;
    } catch (e) {
      debugPrint('requestReadSms: $e');
      return (await hasReadSmsPermission())
          ? RequestReadSmsResult.granted
          : RequestReadSmsResult.denied;
    }
  }

  /// 系统未回包（超时 / 销毁）后：回查一次是否已可读，否则报 timeout。
  Future<RequestReadSmsResult> _readAfterNoResult() async {
    if (await hasReadSmsPermission()) return RequestReadSmsResult.granted;
    return RequestReadSmsResult.timeout;
  }

  /// true=默认 / false=非默认 / null=无法判定
  Future<bool?> isDefaultSms() async {
    try {
      return await _ch.invokeMethod<bool>('isDefaultSms');
    } catch (e) {
      debugPrint('isDefaultSms: $e');
      return null;
    }
  }

  /// 见 [DefaultSmsResult]。
  ///
  /// 超时 / Activity 销毁时返回 [DefaultSmsResult.timeout]（或已在系统页
  /// 完成切换则 [DefaultSmsResult.alreadyDefault]），绝不永久 pending。
  Future<DefaultSmsResult> setDefaultSms() async {
    try {
      return DefaultSmsResult.fromWire(
        await _awaitSystem(_ch.invokeMethod<String>('setDefaultSms')),
      );
    } on TimeoutException {
      debugPrint('setDefaultSms: timeout after $systemResponseTimeout');
      return _defaultSmsAfterNoResult();
    } on PlatformException catch (e) {
      if (e.code == ChannelCodes.errorLifecycle) {
        debugPrint('setDefaultSms: cancelled by activity lifecycle');
        return _defaultSmsAfterNoResult();
      }
      debugPrint('setDefaultSms: $e');
      return DefaultSmsResult.error;
    } catch (e) {
      debugPrint('setDefaultSms: $e');
      return DefaultSmsResult.error;
    }
  }

  /// 系统未回包（超时 / 销毁）后：回查一次是否已成为默认，否则报 timeout。
  Future<DefaultSmsResult> _defaultSmsAfterNoResult() async {
    if (await isDefaultSms() == true) return DefaultSmsResult.alreadyDefault;
    return DefaultSmsResult.timeout;
  }

  /// 见 [RestoreDefaultResult]。
  Future<RestoreDefaultResult> restoreDefaultSms() async {
    try {
      return RestoreDefaultResult.fromWire(
        await _ch.invokeMethod<String>('restoreDefaultSms'),
      );
    } catch (e) {
      debugPrint('restoreDefaultSms: $e');
      return RestoreDefaultResult.error;
    }
  }

  Future<bool> openDefaultSmsSettings() async {
    try {
      return await _ch.invokeMethod<bool>('openDefaultSmsSettings') ?? false;
    } catch (e) {
      debugPrint('openDefaultSmsSettings: $e');
      return false;
    }
  }

  /// 打开本应用系统设置（权限被长期拒绝时手动开启）。
  Future<bool> openAppSettings() async {
    try {
      return await _ch.invokeMethod<bool>('openAppSettings') ?? false;
    } catch (e) {
      debugPrint('openAppSettings: $e');
      return false;
    }
  }

  Future<bool> isMiui() async {
    try {
      return await _ch.invokeMethod<bool>('isMiui') ?? false;
    } catch (e) {
      debugPrint('isMiui: $e');
      return false;
    }
  }

  /// 见 [MiuiNotifState]。
  Future<MiuiNotifState> miuiNotificationSmsState() async {
    try {
      return MiuiNotifState.fromWire(
        await _ch.invokeMethod<String>('miuiNotificationSmsState'),
      );
    } catch (e) {
      debugPrint('miuiNotificationSmsState: $e');
      return MiuiNotifState.unknown;
    }
  }

  Future<bool> openMiuiPermissionEditor() async {
    try {
      return await _ch.invokeMethod<bool>('openMiuiPermissionEditor') ?? false;
    } catch (e) {
      debugPrint('openMiuiPermissionEditor: $e');
      return false;
    }
  }

  /// QA：插入带前缀的测试短信（仅 debug 包 + 当前为默认短信时有效）。
  /// 成功返回 id 列表；失败（非默认 / 非 debug / 异常）返回 null。
  Future<List<int>?> insertTestSms({
    int count = 3,
    String bodyPrefix = 'SMSCLEANUP_TEST',
  }) async {
    try {
      final raw = await _ch.invokeMethod<dynamic>('insertTestSms', {
        'count': count,
        'bodyPrefix': bodyPrefix,
      });
      if (raw is! Map || raw[ChannelCodes.keyOk] != true) return null;
      return [
        for (final x in (raw[ChannelCodes.keyIds] as List? ?? const []))
          (x as num).toInt(),
      ];
    } catch (e) {
      debugPrint('insertTestSms: $e');
      return null;
    }
  }

  Future<List<SmsItem>> queryAll() => _query(null);

  Future<List<SmsItem>> queryByAddress(String address) => _query(address);

  /// 分页查询：`limit`/`offset` 与原生契约一致。
  /// 都不传则等价全量（兼容旧调用）；`total` 为去重后的库内总数。
  ///
  /// [QueryError.permission] 抛 [SmsQueryPermissionException]；
  /// [QueryError.unknown] 抛普通异常；[QueryError.none] 正常返回。
  Future<SmsQueryPage> queryPage({
    String? address,
    int? limit,
    int? offset,
  }) async {
    List<SmsItem> list;
    int? total;
    try {
      final raw = await _ch.invokeMethod<dynamic>('querySms', {
        if (address != null && address.isNotEmpty) 'address': address,
        'limit': ?limit,
        'offset': ?offset,
      });
      if (raw is! Map) return const SmsQueryPage(items: []);
      switch (QueryError.fromWire(raw[ChannelCodes.keyError])) {
        case QueryError.none:
          break;
        case QueryError.permission:
          throw const SmsQueryPermissionException();
        case QueryError.unknown:
          throw Exception('querySms: ${raw[ChannelCodes.keyError]}');
      }
      final rows = (raw[ChannelCodes.keyMessages] as List?) ?? const [];
      total = (raw[ChannelCodes.keyTotal] as num?)?.toInt();
      list = rows.map(_mapRow).toList();
    } on MissingPluginException {
      return const SmsQueryPage(items: []);
    }
    // 与 Kotlin 同序：date 降序（null 最早），_id 降序作稳定次键。
    list.sort(_dateDesc);
    return SmsQueryPage(items: list, total: total);
  }

  Future<List<SmsItem>> _query(String? address) async {
    final page = await queryPage(address: address);
    return page.items;
  }

  static SmsItem _mapRow(Object? e) {
    final m = Map<String, dynamic>.from(e as Map);
    return SmsItem(
      body: m['body']?.toString() ?? '',
      address: m['address']?.toString() ?? '',
      dateMs: (m['date'] as num?)?.toInt(),
      type: (m['type'] as num?)?.toInt() ?? 1,
      sim: (m['sub_id'] as num?)?.toInt() ?? 1,
      read: (m['read'] as num?)?.toInt() == 1,
      id: (m['_id'] as num?)?.toInt(),
      threadId: (m['thread_id'] as num?)?.toInt(),
      isMms: (m['is_mms'] as num?)?.toInt() == 1,
      hasMedia: (m['has_media'] as num?)?.toInt() == 1,
    );
  }

  static int _dateDesc(SmsItem a, SmsItem b) {
    final d = (b.dateMs ?? 0).compareTo(a.dateMs ?? 0);
    if (d != 0) return d;
    // 与 Kotlin 同序：is_mms 降序（uid 已把 MMS 抬到高位）+ id 降序。
    return (b.uid ?? 0).compareTo(a.uid ?? 0);
  }

  /// 见 [DeleteBatchResult]。按 `is_mms` 路由删除，SMS / MMS 不会误删对方同号行。
  ///
  /// 线协议：`[{id, is_mms}]`；原生兼容旧 `List<Int>`（纯 SMS）。
  Future<DeleteBatchResult> deleteSmsBatch(List<SmsItem> items) async {
    final targets = [
      for (final e in items)
        if (e.id != null) {'id': e.id, 'is_mms': e.isMms ? 1 : 0},
    ];
    if (targets.isEmpty) return DeleteBatchResult.ok(0);
    try {
      final n = await _ch.invokeMethod<int>('deleteSmsBatch', targets);
      return n == null
          ? const DeleteBatchResult.failed()
          : DeleteBatchResult.ok(n);
    } catch (e) {
      debugPrint('deleteSmsBatch: $e');
      return const DeleteBatchResult.failed();
    }
  }

  /// 分块删除：按 [deleteChunkSize] 循环调用 [deleteSmsBatch]，每块完成回调
  /// [onProgress]。混合 SMS/MMS 目标保持原序整块过通道，线协议不变。
  ///
  /// - 某块失败：停止后续块，返回 [DeleteStopReason.failed]。
  /// - [shouldCancel] 置真：停止后续块（已发出的不撤回），
  ///   返回 [DeleteStopReason.cancelled]。
  /// - [DeleteChunkResult.deleted] 是**顺序前缀**长度，调用方可直接
  ///   `targets.take(deleted)` 得到已删项；失败/取消块的目标不算已删。
  Future<DeleteChunkResult> deleteSmsBatchChunked(
    List<SmsItem> items, {
    void Function(int done, int total)? onProgress,
    bool Function()? shouldCancel,
    int chunkSize = deleteChunkSize,
  }) async {
    final targets = [for (final e in items) if (e.id != null) e];
    final total = targets.length;
    if (total == 0) return const DeleteChunkResult(deleted: 0, total: 0);
    var done = 0;
    onProgress?.call(done, total);
    for (var offset = 0; offset < total; offset += chunkSize) {
      if (shouldCancel?.call() ?? false) {
        return DeleteChunkResult(
          deleted: done,
          total: total,
          reason: DeleteStopReason.cancelled,
        );
      }
      final end = (offset + chunkSize).clamp(0, total);
      final chunk = targets.sublist(offset, end);
      final r = await deleteSmsBatch(chunk);
      if (!r.ok) {
        return DeleteChunkResult(
          deleted: done,
          total: total,
          reason: DeleteStopReason.failed,
        );
      }
      // 整块视为完成：已删或本就不在库中的行都应从列表消失。
      done += chunk.length;
      onProgress?.call(done, total);
      // 让出事件循环：驱动进度帧绘制，并给「停止」点击生效的机会
      //（连续快速回包时整段循环会挤在同一轮微任务里，UI 与取消都插不进来）。
      if (offset + chunkSize < total) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    return DeleteChunkResult(deleted: done, total: total);
  }

  /// 批量插入（导入 CSV）。仅新增，不删不改。见 [InsertBatchResult]。
  ///
  /// 线协议 Map `{ok, inserted, failed, errors}`；兼容旧 `int?` / 通道异常。
  /// 大列表按 [insertChunkSize] 分片过通道：单条 platform message 不超过
  /// Binder ~1MB 上限；errors[].index 始终是**全局**入参下标。
  Future<InsertBatchResult> insertSmsBatch(
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty) return const InsertBatchResult.ok(0);
    var inserted = 0;
    var failed = 0;
    final errors = <InsertRowError>[];
    for (var offset = 0; offset < rows.length; offset += insertChunkSize) {
      final end = (offset + insertChunkSize).clamp(0, rows.length);
      final chunk = rows.sublist(offset, end);
      // 后续分片的全局下标偏移；-1（整批级）保持不变。
      final base = offset;
      InsertRowError remap(InsertRowError e) => InsertRowError(
        index: e.index < 0 ? e.index : e.index + base,
        code: e.code,
        message: e.message,
      );
      try {
        final raw = await _ch.invokeMethod<Object?>('insertSmsBatch', chunk);
        final r = InsertBatchResult.fromWire(raw);
        if (!r.ok) {
          // 非默认/整批失败：其后分片无意义，直接汇总返回。
          return InsertBatchResult(
            inserted: inserted + r.inserted,
            failed: failed + (r.failed > 0 ? r.failed : chunk.length - r.inserted),
            errors: [...errors, ...r.errors.map(remap)],
            failure: r.failure,
          );
        }
        inserted += r.inserted;
        failed += r.failed;
        errors.addAll(r.errors.map(remap));
      } catch (e) {
        debugPrint('insertSmsBatch: $e');
        return InsertBatchResult(
          inserted: inserted,
          failed: failed + (rows.length - offset),
          errors: errors,
          failure: BatchFailure.notDefaultOrError,
        );
      }
    }
    return InsertBatchResult.ok(inserted, failed: failed, errors: errors);
  }
}
