import 'package:flutter_test/flutter_test.dart';
import 'package:sms/services/sms_filter.dart';
import 'package:sms_advanced/sms_advanced.dart';

SmsMessage _msg({int? id, String? body, int? sim, DateTime? date}) {
  return SmsMessage('10086', body, id: id, threadId: 1, sim: sim, date: date);
}

void main() {
  group('filterByKeyword', () {
    test('keyword 为空时原样返回全部', () {
      final messages = [_msg(body: 'hello'), _msg(body: 'world')];
      expect(filterByKeyword(messages, ''), same(messages));
    });

    test('按子串匹配正文', () {
      final messages = [_msg(body: '验证码 123456'), _msg(body: 'meeting at 5pm')];
      final result = filterByKeyword(messages, '123');
      expect(result.length, 1);
      expect(result.first.body, '验证码 123456');
    });

    test('body 为 null 的短信不匹配也不崩溃', () {
      final messages = [_msg(body: null), _msg(body: 'has code 42')];
      final result = filterByKeyword(messages, '42');
      expect(result.length, 1);
      expect(result.first.body, 'has code 42');
    });
  });

  group('filterByDateRange', () {
    test('区间为空时原样返回', () {
      final messages = [_msg(date: DateTime(2026, 1, 1))];
      expect(filterByDateRange(messages, null, null), same(messages));
    });

    test('只保留区间内的短信', () {
      final messages = [
        _msg(id: 1, date: DateTime(2026, 1, 1)),
        _msg(id: 2, date: DateTime(2026, 6, 15)),
        _msg(id: 3, date: DateTime(2026, 12, 31)),
      ];
      final result = filterByDateRange(
        messages,
        DateTime(2026, 1, 2),
        DateTime(2026, 12, 30),
      );
      expect(result.map((m) => m.id), [2]);
    });

    test('date 为 null 的短信被过滤掉', () {
      final messages = [_msg(id: 1), _msg(id: 2, date: DateTime(2026, 5, 5))];
      final result = filterByDateRange(
        messages,
        DateTime(2026, 1, 1),
        DateTime(2026, 12, 31),
      );
      expect(result.map((m) => m.id), [2]);
    });
  });

  group('filterBySim', () {
    test('sim 为 null 时原样返回', () {
      final messages = [_msg(sim: 0), _msg(sim: 1)];
      expect(filterBySim(messages, null), same(messages));
    });

    test('只保留指定 SIM 的短信', () {
      final messages = [
        _msg(id: 1, sim: 0),
        _msg(id: 2, sim: 1),
        _msg(id: 3, sim: 1),
      ];
      final result = filterBySim(messages, 1);
      expect(result.map((m) => m.id), [2, 3]);
    });
  });

  group('sortByDateDesc', () {
    test('按日期降序排列', () {
      final messages = [
        _msg(id: 1, date: DateTime(2026, 1, 1)),
        _msg(id: 2, date: DateTime(2026, 3, 1)),
        _msg(id: 3, date: DateTime(2026, 2, 1)),
      ];
      sortByDateDesc(messages);
      expect(messages.map((m) => m.id), [2, 3, 1]);
    });

    test('date 为 null 的排在末尾，不崩溃', () {
      final messages = [_msg(id: 1), _msg(id: 2, date: DateTime(2026, 3, 1))];
      sortByDateDesc(messages);
      expect(messages.map((m) => m.id), [2, 1]);
    });
  });
}
