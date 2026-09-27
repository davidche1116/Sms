import 'package:flutter_test/flutter_test.dart';
import 'package:sms/features/filter/filter_sheet.dart';
import 'package:sms/models/sms_item.dart';

/// SmsFilter 状态与匹配（features/filter）。
void main() {
  group('active 与 reset', () {
    test('字段置位后 active，reset 全部还原', () {
      final f = SmsFilter();
      expect(f.active, isFalse);
      f
        ..keyword = '验证码'
        ..type = 2
        ..sameAddress = '10010'
        ..sameSim = 1;
      expect(f.active, isTrue);
      f.reset();
      expect(f.active, isFalse);
      expect(f.type, 0);
      expect(f.keyword, '');
      expect(f.start, isNull);
      expect(f.end, isNull);
      expect(f.sameAddress, isNull);
      expect(f.sameSim, isNull);
    });
  });

  group('copy / applyFrom', () {
    test('copy 生成独立副本', () {
      final f = SmsFilter()
        ..keyword = 'x'
        ..sameAddress = '10010'
        ..sameSim = 2;
      final c = f.copy();
      f
        ..keyword = 'y'
        ..sameAddress = null;
      expect(c.keyword, 'x');
      expect(c.sameAddress, '10010');
      expect(c.sameSim, 2);
    });

    test('applyFrom 完整拷贝全部字段且互不影响', () {
      final src = SmsFilter()
        ..keyword = 'k'
        ..start = DateTime(2026, 1, 1)
        ..end = DateTime(2026, 1, 2)
        ..type = 2
        ..sameAddress = '10010'
        ..sameSim = 2;
      final dst = SmsFilter()..applyFrom(src);
      expect(dst.keyword, 'k');
      expect(dst.start, src.start);
      expect(dst.end, src.end);
      expect(dst.type, 2);
      expect(dst.sameAddress, '10010');
      expect(dst.sameSim, 2);

      src
        ..keyword = 'changed'
        ..sameAddress = null
        ..sameSim = 9;
      expect(dst.keyword, 'k');
      expect(dst.sameAddress, '10010');
      expect(dst.sameSim, 2);
    });
  });

  group('matches', () {
    final items = [
      const SmsItem(
        id: 1,
        body: '流量提醒',
        address: '10010',
        dateMs: 0,
        type: 1,
        sim: 1,
      ),
      const SmsItem(
        id: 2,
        body: '验证码 8888',
        address: '10086',
        dateMs: 0,
        type: 1,
        sim: 1,
      ),
      const SmsItem(
        id: 3,
        body: '好的',
        address: '138',
        dateMs: 0,
        type: 2,
        sim: 2,
      ),
      // date null：日期筛选时被丢弃，无日期筛选时保留
      const SmsItem(id: 4, body: '无日期', address: '1', type: 1, sim: 1),
      const SmsItem(
        id: 5,
        body: '彩信正文',
        address: '10086',
        dateMs: 0,
        type: 1,
        sim: 1,
        isMms: true,
      ),
    ];

    test('关键词 / 同号 / 同卡 / 类型 / 日期各自命中', () {
      final byKeyword = SmsFilter()..keyword = '验证码';
      expect(items.where(byKeyword.matches).map((e) => e.id), [2]);

      final byAddr = SmsFilter()..sameAddress = '10010';
      expect(items.where(byAddr.matches).map((e) => e.id), [1]);

      final bySim = SmsFilter()..sameSim = 2;
      expect(items.where(bySim.matches).map((e) => e.id), [3]);

      final byType = SmsFilter()..type = 2;
      expect(items.where(byType.matches).map((e) => e.id), [3]);

      final byDate = SmsFilter()..start = DateTime(2000, 1, 2);
      expect(items.where(byDate.matches).map((e) => e.id), isEmpty);
    });

    test('type=3 只命中彩信', () {
      final byMms = SmsFilter()..type = 3;
      expect(items.where(byMms.matches).map((e) => e.id), [5]);
    });

    test('type=1 收件含彩信（按 kind 而非 isMms）', () {
      final byInbox = SmsFilter()..type = 1;
      // id=5 是 type=1 的彩信，kind=received，应命中；id=4 也是收件
      expect(items.where(byInbox.matches).map((e) => e.id), [1, 2, 4, 5]);
    });
  });
}
