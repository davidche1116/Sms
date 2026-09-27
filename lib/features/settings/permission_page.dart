import 'package:flutter/material.dart';

import '../../services/sms_repository.dart';
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
  String _miuiNotif = 'unknown';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final r = await widget.repo.hasReadSmsPermission();
    final d = await widget.repo.isDefaultSms();
    final miui = await widget.repo.isMiui();
    final notif = miui
        ? await widget.repo.miuiNotificationSmsState()
        : 'unknown';
    if (!mounted) return;
    setState(() {
      _hasRead = r;
      _isDefault = d;
      _isMiui = miui;
      _miuiNotif = notif;
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
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
    final r = await widget.repo.setDefaultSms();
    await _refresh();
    if (!mounted) return;
    if (r == 'had') {
      _toast('已是默认短信应用');
    } else if (r == 'no') {
      _toast('请在系统弹窗中点「设为默认应用」');
    } else {
      await widget.repo.openDefaultSmsSettings();
    }
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('短信权限'),
        actions: [
          IconButton(
            tooltip: '刷新状态',
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
                  title: const Text('读取短信'),
                  subtitle: Text(
                    _hasRead == true
                        ? '已授予 · AppOps 正常'
                        : _hasRead == false
                        ? '未授予 · 无法读取短信列表'
                        : '检查中…',
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
                  title: const Text('默认短信应用'),
                  subtitle: Text(
                    _isDefault == true
                        ? '本应用 · 删除功能可用'
                        : _isDefault == false
                        ? '非本应用 · 删除短信需要设为默认'
                        : '检查中…',
                  ),
                ),
                if (_isMiui) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      _miuiNotif == 'allow'
                          ? Icons.check_circle
                          : Icons.warning_amber_outlined,
                      color: _miuiNotif == 'allow'
                          ? scheme.primary
                          : const Color(0xFFE6A23C),
                    ),
                    title: const Text('MIUI 通知类短信'),
                    subtitle: Text(
                      switch (_miuiNotif) {
                        'allow' => '已允许 · 通知类短信可见',
                        'likely_off' => '可能未开通 · 10086 等可能读不到',
                        'deny' || 'ignore' => '未开通 · 只能读到点对点短信',
                        _ => 'MIUI 附加权限 · 建议开通',
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isMiui
                ? '读取与删除相互独立：读列表只需短信权限；删除必须是默认短信应用。'
                    'MIUI 额外有「通知类短信」开关，不开通时 10086/银行等通知类会读不到。'
                    '在系统中改掉默认短信后，系统可能同时收回读权限，回到本页重新申请即可。'
                : '读取与删除相互独立：读列表只需短信权限；删除必须是默认短信应用。'
                    '在系统中改掉默认短信后，系统可能同时收回读权限，回到本页重新申请即可。',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          if (_hasRead != true) ...[
            FilledButton(
              onPressed: _busy ? null : _requestRead,
              child: const Text('申请短信权限'),
            ),
            const SizedBox(height: 12),
          ],
          if (_isDefault != true) ...[
            FilledButton.tonal(
              onPressed: _busy ? null : _setDefault,
              child: const Text('设为默认短信应用'),
            ),
            const SizedBox(height: 12),
          ],
          if (_isMiui) ...[
            FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      final action = await showMiuiNotificationSmsSheet(context);
                      if (action == 'open_miui') {
                        final ok = await widget.repo.openMiuiPermissionEditor();
                        if (!ok && mounted) _toast('打开 MIUI 权限页失败');
                      }
                    }),
              child: const Text('开启 MIUI 通知类短信'),
            ),
            const SizedBox(height: 12),
            Text(
              '路径：应用信息 → 权限管理 → 其他权限 → 通知类短信',
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
                    if (!ok && mounted) _toast('打开应用设置失败');
                  }),
            child: const Text('打开应用设置'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final ok = await widget.repo.openDefaultSmsSettings();
                    if (!ok && mounted) _toast('打开默认应用设置失败');
                  }),
            child: const Text('打开系统默认应用设置'),
          ),
        ],
      ),
    );
  }
}
