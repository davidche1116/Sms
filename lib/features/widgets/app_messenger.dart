import 'package:flutter/material.dart';

/// 统一的 SnackBar 工具，标准时长 2 秒。
class AppMessenger {
  AppMessenger._();

  static void show(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration ?? const Duration(seconds: 2),
        ),
      );
  }
}
