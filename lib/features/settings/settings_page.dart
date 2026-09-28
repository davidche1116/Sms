import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../generated/app_localizations.dart';
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
    this.locale,
    this.onLocaleChanged,
    required this.repo,
    required this.hiddenStore,
    this.onDataChanged,
  });

  final Color seed;
  final ThemeMode mode;
  final void Function(Color? seed, ThemeMode? mode) onThemeChanged;

  /// 当前界面语言；null = 跟随系统。
  final Locale? locale;
  final void Function(Locale? locale)? onLocaleChanged;
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
  bool _importing = false;
  String _version = '2.0.0';

  /// 当前界面语言（跟随本次选择即时刷新；widget.locale 只是初值）。
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.locale;
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
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_isDefault == true) {
      final go = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          final sheetL10n = AppLocalizations.of(ctx);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(sheetL10n.alreadyDefaultSms),
                  subtitle: Text(sheetL10n.deleteAvailable),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_backup_restore),
                  title: Text(sheetL10n.restoreSystemSms),
                  subtitle: Text(sheetL10n.restoreSystemSmsHint),
                  onTap: () => Navigator.pop(ctx, true),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(sheetL10n.keepAsIs),
                ),
              ],
            ),
          );
        },
      );
      if (go != true) return;
      final r = await widget.repo.restoreDefaultSms();
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(switch (r) {
              RestoreDefaultResult.openedSettings =>
                l10n.openedDefaultSettingsPickOther,
              RestoreDefaultResult.notDefault => l10n.notDefaultNow,
              RestoreDefaultResult.error => l10n.openSettingsFailed,
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
              DefaultSmsResult.alreadyDefault => l10n.alreadyDefaultSms,
              DefaultSmsResult.requested => l10n.confirmSetDefaultInDialog,
              DefaultSmsResult.timeout => l10n.systemNoResult,
              DefaultSmsResult.error => l10n.openedDefaultSettings,
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
    final l10n = AppLocalizations.of(context);
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
          content: Text(ok ? l10n.autoRepairReady : l10n.autoRepairIncomplete),
        ),
      );
  }

  /// 导出全部短信 CSV（查库 → 写文件 → 分享）。
  Future<void> _exportAll() async {
    if (_exporting || _importing) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _exporting = true);
    try {
      final msg = await exportAll(widget.repo, l10n);
      if (mounted && msg != null) _toast(msg);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// 导入 CSV：只新增写入系统短信库。
  Future<void> _importCsv() async {
    if (_exporting || _importing) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _importing = true);
    try {
      final r = await importCsv(widget.repo);
      if (!mounted) return;
      _toast(importMessage(r, l10n));
      if (r.ok) await widget.onDataChanged?.call();
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// 清空本地隐藏列表，被移出的短信重新显示。
  Future<void> _resetHidden() async {
    final l10n = AppLocalizations.of(context);
    await widget.hiddenStore.clear();
    await _refreshHiddenCount();
    await widget.onDataChanged?.call();
    if (!mounted) return;
    _toast(l10n.hiddenListReset);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _section(context, l10n.sectionAppearance),
          _group([
            _row(
              icon: Icons.palette_outlined,
              iconBg: scheme.primary,
              title: l10n.themeColor,
              value: _seedName(l10n, widget.seed),
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
              title: l10n.darkMode,
              value: switch (widget.mode) {
                ThemeMode.system => l10n.themeSystem,
                ThemeMode.light => l10n.themeLight,
                ThemeMode.dark => l10n.themeDark,
              },
              onTap: () => _pickMode(context),
            ),
            _row(
              icon: Icons.language_outlined,
              iconBg: const Color(0xFF26A69A),
              title: l10n.language,
              value: _localeName(l10n, _locale),
              onTap: () => _pickLocale(context),
            ),
          ]),
          _section(context, l10n.sectionPermissions),
          _group([
            _row(
              icon: Icons.lock_outline,
              iconBg: const Color(0xFFE6A23C),
              title: l10n.smsPermission,
              subtitle: _hasRead == true
                  ? l10n.smsPermissionGranted
                  : _hasRead == false
                  ? l10n.smsPermissionDenied
                  : l10n.checking,
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
              title: l10n.defaultSmsApp,
              subtitle: _isDefault == true
                  ? l10n.defaultSmsIsThisApp
                  : _isDefault == false
                  ? l10n.defaultSmsNotThisApp
                  : l10n.checking,
              trailing: Icon(
                _isDefault == true
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: _isDefault == true ? scheme.primary : scheme.outline,
                size: 20,
              ),
              onTap: _onDefaultSmsRow,
            ),
            // 已是默认时明示彩信接收限制（P0-2），避免用户以为彩信完整入库
            if (_isDefault == true)
              _warnRow(
                context,
                icon: Icons.warning_amber_rounded,
                title: l10n.defaultSmsMmsWarnTitle,
                subtitle: l10n.defaultSmsMmsWarnBody,
              ),
            _row(
              icon: Icons.build_outlined,
              iconBg: const Color(0xFF42A5F5),
              title: l10n.autoRepair,
              subtitle: l10n.autoRepairHint,
              onTap: _autoRepair,
            ),
          ]),
          _section(context, l10n.sectionData),
          _group([
            _row(
              icon: Icons.ios_share,
              iconBg: const Color(0xFF42A5F5),
              title: l10n.exportSmsCsv,
              subtitle: _exporting ? l10n.exporting : l10n.exportSmsHint,
              onTap: (_exporting || _importing) ? null : _exportAll,
            ),
            _row(
              icon: Icons.upload_file_outlined,
              iconBg: const Color(0xFF66BB6A),
              title: l10n.importSmsCsv,
              subtitle: _importing ? l10n.importing : l10n.importSmsHint,
              onTap: (_exporting || _importing) ? null : _importCsv,
            ),
            _row(
              icon: Icons.visibility_off_outlined,
              iconBg: const Color(0xFF8D6E63),
              title: l10n.resetHiddenList,
              subtitle: _hiddenCount == 0
                  ? l10n.noHidden
                  : l10n.hiddenCountLabel(_hiddenCount),
              onTap: _hiddenCount == 0 ? null : _resetHidden,
            ),
          ]),
          _section(context, l10n.sectionAbout),
          _group([
            _row(
              icon: Icons.info_outline,
              iconBg: const Color(0xFF8D6E63),
              title: l10n.version,
              value: _version,
            ),
            _row(
              icon: Icons.privacy_tip_outlined,
              iconBg: const Color(0xFF7E57C2),
              title: l10n.privacy,
              subtitle: l10n.privacyHint,
              onTap: () => _showPrivacyDialog(context),
            ),
            _row(
              icon: Icons.gavel_outlined,
              iconBg: const Color(0xFF5C6BC0),
              title: l10n.openSourceLicenses,
              subtitle: l10n.openSourceLicensesHint,
              onTap: () => showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
                applicationVersion: _version,
              ),
            ),
            _row(
              icon: Icons.feedback_outlined,
              iconBg: const Color(0xFFEF5350),
              title: l10n.feedback,
              subtitle: l10n.feedbackHint,
              onTap: _openFeedback,
            ),
            _warnRow(
              context,
              icon: Icons.perm_phone_msg_outlined,
              title: l10n.aboutMmsReceiveTitle,
              subtitle: l10n.aboutMmsReceiveBody,
            ),
          ]),
          const SizedBox(height: 24),
          Center(
            child: Text(
              l10n.footerTagline,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _seedName(AppLocalizations l10n, Color c) {
    final argb = c.toARGB32();
    for (final p in kSeedPresets) {
      if (p.$2.toARGB32() == argb) return seedDisplayName(l10n, p.$1);
    }
    return '#${argb.toRadixString(16).substring(2).toUpperCase()}';
  }

  Future<void> _pickMode(BuildContext context) async {
    final m = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final sheetL10n = AppLocalizations.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, value) in [
                (sheetL10n.themeSystem, ThemeMode.system),
                (sheetL10n.themeLight, ThemeMode.light),
                (sheetL10n.themeDark, ThemeMode.dark),
              ])
                ListTile(
                  title: Text(label),
                  trailing: widget.mode == value ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(ctx, value),
                ),
            ],
          ),
        );
      },
    );
    if (m != null) widget.onThemeChanged(null, m);
  }

  String _localeName(AppLocalizations l10n, Locale? locale) {
    if (locale == null) return l10n.languageSystem;
    if (locale.languageCode == 'zh' && locale.countryCode == 'TW') {
      return l10n.languageZhTw;
    }
    return switch (locale.languageCode) {
      'zh' => l10n.languageZh,
      'en' => l10n.languageEn,
      _ => locale.toLanguageTag(),
    };
  }

  Future<void> _pickLocale(BuildContext context) async {
    final result = await showModalBottomSheet<(bool, Locale?)>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final sheetL10n = AppLocalizations.of(ctx);
        final current = _locale;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, value) in [
                (sheetL10n.languageSystem, null),
                (sheetL10n.languageZh, const Locale('zh')),
                (sheetL10n.languageZhTw, const Locale('zh', 'TW')),
                (sheetL10n.languageEn, const Locale('en')),
              ])
                ListTile(
                  title: Text(label),
                  trailing: current == value ? const Icon(Icons.check) : null,
                  // 用 (true, value) 区分「点了跟随系统」与「点外部取消」。
                  onTap: () => Navigator.pop(ctx, (true, value)),
                ),
            ],
          ),
        );
      },
    );
    if (result?.$1 != true) return;
    setState(() => _locale = result!.$2);
    widget.onLocaleChanged?.call(result!.$2);
  }

  void _showPrivacyDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.privacyDialogTitle),
        content: Text(l10n.privacyDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.done),
          ),
        ],
      ),
    );
  }

  Future<void> _openFeedback() async {
    final l10n = AppLocalizations.of(context);
    final uri = Uri.parse('https://github.com/davidche1116/Sms/issues');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _toast(l10n.feedbackOpenFailed);
    } catch (_) {
      if (mounted) _toast(l10n.feedbackOpenFailed);
    }
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

  /// 警告行：不截断副文，多行完整展示。
  Widget _warnRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: scheme.onErrorContainer, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: scheme.onErrorContainer,
        ),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: scheme.error)),
      trailing: const SizedBox.shrink(),
    );
  }
}
