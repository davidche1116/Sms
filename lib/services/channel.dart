/// MethodChannel 协议：常量、类型、解析函数。
///
/// 业务代码统一从本 barrel 导入；仅需要常量时可导入 `channel/channel_codes.dart`。
library;

export 'channel/channel_codes.dart';
export 'channel/wire_types.dart';
export 'channel/wire_parser.dart';
