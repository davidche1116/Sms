import 'package:flutter/material.dart';

import 'app_messenger.dart';

/// 运行异步操作，带忙状态、错误处理和 toast 反馈。
///
/// 返回操作是否成功（未抛出异常）。
Future<bool> runAsyncAction({
  required BuildContext context,
  required String busyMessage,
  required String successMessage,
  required Future<void> Function() action,
  String? errorMessage,
  Duration toastDuration = const Duration(seconds: 2),
}) async {
  try {
    await action();
    if (!context.mounted) return true;
    AppMessenger.show(context, successMessage, duration: toastDuration);
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    AppMessenger.show(
      context,
      errorMessage ?? '操作失败：$e',
      duration: toastDuration,
    );
    return false;
  }
}
