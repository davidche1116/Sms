import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../generated/app_localizations.dart';
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
      final l10n = AppLocalizations.of(ctx);
      void toast(String msg) {
        ScaffoldMessenger.of(ctx)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
          );
      }

      return SafeArea(
        top: false,
        child: SizedBox(
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
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                  children: [
                    ListTile(
                      dense: true,
                      title: Text(
                        e.address,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(l10n.simTime(e.sim, e.time)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.tag),
                      title: Text(l10n.sameAddressSms),
                      subtitle: Text(l10n.sameAddressHint),
                      onTap: () {
                        Navigator.pop(ctx);
                        onSameAddress(e.address);
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.sim_card_outlined),
                      title: Text(l10n.sameSimSms),
                      onTap: () {
                        Navigator.pop(ctx);
                        onSameSim(e.sim);
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.copy_outlined),
                      title: Text(l10n.copyAddress),
                      onTap: () {
                        Navigator.pop(ctx);
                        Clipboard.setData(ClipboardData(text: e.address));
                        toast(l10n.copiedAddress);
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.copy_all_outlined),
                      title: Text(l10n.copyBody),
                      onTap: () {
                        Navigator.pop(ctx);
                        Clipboard.setData(ClipboardData(text: e.body));
                        toast(l10n.copiedBody);
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.delete_outline,
                        color: Theme.of(ctx).colorScheme.error,
                      ),
                      title: Text(
                        l10n.delete,
                        style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                      ),
                      subtitle: Text(l10n.deleteOneHint),
                      onTap: () {
                        Navigator.pop(ctx);
                        onDelete();
                      },
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.visibility_off_outlined),
                      title: Text(l10n.hideFromList),
                      subtitle: Text(l10n.hideFromListHint),
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
        ),
      );
    },
  );
}
