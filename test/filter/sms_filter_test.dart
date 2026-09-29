import 'package:flutter_test/flutter_test.dart';
import 'package:sms/features/filter/filter_sheet.dart';
import 'package:sms/models/sms_item.dart';

/// SmsFilter 状态与匹配（features/filter）。
void main() {
  group('active 与 copyWith', () {
    test('字段置位后 active，copyWith 可还原', () {
      const f = SmsFilter();
      expect(f.active, isFalse);
      final f2 = f.copyWith(
        keyword: '验证码',
        type: 2,
        sameAddress: '10010',
        sameSim: 1,
      );
      expect(f2.active, isTrue);
      const f3 = SmsFilter();
      expect(f3.active, isFalse);
      expect(f3.type, 0);
      expect(f3.keyword, '');
      expect(f3.start, isNull);
      expect(f3.end, isNull);
      expect(f3.sameAddress, isNull);
      expect(f3.sameSim, isNull);
    });
  });

  group('copyWith', () {
    test('copyWith 生成独立副本', () {
      const f = SmsFilter(keyword: 'x', sameAddress: '10010', sameSim: 2);
      final c = f.copyWith();
      expect(c.keyword, 'x');
      expect(c.sameAddress, '10010');
      expect(c.sameSim, 2);
    });

    test('copyWith 部分字段修改且互不影响', () {
      final src = SmsFilter(
        keyword: 'k',
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 2),
        type: 2,
        sameAddress: '10010',
        sameSim: 2,
      );
      final dst = src.copyWith(keyword: 'changed', sameAddress: null);
      expect(dst.keyword, 'changed');
      expect(dst.start, src.start);
      expect(dst.end, src.end);
      expect(dst.type, 2);
      expect(dst.sameAddress, isNull);
      expect(dst.sameSim, 2);
      // 原对象不受影响
      expect(src.keyword, 'k');
      expect(src.sameAddress, '10010');
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
      const byKeyword = SmsFilter(keyword: '验证码');
      expect(items.where(byKeyword.matches).map((e) => e.id), [2]);

      const byAddr = SmsFilter(sameAddress: '10010');
      expect(items.where(byAddr.matches).map((e) => e.id), [1]);

      const bySim = SmsFilter(sameSim: 2);
      expect(items.where(bySim.matches).map((e) => e.id), [3]);

      const byType = SmsFilter(type: 2);
      expect(items.where(byType.matches).map((e) => e.id), [3]);

      final byDate = SmsFilter(start: DateTime(2000, 1, 2));
      expect(items.where(byDate.matches).map((e) => e.id), isEmpty);
    });

    test('type=3 只命中彩信', () {
      const byMms = SmsFilter(type: 3);
      expect(items.where(byMms.matches).map((e) => e.id), [5]);
    });

    test('type=1 收件含彩信（按 kind 而非 isMms）', () {
      const byInbox = SmsFilter(type: 1);
      // id=5 是 type=1 的彩信，kind=received，应命中；id=4 也是收件
      expect(items.where(byInbox.matches).map((e) => e.id), [1, 2, 4, 5]);
    });
  });
}
