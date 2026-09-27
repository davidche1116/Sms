import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/hidden_store.dart';
import '../../services/sms_data_service.dart';
import '../../services/sms_repository.dart';
import '../../theme/tokens.dart';
import 'miui_notif_guide.dart';
import 'permission_page.dart';
import 'theme_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.seed,
    required this.mode,
    required this.onThemeChanged,
    required this.repo,
    required this.hiddenStore,
    this.onDataChanged,
  });

  final Color seed;
  final ThemeMode mode;
  final void Function(Color? seed, ThemeMode? mode) onThemeChanged;
  final SmsRepository repo;
  final HiddenStore hiddenStore;

  /// 权限 / 隐藏列表等数据发生变化后，通知首页重载。
  final Future<void> Function()? onDataChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool? _hasRead;
  bool? _isDefault;
  int _hiddenCount = 0;
  bool _exporting = false;
  String _version = '2.0.0';

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    _refreshHiddenCount();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = info.buildNumber.isEmpty
            ? info.version
            : '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      // 读取失败时保留 pubspec 回退值
    }
  }

  Future<void> _refreshStatus() async {
    final r = await widget.repo.hasReadSmsPermission();
    final d = await widget.repo.isDefaultSms();
    if (!mounted) return;
    setState(() {
      _hasRead = r;
      _isDefault = d;
    });
  }

  Future<void> _refreshHiddenCount() async {
    final ids = await widget.hiddenStore.load();
    if (!mounted) return;
    setState(() => _hiddenCount = ids.length);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 已是默认时：明确提供「去系统设置换回系统短信」。
  Future<void> _onDefaultSmsRow() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_isDefault == true) {
      final go = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('已是默认短信应用'),
                subtitle: Text('删除短信功能可用'),
              ),
              ListTile(
                leading: const Icon(Icons.settings_backup_restore),
                title: const Text('还原为系统短信'),
                subtitle: const Text('打开系统「默认应用」设置，手动选择「信息」'),
                onTap: () => Navigator.pop(ctx, true),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('保持现状'),
              ),
            ],
          ),
        ),
      );
      if (go != true) return;
      final r = await widget.repo.restoreDefaultSms();
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(switch (r) {
              RestoreDefaultResult.openedSettings =>
                '已打开系统默认应用设置，请选择其他短信应用',
              RestoreDefaultResult.notDefault => '当前不是默认短信应用',
              RestoreDefaultResult.error => '打开设置失败',
            }),
          ),
        );
    } else {
      final r = await widget.repo.setDefaultSms();
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(switch (r) {
              DefaultSmsResult.alreadyDefault => '已是默认短信应用',
              DefaultSmsResult.requested => '请在系统弹窗中点「设为默认应用」',
              DefaultSmsResult.timeout => '系统未返回结果，可在设置中手动开启',
              DefaultSmsResult.error => '已打开系统默认应用设置',
            }),
          ),
        );
      if (r == DefaultSmsResult.error) await widget.repo.openDefaultSmsSettings();
    }
    await _refreshStatus();
    await widget.onDataChanged?.call();
  }

  /// 一键检查并修复：缺读权限先申请（MIUI 自动跟通知类短信引导），非默认再拉起角色申请。
  Future<void> _autoRepair() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_hasRead != true) {
      await requestReadSmsWithMiuiGuide(context, widget.repo);
    } else if (await widget.repo.isMiui()) {
      final st = await widget.repo.miuiNotificationSmsState();
      if (st != MiuiNotifState.allow && mounted) {
        final action = await showMiuiNotificationSmsSheet(context);
        if (action == MiuiGuideAction.openMiui) {
          await widget.repo.openMiuiPermissionEditor();
        }
      }
    }
    if (await widget.repo.isDefaultSms() != true) {
      await widget.repo.setDefaultSms();
    }
    await _refreshStatus();
    await widget.onDataChanged?.call();
    if (!mounted) return;
    final ok = _hasRead == true && _isDefault == true;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(ok ? '已就绪：可读可删' : '仍有项目未就绪，请检查上方状态'),
        ),
      );
  }

  /// 导出全部短信 CSV（查库 → 写文件 → 分享）。
  Future<void> _exportAll() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final msg = await exportAll(widget.repo);
      if (mounted && msg != null) _toast(msg);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// 导入 CSV：只新增写入系统短信库。
  Future<void> _importCsv() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final r = await importCsv(widget.repo);
      if (!mounted) return;
      _toast(importMessage(r));
      if (r.ok) await widget.onDataChanged?.call();
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// 清空本地隐藏列表，被移出的短信重新显示。
  Future<void> _resetHidden() async {
    await widget.hiddenStore.clear();
    await _refreshHiddenCount();
    await widget.onDataChanged?.call();
    _toast('已重置本地隐藏列表');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _section(context, '外观'),
          _group([
            _row(
              icon: Icons.palette_outlined,
              iconBg: scheme.primary,
              title: '主题色',
              value: _seedName(widget.seed),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ThemePage(
                    seed: widget.seed,
                    onPick: (c) => widget.onThemeChanged(c, null),
                  ),
                ),
              ),
            ),
            _row(
              icon: Icons.dark_mode_outlined,
              iconBg: const Color(0xFF546E7A),
              title: '深色模式',
              value: switch (widget.mode) {
                ThemeMode.system => '跟随系统',
                ThemeMode.light => '浅色',
                ThemeMode.dark => '深色',
              },
              onTap: () => _pickMode(context),
            ),
          ]),
          _section(context, '权限'),
          _group([
            _row(
              icon: Icons.lock_outline,
              iconBg: const Color(0xFFE6A23C),
              title: '短信权限',
              subtitle: _hasRead == true
                  ? '已授予 · 用于读取与导出'
                  : _hasRead == false
                  ? '未授予 · 点击查看与申请'
                  : '检查中…',
              trailing: Icon(
                _hasRead == true
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: _hasRead == true ? scheme.primary : scheme.outline,
                size: 20,
              ),
              onTap: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => PermissionPage(repo: widget.repo),
                  ),
                );
                await _refreshStatus();
                await widget.onDataChanged?.call();
              },
            ),
            _row(
              icon: Icons.sms_outlined,
              iconBg: scheme.primary,
              title: '默认短信应用',
              subtitle: _isDefault == true
                  ? '本应用 · 点击可还原系统短信'
                  : _isDefault == false
                  ? '非本应用 · 点击设为默认（删除需要）'
                  : '检查中…',
              trailing: Icon(
                _isDefault == true
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: _isDefault == true ? scheme.primary : scheme.outline,
                size: 20,
              ),
              onTap: _onDefaultSmsRow,
            ),
            _row(
              icon: Icons.build_outlined,
              iconBg: const Color(0xFF42A5F5),
              title: '一键检查并修复',
              subtitle: '依次申请读权限、设为默认短信',
              onTap: _autoRepair,
            ),
          ]),
          _section(context, '数据'),
          _group([
            _row(
              icon: Icons.ios_share,
              iconBg: const Color(0xFF42A5F5),
              title: '导出短信 CSV',
              subtitle: _exporting ? '导出中…' : '导出全部短信到文件并分享',
              onTap: _exporting ? null : _exportAll,
            ),
            _row(
              icon: Icons.upload_file_outlined,
              iconBg: const Color(0xFF66BB6A),
              title: '导入短信 CSV',
              subtitle: _exporting ? '导入中…' : '只新增入库，需设为默认短信应用',
              onTap: _exporting ? null : _importCsv,
            ),
            _row(
              icon: Icons.visibility_off_outlined,
              iconBg: const Color(0xFF8D6E63),
              title: '重置本地隐藏列表',
              subtitle: _hiddenCount == 0
                  ? '暂无已移出的短信'
                  : '已移出 $_hiddenCount 条，重置后重新显示',
              onTap: _hiddenCount == 0 ? null : _resetHidden,
            ),
          ]),
          _section(context, '关于'),
          _group([
            _row(
              icon: Icons.info_outline,
              iconBg: const Color(0xFF8D6E63),
              title: '版本',
              value: _version,
            ),
            _row(
              icon: Icons.privacy_tip_outlined,
              iconBg: const Color(0xFF7E57C2),
              title: '隐私说明',
              subtitle: '数据仅在本机处理',
              onTap: () => _toast('数据仅在本机处理，不上传、不收集'),
            ),
          ]),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '短信清理 · 本地工具',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _seedName(Color c) {
    final argb = c.toARGB32();
    for (final p in kSeedPresets) {
      if (p.$2.toARGB32() == argb) return p.$1;
    }
    return '#${argb.toRadixString(16).substring(2).toUpperCase()}';
  }

  Future<void> _pickMode(BuildContext context) async {
    final m = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, value) in [
              ('跟随系统', ThemeMode.system),
              ('浅色', ThemeMode.light),
              ('深色', ThemeMode.dark),
            ])
              ListTile(
                title: Text(label),
                trailing: widget.mode == value ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, value),
              ),
          ],
        ),
      ),
    );
    if (m != null) widget.onThemeChanged(null, m);
  }

  Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _group(List<Widget> children) => Card(
    margin: EdgeInsets.zero,
    child: Column(children: children),
  );

  Widget _row({
    required IconData icon,
    required Color iconBg,
    required String title,
    String? subtitle,
    String? value,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing:
          trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null) Text(value),
              const Icon(Icons.chevron_right),
            ],
          ),
      onTap: onTap,
    );
  }
}
