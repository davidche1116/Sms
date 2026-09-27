import 'package:flutter_test/flutter_test.dart';
import 'package:sms/models/sms_item.dart';
import 'package:sms/services/sms_repository.dart';

import '../helpers/app_channel.dart';

/// 分块删除：进度步进、失败中断、取消停发、MMS 混合线协议。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(clearAppChannelHandler);

  SmsItem item(int id, {bool isMms = false}) =>
      SmsItem(id: id, body: '', address: '', isMms: isMms);

  List<SmsItem> items(int n) => [for (var i = 1; i <= n; i++) item(i)];

  /// 记录每次 `deleteSmsBatch` 的线协议载荷；[respond] 决定该块返回值（null=失败）。
  void mockDelete({
    required Object? Function(int callIndex, List<Object?> wire) respond,
    List<List<Object?>>? captured,
  }) {
    var i = 0;
    setAppChannelHandler((call) async {
      if (call.method != 'deleteSmsBatch') return null;
      final wire = (call.arguments as List).cast<Object?>();
      captured?.add(wire);
      return respond(i++, wire);
    });
  }

  test('全成：进度按块步进，完整删完', () async {
    final progress = <(int, int)>[];
    mockDelete(respond: (_, wire) => wire.length);
    final r = await SmsRepository().deleteSmsBatchChunked(
      items(5),
      chunkSize: 2,
      onProgress: (done, total) => progress.add((done, total)),
    );
    expect(r.complete, isTrue);
    expect(r.deleted, 5);
    expect(r.total, 5);
    expect(r.reason, DeleteStopReason.none);
    expect(progress, [(0, 5), (2, 5), (4, 5), (5, 5)]);
  });

  test('某块失败：停止后续块，已删为顺序前缀', () async {
    final calls = <List<Object?>>[];
    mockDelete(
      captured: calls,
      respond: (i, wire) => i == 1 ? null : wire.length,
    );
    final r = await SmsRepository().deleteSmsBatchChunked(
      items(5),
      chunkSize: 2,
    );
    expect(r.complete, isFalse);
    expect(r.deleted, 2);
    expect(r.total, 5);
    expect(r.reason, DeleteStopReason.failed);
    // 第 2 块失败后，第 3 块不再发出
    expect(calls.length, 2);
  });

  test('首块即失败：deleted=0，后续不发', () async {
    final calls = <List<Object?>>[];
    mockDelete(captured: calls, respond: (_, _) => null);
    final r = await SmsRepository().deleteSmsBatchChunked(
      items(5),
      chunkSize: 2,
    );
    expect(r.deleted, 0);
    expect(r.reason, DeleteStopReason.failed);
    expect(calls.length, 1);
  });

  test('取消：已发出的块不撤回，未发出的不再发', () async {
    final calls = <List<Object?>>[];
    var cancel = false;
    mockDelete(
      captured: calls,
      respond: (_, wire) {
        cancel = true; // 首块完成后置取消
        return wire.length;
      },
    );
    final r = await SmsRepository().deleteSmsBatchChunked(
      items(5),
      chunkSize: 2,
      shouldCancel: () => cancel,
    );
    expect(r.reason, DeleteStopReason.cancelled);
    expect(r.deleted, 2); // 只有已发出并完成的首块
    expect(calls.length, 1);
  });

  test('取消请求在首块发出前：一块都不发', () async {
    final calls = <List<Object?>>[];
    mockDelete(captured: calls, respond: (_, wire) => wire.length);
    final r = await SmsRepository().deleteSmsBatchChunked(
      items(5),
      chunkSize: 2,
      shouldCancel: () => true,
    );
    expect(r.reason, DeleteStopReason.cancelled);
    expect(r.deleted, 0);
    expect(calls, isEmpty);
  });

  test('MMS 混合目标按原序分片，线协议保留 is_mms', () async {
    final calls = <List<Object?>>[];
    mockDelete(captured: calls, respond: (_, wire) => wire.length);
    await SmsRepository().deleteSmsBatchChunked([
      item(1),
      item(2, isMms: true),
      item(3),
      item(4, isMms: true),
      item(5),
    ], chunkSize: 2);
    expect(calls, [
      [
        {'id': 1, 'is_mms': 0},
        {'id': 2, 'is_mms': 1},
      ],
      [
        {'id': 3, 'is_mms': 0},
        {'id': 4, 'is_mms': 1},
      ],
      [
        {'id': 5, 'is_mms': 0},
      ],
    ]);
  });

  test('无 id 行被滤掉；全无 id 时零调用零删除', () async {
    final calls = <List<Object?>>[];
    mockDelete(captured: calls, respond: (_, wire) => wire.length);
    final r = await SmsRepository().deleteSmsBatchChunked([
      item(1),
      const SmsItem(body: '', address: ''),
    ], chunkSize: 10);
    expect(r.deleted, 1);
    expect(r.complete, isTrue);
    expect(calls.length, 1);

    final empty = await SmsRepository().deleteSmsBatchChunked([
      const SmsItem(body: '', address: ''),
    ]);
    expect(empty.deleted, 0);
    expect(empty.complete, isTrue);
    expect(calls.length, 1); // 未再调用
  });

  test('单块整批：一次通道调用即完成', () async {
    final calls = <List<Object?>>[];
    mockDelete(captured: calls, respond: (_, wire) => wire.length);
    final r = await SmsRepository().deleteSmsBatchChunked(items(3));
    expect(r.complete, isTrue);
    expect(r.deleted, 3);
    expect(calls.length, 1);
  });
}
