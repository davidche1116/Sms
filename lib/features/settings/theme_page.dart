import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 主题色选择页：预设 8 色 + 自定义 hex + 实时换肤（UI_DESIGN §6.5）。
class ThemePage extends StatefulWidget {
  const ThemePage({super.key, required this.seed, required this.onPick});

  final Color seed;
  final ValueChanged<Color> onPick;

  @override
  State<ThemePage> createState() => _ThemePageState();
}

class _ThemePageState extends State<ThemePage> {
  late Color _color;
  late final TextEditingController _hex;

  @override
  void initState() {
    super.initState();
    _color = widget.seed;
    _hex = TextEditingController(text: _toHex(_color));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  String _toHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

  void _set(Color c) {
    setState(() {
      _color = c;
      _hex.text = _toHex(c);
    });
    widget.onPick(c);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('主题色')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            '选择强调色，立即作用于主按钮、选中项与图标。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text('预设', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final (name, color) in kSeedPresets)
                _swatch(name, color, color.toARGB32() == _color.toARGB32()),
            ],
          ),
          const SizedBox(height: 24),
          Text('自定义', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _hex,
                          decoration: const InputDecoration(
                            labelText: '颜色值',
                            hintText: '#2BAE67',
                          ),
                          onChanged: (v) {
                            final c = _parseHex(v);
                            if (c != null) {
                              setState(() => _color = c);
                              widget.onPick(c);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      final c = _parseHex(_hex.text);
                      if (c == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请输入合法颜色值，如 #2BAE67')),
                        );
                        return;
                      }
                      _set(c);
                    },
                    child: const Text('应用自定义颜色'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('预览', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(onPressed: () {}, child: const Text('主按钮示例')),
                  const SizedBox(height: 12),
                  const Wrap(
                    spacing: 8,
                    children: [
                      Chip(label: Text('筛选 Chip')),
                      Chip(label: Text('同号 10086')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _swatch(String name, Color color, bool selected) {
    return Tooltip(
      message: name,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _set(color),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }

  Color? _parseHex(String v) {
    var s = v.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 3) {
      s = s.split('').map((c) => '$c$c').join();
    }
    if (s.length != 6) return null;
    final n = int.tryParse(s, radix: 16);
    if (n == null) return null;
    return Color(0xFF000000 | n);
  }
}
