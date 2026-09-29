import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/generated/app_localizations.dart';
import 'package:sms/models/sms_item.dart';

/// SmsItem 映射/时间（QUERY_DELETE_DESIGN §5.8 / §10）。
void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('type → kind', () {
    test('1 收件 / 2,4,5,6 发送 / 3 草稿', () {
      expect(
        const SmsItem(body: 'a', address: 'b', type: 1).kind,
        SmsKind.received,
      );
      for (final t in [2, 4, 5, 6]) {
        expect(SmsItem(body: 'a', address: 'b', type: t).kind, SmsKind.sent);
      }
      expect(
        const SmsItem(body: 'a', address: 'b', type: 3).kind,
        SmsKind.draft,
      );
    });

    test('type 缺省按收件处理；date 为 null 不崩溃', () {
      const e = SmsItem(body: 'a', address: 'b');
      expect(e.kind, SmsKind.received);
      expect(e.time(), '');
      expect(e.dayLabelOf(zh), '未知');
      expect(e.dayLabelOf(en), 'Unknown');
    });
  });

  group('uid（跨 SMS/MMS 唯一键）', () {
    test('SMS uid == id；MMS uid == id + 偏移', () {
      const sms = SmsItem(id: 5, body: '', address: '');
      const mms = SmsItem(id: 5, body: '', address: '', isMms: true);
      expect(sms.uid, 5);
      expect(mms.uid, 5 + SmsItem.mmsUidOffset);
      expect(sms.uid, isNot(mms.uid));
    });

    test('无 id → uid 为 null', () {
      expect(const SmsItem(body: '', address: '').uid, isNull);
    });
  });

  group('bodyOf（彩信占位）', () {
    test('短信直接回 body', () {
      const e = SmsItem(id: 1, body: '你好', address: '1');
      expect(e.bodyOf(zh), '你好');
    });

    test('彩信有文本回文本', () {
      const e = SmsItem(id: 1, body: '彩信正文', address: '', isMms: true);
      expect(e.bodyOf(zh), '彩信正文');
    });

    test('彩信无文本回占位；含附件时标注', () {
      const bare = SmsItem(id: 1, body: '', address: '', isMms: true);
      expect(bare.bodyOf(zh), '[彩信]');
      expect(bare.bodyOf(en), '[MMS]');
      const media = SmsItem(
        id: 1,
        body: '',
        address: '',
        isMms: true,
        hasMedia: true,
      );
      expect(media.bodyOf(zh), '[彩信]·含附件');
      expect(media.bodyOf(en), contains('attachment'));
    });
  });

  group('dayLabel / time', () {
    test('今天只显时:分，dayLabel 为「今天」', () {
      final now = DateTime.now();
      final noon = DateTime(now.year, now.month, now.day, 12, 0);
      final e = SmsItem(
        body: 'a',
        address: 'b',
        dateMs: noon.millisecondsSinceEpoch,
      );
      expect(e.dayLabelOf(zh), '今天');
      expect(e.dayLabelOf(en), 'Today');
      expect(e.time(), '12:00');
    });

    test('昨天显示「昨天」（按自然日，跨月/跨年同样成立）', () {
      final now = DateTime.now();
      final yesterdayNoon = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 1))
          // 取昨天中午，避免刚好卡在零点边界
          .add(const Duration(hours: 12));
      final e = SmsItem(
        body: 'a',
        address: 'b',
        dateMs: yesterdayNoon.millisecondsSinceEpoch,
      );
      expect(e.dayLabelOf(zh), '昨天');
      expect(e.dayLabelOf(en), 'Yesterday');
      expect(e.time(), contains('-'));
    });

    test('更早日期回退 YYYY-MM-DD / MM-DD', () {
      final ms = DateTime(2000, 1, 1).millisecondsSinceEpoch;
      final e = SmsItem(body: 'a', address: 'b', dateMs: ms);
      expect(e.dayLabelOf(zh), '2000-01-01');
      expect(e.dayLabelOf(en), '2000-01-01');
      expect(e.time(), '01-01');
    });
  });
}
