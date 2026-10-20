import 'package:flutter_test/flutter_test.dart';
import 'package:sms/features/filter/filter_sheet.dart';
import 'package:sms/features/filter/keyword_presets.dart';
import 'package:sms/features/filter/quick_range.dart';
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

  group('时间快捷预设', () {
    test('cutoffOf：天数精确相减，月 / 年按日历回退（月末收窄）', () {
      final anchor = DateTime(2026, 3, 31, 10, 30);
      expect(cutoffOf(SmsQuickRange.d7, anchor), DateTime(2026, 3, 24, 10, 30));
      expect(
        cutoffOf(SmsQuickRange.d15, anchor),
        DateTime(2026, 3, 16, 10, 30),
      );
      expect(cutoffOf(SmsQuickRange.d30, anchor), DateTime(2026, 3, 1, 10, 30));
      // 3/31 减 3 个月 = 12/31；减 6 个月 = 9/30（9 月没有 31 号）
      expect(
        cutoffOf(SmsQuickRange.m3, anchor),
        DateTime(2025, 12, 31, 10, 30),
      );
      expect(cutoffOf(SmsQuickRange.m6, anchor), DateTime(2025, 9, 30, 10, 30));
      expect(cutoffOf(SmsQuickRange.y1, anchor), DateTime(2025, 3, 31, 10, 30));
      // 闰年：2024/5/31 减 3 个月 = 2024/2/29
      expect(
        cutoffOf(SmsQuickRange.m3, DateTime(2024, 5, 31, 8, 0)),
        DateTime(2024, 2, 29, 8, 0),
      );
    });

    test('withQuickRange 清空自定义区间并快照锚点', () {
      final f = SmsFilter(
        start: DateTime(2020),
        end: DateTime(2021),
      ).withQuickRange(SmsQuickRange.d30, DateTime(2026, 9, 26, 11));
      expect(f.start, isNull);
      expect(f.end, isNull);
      expect(f.quickRange, SmsQuickRange.d30);
      expect(f.quickAnchor, DateTime(2026, 9, 26, 11));
      expect(f.effectiveStart, isNull);
      expect(f.effectiveEnd, DateTime(2026, 8, 27, 11));
      expect(f.endExact, isTrue);
      expect(f.active, isTrue);
    });

    test('预设边界精确到毫秒，不把当天 23:59 之后的项放进来', () {
      final f = const SmsFilter().withQuickRange(
        SmsQuickRange.d7,
        DateTime(2026, 9, 26, 11, 0),
      );
      bool hit(DateTime d) => f.matches(
        SmsItem(
          id: 1,
          body: 'x',
          address: '1',
          dateMs: d.millisecondsSinceEpoch,
          type: 1,
          sim: 1,
        ),
      );

      expect(hit(DateTime(2026, 8, 1)), isTrue);
      expect(hit(DateTime(2026, 9, 19, 10, 59)), isTrue);
      expect(hit(DateTime(2026, 9, 19, 11, 0)), isTrue); // 边界闭区间
      expect(hit(DateTime(2026, 9, 19, 11, 1)), isFalse);
      // 关键：9/19 晚上已经超过「7 天前 11:00」，不能被 endOfDay 规则放进来
      expect(hit(DateTime(2026, 9, 19, 23, 0)), isFalse);
      expect(hit(DateTime(2026, 9, 27)), isFalse);
      // 无日期的行在日期筛选下一律丢弃
      expect(f.matches(const SmsItem(id: 9, body: 'x', address: '1')), isFalse);
    });

    test('自定义 end 维持「当天 23:59:59.999」闭区间（旧行为不变）', () {
      final f = SmsFilter(end: DateTime(2026, 9, 19));
      bool hit(DateTime d) => f.matches(
        SmsItem(
          id: 1,
          body: 'x',
          address: '1',
          dateMs: d.millisecondsSinceEpoch,
          type: 1,
          sim: 1,
        ),
      );
      expect(f.endExact, isFalse);
      expect(hit(DateTime(2026, 9, 19, 23, 59, 59)), isTrue);
      expect(hit(DateTime(2026, 9, 20)), isFalse);
    });

    test('copyWith(quickRange: null) 只清预设，不动其它条件', () {
      final src = const SmsFilter(
        keyword: 'k',
        type: 1,
        sameSim: 2,
      ).withQuickRange(SmsQuickRange.y1, DateTime(2026, 9, 26));
      final cleared = src.copyWith(quickRange: null, quickAnchor: null);
      expect(cleared.quickRange, isNull);
      expect(cleared.quickAnchor, isNull);
      expect(cleared.start, isNull);
      expect(cleared.end, isNull);
      expect(cleared.keyword, 'k');
      expect(cleared.type, 1);
      expect(cleared.sameSim, 2);
      expect(cleared.active, isTrue);
      // 原实例不受影响
      expect(src.quickRange, SmsQuickRange.y1);
    });

    test('锚点快照：同一 filter 反复求值时边界不漂移', () {
      final anchor = DateTime(2026, 9, 26, 11, 0);
      final f = const SmsFilter().withQuickRange(SmsQuickRange.d30, anchor);
      final first = f.effectiveEnd;
      expect(f.effectiveEnd, first);
      expect(f.effectiveEnd, first);
    });
  });

  group('类别预设', () {
    const bankWords = <String>['银行', '尾号', 'ICBC'];
    final items = [
      const SmsItem(id: 1, body: '【工商银行】尾号 8888 到账', address: '95588'),
      const SmsItem(id: 2, body: '流量提醒', address: '10010'),
      const SmsItem(id: 3, body: 'icbc 提醒您', address: '95588'),
    ];

    test('withPreset 展开词组并清空手动关键词（互斥）', () {
      final f = const SmsFilter(
        keyword: 'abc',
      ).withPreset(SmsKeywordPreset.bank, bankWords);
      expect(f.keyword, '');
      expect(f.preset, SmsKeywordPreset.bank);
      expect(f.keywordGroup, bankWords);
      expect(f.presetKeywordsForQuery, bankWords);
    });

    test('matches 组内 OR，且 ASCII 大小写不敏感（对齐原生 LIKE）', () {
      final f = const SmsFilter().withPreset(SmsKeywordPreset.bank, bankWords);
      expect(items.where(f.matches).map((e) => e.id), [1, 3]);
    });

    test('取消预设后恢复不过滤', () {
      final f = const SmsFilter()
          .withPreset(SmsKeywordPreset.bank, bankWords)
          .copyWith(preset: null, keywordGroup: const <String>[]);
      expect(f.active, isFalse);
      expect(items.where(f.matches).map((e) => e.id), [1, 2, 3]);
    });

    test('类别预设与时间预设可叠加（AND）', () {
      final f = const SmsFilter()
          .withPreset(SmsKeywordPreset.bank, bankWords)
          .withQuickRange(SmsQuickRange.y1, DateTime(2026, 9, 26, 11, 0));
      final rows = [
        SmsItem(
          id: 1,
          body: '银行到账',
          address: '95588',
          dateMs: DateTime(2024, 1, 1).millisecondsSinceEpoch,
        ),
        SmsItem(
          id: 2,
          body: '银行到账',
          address: '95588',
          dateMs: DateTime(2026, 9, 1).millisecondsSinceEpoch,
        ),
      ];
      expect(rows.where(f.matches).map((e) => e.id), [1]);
    });
  });
}
