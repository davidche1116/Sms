import 'dart:async';

import 'package:flutter/material.dart';

import '../../generated/app_localizations.dart';
import '../../services/sms_repository.dart';
import '../widgets/app_messenger.dart';
import 'miui_notif_guide.dart';

/// 权限子页：实时展示读权限 / 默认短信状态，提供申请与修复入口
/// （INTERACTION_DESIGN §6.3）。
class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key, required this.repo});

  final SmsRepository repo;

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> {
  bool? _hasRead;
  bool? _isDefault;
  bool _isMiui = false;
  MiuiNotifState _miuiNotif = MiuiNotifState.unknown;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final r = await widget.repo.hasReadSmsPermission();
    final d = await widget.repo.isDefaultSms();
    final miui = await widget.repo.isMiui();
    final notif = miui
        ? await widget.repo.miuiNotificationSmsState()
        : MiuiNotifState.unknown;
    if (!mounted) return;
    setState(() {
      _hasRead = r;
      _isDefault = d;
      _isMiui = miui;
      _miuiNotif = notif;
    });
  }

  void _toast(String msg) {
    AppMessenger.show(context, msg);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestRead() => _run(() async {
    await requestReadSmsWithMiuiGuide(
      context,
      widget.repo,
      onRefresh: _refresh,
    );
  });

  Future<void> _setDefault() => _run(() async {
    final l10n = AppLocalizations.of(context);
    final r = await widget.repo.setDefaultSms();
    await _refresh();
    if (!mounted) return;
    switch (r) {
      case DefaultSmsResult.alreadyDefault:
        _toast(l10n.alreadyDefaultSms);
      case DefaultSmsResult.requested:
        _toast(l10n.confirmSetDefaultInDialog);
      case DefaultSmsResult.timeout:
        _toast(l10n.systemNoResult);
      case DefaultSmsResult.error:
        await widget.repo.openDefaultSmsSettings();
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.smsPermission),
        actions: [
          IconButton(
            tooltip: l10n.refreshStatus,
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    _hasRead == true
                        ? Icons.check_circle
                        : Icons.warning_amber_outlined,
                    color: _hasRead == true
                        ? scheme.primary
                        : const Color(0xFFE6A23C),
                  ),
                  title: Text(l10n.readSms),
                  subtitle: Text(
                    _hasRead == true
                        ? l10n.readGrantedAppOps
                        : _hasRead == false
                        ? l10n.readDeniedList
                        : l10n.checking,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    _isDefault == true
                        ? Icons.check_circle
                        : Icons.warning_amber_outlined,
                    color: _isDefault == true
                        ? scheme.primary
                        : const Color(0xFFE6A23C),
                  ),
                  title: Text(l10n.defaultSmsApp),
                  subtitle: Text(
                    _isDefault == true
                        ? l10n.defaultSmsDeleteOk
                        : _isDefault == false
                        ? l10n.defaultSmsDeleteNeed
                        : l10n.checking,
                  ),
                ),
                if (_isMiui) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      _miuiNotif == MiuiNotifState.allow
                          ? Icons.check_circle
                          : Icons.warning_amber_outlined,
                      color: _miuiNotif == MiuiNotifState.allow
                          ? scheme.primary
                          : const Color(0xFFE6A23C),
                    ),
                    title: Text(l10n.miuiNotifSms),
                    subtitle: Text(switch (_miuiNotif) {
                      MiuiNotifState.allow => l10n.miuiNotifAllowed,
                      MiuiNotifState.likelyOff => l10n.miuiNotifLikelyOff,
                      MiuiNotifState.deny ||
                      MiuiNotifState.ignore => l10n.miuiNotifOff,
                      MiuiNotifState.unknown => l10n.miuiNotifSuggest,
                    }),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isMiui ? l10n.permExplainMiui : l10n.permExplain,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          if (_hasRead != true) ...[
            FilledButton(
              onPressed: _busy ? null : _requestRead,
              child: Text(l10n.requestSmsPermission),
            ),
            const SizedBox(height: 12),
          ],
          if (_isDefault != true) ...[
            FilledButton.tonal(
              onPressed: _busy ? null : _setDefault,
              child: Text(l10n.setDefaultSms),
            ),
            const SizedBox(height: 12),
          ],
          if (_isMiui) ...[
            FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      final action = await showMiuiNotificationSmsSheet(
                        context,
                      );
                      if (action == MiuiGuideAction.openMiui) {
                        final ok = await widget.repo.openMiuiPermissionEditor();
                        if (!ok && mounted) {
                          _toast(l10n.openMiuiPermFailed);
                        }
                      }
                    }),
              child: Text(l10n.openMiuiNotifSmsBtn),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.miuiPath,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final ok = await widget.repo.openAppSettings();
                    if (!ok && mounted) _toast(l10n.openAppSettingsFailed);
                  }),
            child: Text(l10n.openAppSettings),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final ok = await widget.repo.openDefaultSmsSettings();
                    if (!ok && mounted) _toast(l10n.openDefaultSettingsFailed);
                  }),
            child: Text(l10n.openDefaultSmsSettings),
          ),
        ],
      ),
    );
  }
}
