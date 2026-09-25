import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_advanced/sms_advanced.dart';

import '../l10n/generated/app_localizations.dart';
import '../utils/date_format.dart';

/// 短信列表项卡片。从 main.dart 的 _buildItem 抽出，行为不变：
/// 渲染一条短信并提供删除/移至回收站/同卡/同号/复制等交互，
/// 具体动作通过回调交回页面 State 执行。
class MessageItem extends StatelessWidget {
  const MessageItem({
    super.key,
    required this.index,
    required this.item,
    required this.animation,
    this.interactive = true,
    required this.appLocalizations,
    required this.onDelete,
    required this.onRemove,
    required this.onSameAddress,
    required this.onSameSim,
    required this.onShowToast,
  });

  final int index;
  final SmsMessage item;
  final Animation<double> animation;
  final bool interactive;
  final AppLocalizations appLocalizations;
  final void Function(int) onDelete;
  final void Function(int) onRemove;
  final void Function(int) onSameAddress;
  final void Function(int) onSameSim;
  final void Function(String) onShowToast;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position:
          Tween<Offset>(
            begin: const Offset(1, 0),
            end: const Offset(0, 0),
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeInBack,
              reverseCurve: Curves.easeInOutBack,
            ),
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            minVerticalPadding: 8,
            minLeadingWidth: 4,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(item.body ?? ''), const SizedBox(height: 5)],
            ),
            subtitle: Row(
              spacing: 10,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${appLocalizations.sim}${item.sim ?? '-'}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    item.sender ?? '',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  // date 可为 null（草稿/彩信）。旧实现对 "null" 直接
                  // substring(0, 19) 会抛 RangeError，这里统一走空安全格式化。
                  formatSmsDate(item.date),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                ),
              ],
            ),
            onTap: interactive
                ? () {
                    showCupertinoModalPopup(
                      context: context,
                      builder: (context) {
                        return CupertinoActionSheet(
                          title: Text(appLocalizations.tips),
                          message: Text(appLocalizations.delete_or_move),
                          actions: <Widget>[
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.of(context).pop('remove');
                                onRemove(index);
                              },
                              child: Text(appLocalizations.b_remove),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.of(context).pop('delete');
                                onDelete(index);
                              },
                              isDestructiveAction: true,
                              isDefaultAction: true,
                              child: Text(appLocalizations.b_delete),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.of(context).pop('same');
                                onSameAddress(index);
                              },
                              child: Text(appLocalizations.b_same_number),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.of(context).pop('sim');
                                onSameSim(index);
                              },
                              child: Text(appLocalizations.b_same_sim),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.of(context).pop('copy');
                                Clipboard.setData(
                                  ClipboardData(
                                    // 用创建弹窗时捕获的 item，不按 index 回查实时列表
                                    //（列表刷新/移除后 index 可能指向别条甚至越界）。
                                    text: buildSmsClipboardText(
                                      address: item.address,
                                      date: item.date,
                                      body: item.body,
                                    ),
                                  ),
                                );
                                onShowToast(appLocalizations.toast_clipboard);
                              },
                              child: Text(appLocalizations.b_copy),
                            ),
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            child: Text(appLocalizations.b_cancel),
                            onPressed: () {
                              Navigator.of(context).pop('cancel');
                            },
                          ),
                        );
                      },
                    );
                  }
                : null,
            onLongPress: interactive
                ? () {
                    showCupertinoModalPopup(
                      context: context,
                      builder: (context) {
                        return CupertinoActionSheet(
                          title: Padding(
                            padding: const EdgeInsets.all(20),
                            child: SelectableText(
                              item.body ?? '',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          actions: [
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.of(context).pop('copy');
                                Clipboard.setData(
                                  ClipboardData(text: '${item.address}'),
                                );
                                onShowToast(appLocalizations.toast_clipboard);
                              },
                              child: Text(item.address ?? ''),
                            ),
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            child: Text(appLocalizations.b_cancel),
                            onPressed: () {
                              Navigator.of(context).pop('cancel');
                            },
                          ),
                        );
                      },
                    );
                  }
                : null,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Divider(),
          ),
        ],
      ),
    );
  }
}
