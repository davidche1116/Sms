import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/sms_item.dart';

/// 列表项动作 Sheet（UI_DESIGN §6.1b）。
Future<void> showSmsActionSheet(
  BuildContext context,
  SmsItem e, {
  required void Function(String address) onSameAddress,
  required void Function(int sim) onSameSim,
  required VoidCallback onDelete,
  required VoidCallback onHide,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final pad = MediaQuery.paddingOf(ctx).bottom;
      void toast(String msg) {
        ScaffoldMessenger.of(ctx)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
          );
      }

      return SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.75,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 10, bottom: 4),
              child: SizedBox(
                width: 36,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFB0B8B3),
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(0, 4, 0, pad + 12),
                children: [
                  ListTile(
                    dense: true,
                    title: Text(
                      e.address,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('卡${e.sim} · ${e.time}'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.tag),
                    title: const Text('同号短信'),
                    subtitle: const Text('只看这个号码的全部短信'),
                    onTap: () {
                      Navigator.pop(ctx);
                      onSameAddress(e.address);
                    },
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.sim_card_outlined),
                    title: const Text('同卡短信'),
                    onTap: () {
                      Navigator.pop(ctx);
                      onSameSim(e.sim);
                    },
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.copy_outlined),
                    title: const Text('复制号码'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Clipboard.setData(ClipboardData(text: e.address));
                      toast('已复制号码');
                    },
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.copy_all_outlined),
                    title: const Text('复制正文'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Clipboard.setData(ClipboardData(text: e.body));
                      toast('已复制正文');
                    },
                  ),
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.delete_outline,
                      color: Theme.of(ctx).colorScheme.error,
                    ),
                    title: Text(
                      '删除',
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                    subtitle: const Text('删除这一条，删除前确认'),
                    onTap: () {
                      Navigator.pop(ctx);
                      onDelete();
                    },
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.visibility_off_outlined),
                    title: const Text('移出列表'),
                    subtitle: const Text('仅本地隐藏；悬浮球删除不会带上它们'),
                    onTap: () {
                      Navigator.pop(ctx);
                      onHide();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
