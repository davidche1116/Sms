import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 与 Kotlin `SmsApp` 同名的 MethodChannel，所有通道 mock 共用。
const appChannel = MethodChannel('com.dc16.sms/smsApp');

/// 装/卸 mock handler（测试 tearDown 必须清掉，避免泄漏到下一用例）。
void setAppChannelHandler(Future<Object?> Function(MethodCall call)? handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(appChannel, handler);
}

void clearAppChannelHandler() => setAppChannelHandler(null);
