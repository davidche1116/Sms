import 'package:flutter/material.dart';

import '../../services/sms_repository.dart';

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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final r = await widget.repo.hasReadSmsPermission();
    final d = await widget.repo.isDefaultSms();
    if (!mounted) return;
    setState(() {
      _hasRead = r;
      _isDefault = d;
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
    final ok = await widget.repo.requestReadSms();
    await _refresh();
    if (!mounted) return;
    _toast(ok ? '已可读取短信' : '仍未获得权限，可到系统设置开启');
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '读取与删除相互独立：读列表只需短信权限；删除必须是默认短信应用。'
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
