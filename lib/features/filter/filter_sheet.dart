import 'package:flutter/material.dart';

/// 列表筛选条件。type：0 全部 / 1 仅收件箱 / 2 仅已发送（草稿归入发送侧）。
class SmsFilter {
  String keyword = '';
  DateTime? start;
  DateTime? end;
  int type = 0;
  String? sameAddress;
  int? sameSim;

  bool get active =>
      keyword.isNotEmpty ||
      start != null ||
      end != null ||
      type != 0 ||
      sameAddress != null ||
      sameSim != null;

  void reset() {
    keyword = '';
    start = null;
    end = null;
    type = 0;
    sameAddress = null;
    sameSim = null;
  }

  SmsFilter copy() => SmsFilter()
    ..keyword = keyword
    ..start = start
    ..end = end
    ..type = type
    ..sameAddress = sameAddress
    ..sameSim = sameSim;

  /// 供测试 / Chip 文案使用。
  static String fmtDate(DateTime? d) => d == null
      ? ''
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// 搜索 / 筛选弹层（单一入口，UI_DESIGN §6.3）。返回应用后的筛选；直接关闭返回 null。
Future<SmsFilter?> showFilterSheet(BuildContext context, SmsFilter current) {
  final f = current.copy();
  return showModalBottomSheet<SmsFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
      ),
      child: StatefulBuilder(
        builder: (ctx, setLocal) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('搜索 / 筛选', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: '关键词',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setLocal(() => f.keyword = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text(
                        f.start == null ? '开始日期' : SmsFilter.fmtDate(f.start),
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: f.start ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setLocal(() => f.start = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text(
                        f.end == null ? '结束日期' : SmsFilter.fmtDate(f.end),
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: f.end ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setLocal(() => f.end = d);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: f.type,
                decoration: const InputDecoration(labelText: '类型'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('全部')),
                  DropdownMenuItem(value: 1, child: Text('仅收件箱')),
                  DropdownMenuItem(value: 2, child: Text('仅已发送')),
                ],
                onChanged: (v) => setLocal(() => f.type = v ?? 0),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setLocal(f.reset),
                      child: const Text('重置'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, f),
                      child: const Text('完成'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
