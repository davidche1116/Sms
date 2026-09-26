import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sms/main.dart';

class SmsQueryPermissionException implements Exception {
  const SmsQueryPermissionException();
}

/// 薄封装原生通道 `com.dc16.sms/smsApp`。
class SmsRepository {
  static const _ch = MethodChannel('com.dc16.sms/smsApp');

  Future<bool> hasReadSmsPermission() async {
    try {
      return await _ch.invokeMethod<bool>('hasReadSmsPermission') ?? false;
    } catch (e) {
      debugPrint('hasReadSmsPermission: $e');
      return false;
    }
  }

  /// 等待系统弹窗结束并返回是否真正可读。
  Future<bool> requestReadSms() async {
    try {
      final ok = await _ch.invokeMethod<bool>('requestReadSms');
      return ok == true || await hasReadSmsPermission();
    } catch (e) {
      debugPrint('requestReadSms: $e');
      return hasReadSmsPermission();
    }
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

  /// had | no | error
  Future<String?> setDefaultSms() async {
    try {
      return await _ch.invokeMethod<String>('setDefaultSms');
    } catch (e) {
      debugPrint('setDefaultSms: $e');
      return 'error';
    }
  }

  /// not_default | settings | ok | error
  Future<String?> restoreDefaultSms() async {
    try {
      return await _ch.invokeMethod<String>('restoreDefaultSms');
    } catch (e) {
      debugPrint('restoreDefaultSms: $e');
      return 'error';
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

  /// 打开本应用系统设置（用于权限被彻底关闭时）。
  Future<void> openAppSettingsFallback() async {
    try {
      await _ch.invokeMethod<bool>('openDefaultSmsSettings');
    } catch (e) {
      debugPrint('openAppSettingsFallback: $e');
    }
  }

  Future<List<SmsItem>> queryAll() => _query(null);

  Future<List<SmsItem>> queryByAddress(String address) => _query(address);

  Future<List<SmsItem>> _query(String? address) async {
    try {
      final raw = await _ch.invokeMethod<dynamic>('querySms', {
        if (address != null && address.isNotEmpty) 'address': address,
      });
      if (raw is! Map) return const [];
      if (raw['error'] == 'permission') {
        throw const SmsQueryPermissionException();
      }
      if (raw['error'] != null) {
        throw Exception('querySms: ${raw['error']}');
      }
      final rows = (raw['messages'] as List?) ?? const [];
      return rows.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return SmsItem(
          body: m['body']?.toString() ?? '',
          address: m['address']?.toString() ?? '',
          time: _time(m['date']),
          dayLabel: _day(m['date']),
          sim: (m['sub_id'] as num?)?.toInt() ?? 1,
          id: (m['_id'] as num?)?.toInt(),
          threadId: (m['thread_id'] as num?)?.toInt(),
        );
      }).toList();
    } on MissingPluginException {
      return const [];
    }
  }

  Future<int?> deleteSmsBatch(List<int> ids) async {
    try {
      return await _ch.invokeMethod<int>('deleteSmsBatch', ids);
    } catch (e) {
      debugPrint('deleteSmsBatch: $e');
      return null;
    }
  }

  String _time(Object? ms) {
    final t = (ms as num?)?.toInt();
    if (t == null) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(t);
    final now = DateTime.now();
    final sameDay =
        d.year == now.year && d.month == now.month && d.day == now.day;
    if (sameDay) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _day(Object? ms) {
    final t = (ms as num?)?.toInt();
    if (t == null) return '未知';
    final d = DateTime.fromMillisecondsSinceEpoch(t);
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '今天';
    }
    if (d.year == now.year && d.month == now.month && d.day == now.day - 1) {
      return '昨天';
    }
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
