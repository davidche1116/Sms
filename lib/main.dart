import 'package:flutter/material.dart';

import 'home_page.dart';

void main() => runApp(const SmsApp());

class SmsApp extends StatefulWidget {
  const SmsApp({super.key});

  @override
  State<SmsApp> createState() => _SmsAppState();
}

class _SmsAppState extends State<SmsApp> {
  Color seed = const Color(0xFF2BAE67);
  ThemeMode mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '短信清理',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: _theme(Brightness.light, seed),
      darkTheme: _theme(Brightness.dark, seed),
      home: HomePage(
        seed: seed,
        mode: mode,
        onThemeChanged: (c, m) => setState(() {
          if (c != null) seed = c;
          if (m != null) mode = m;
        }),
      ),
    );
  }

  ThemeData _theme(Brightness b, Color seed) {
    // fromSeed 会推导出另一套 primary，和色盘上的色块不一致。
    // 这里强制 primary = 用户所选颜色，保证「预设绿」和标题栏颜色相同。
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b)
        .copyWith(
          primary: seed,
          onPrimary: b == Brightness.light ? Colors.white : Colors.black,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: const EdgeInsets.only(bottom: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: scheme.surfaceContainerLow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// 主题色预设。
const kSeedPresets = <(String, Color)>[
  ('绿', Color(0xFF2BAE67)),
  ('蓝', Color(0xFF2B7FE7)),
  ('紫', Color(0xFF7B61FF)),
  ('橙', Color(0xFFE67E22)),
  ('红', Color(0xFFE74C3C)),
  ('青', Color(0xFF00BCD4)),
  ('粉', Color(0xFFEC407A)),
  ('石墨', Color(0xFF546E7A)),
];

/// 演示用短信。
class SmsItem {
  SmsItem({
    required this.body,
    required this.address,
    required this.time,
    required this.dayLabel,
    required this.sim,
    this.id,
    this.threadId,
  });

  final String body;
  final String address;
  final String time;
  final String dayLabel;
  final int sim;
  final int? id;
  final int? threadId;
}

final kDemoSms = <SmsItem>[
  SmsItem(
    body: '【嘿哈猫健身】亲爱的会员，您购买的嘿哈猫会员服务已于2026-09-26 11:02:24开通。',
    address: '1069452226612058152',
    time: '11:02',
    dayLabel: '今天',
    sim: 1,
  ),
  SmsItem(
    body: '【流量提醒】尊敬的5G用户，截至09月25日24时，当月共享国内通用流量已用47.552GB，剩余72.448GB。',
    address: '10010',
    time: '11:02',
    dayLabel: '今天',
    sim: 2,
  ),
  SmsItem(
    body: '您的借记卡账户8309，于09月25日网上支付支取人民币270.34元，交易后余额9420.35。',
    address: '95566',
    time: '09:39',
    dayLabel: '今天',
    sim: 1,
  ),
  SmsItem(
    body: '【湖南住房公积金】尊敬的车阳，您账户2026年09月24日汇缴220元，余额为3198.33元。',
    address: '12329',
    time: '17:37',
    dayLabel: '昨天',
    sim: 1,
  ),
  SmsItem(
    body: '车阳同志：您于2026年08月16日申请的社保关系终止业务，已审核通过，请继续关注待遇核定情况。',
    address: '106509768010914',
    time: '15:06',
    dayLabel: '昨天',
    sim: 2,
  ),
  SmsItem(
    body: '验证码 884215，您正在登录微信。请勿转发给他人。',
    address: '10690',
    time: '09:12',
    dayLabel: '昨天',
    sim: 1,
  ),
];
