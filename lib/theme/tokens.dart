import 'package:flutter/material.dart';

import '../generated/app_localizations.dart';

/// 主题色预设（UI_DESIGN §6.5：8 色圆点）。name 为 l10n 键后缀。
const kSeedPresets = <(String, Color)>[
  ('Green', Color(0xFF2BAE67)),
  ('Blue', Color(0xFF2B7FE7)),
  ('Purple', Color(0xFF7B61FF)),
  ('Orange', Color(0xFFE67E22)),
  ('Red', Color(0xFFE74C3C)),
  ('Cyan', Color(0xFF00BCD4)),
  ('Pink', Color(0xFFEC407A)),
  ('Graphite', Color(0xFF546E7A)),
];

/// 预设色展示名（跟随当前 locale）。
String seedDisplayName(AppLocalizations l10n, String key) {
  return switch (key) {
    'Green' => l10n.seedGreen,
    'Blue' => l10n.seedBlue,
    'Purple' => l10n.seedPurple,
    'Orange' => l10n.seedOrange,
    'Red' => l10n.seedRed,
    'Cyan' => l10n.seedCyan,
    'Pink' => l10n.seedPink,
    'Graphite' => l10n.seedGraphite,
    _ => key,
  };
}
