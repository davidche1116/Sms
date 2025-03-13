// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get title => '短信清理';

  @override
  String get toast_default => '需要在系统设置中将本应用设置为默认短信应用才能删除短信';

  @override
  String get toast_permission => '需要申请短信权限或设置为短信默认应用';

  @override
  String get keyword => '关键字';

  @override
  String get b_confirm => '确定';

  @override
  String get t_confirm_delete => '确认删除';

  @override
  String delete_num(String num) {
    return '是否删除这$num条短信？';
  }

  @override
  String get b_cancel => '取消';

  @override
  String get operation_failed => '操作失败';

  @override
  String get operation_completed => '操作成功';

  @override
  String get toast_no => '没有短信可分享';

  @override
  String get sms_list => '短信列表';

  @override
  String get toast_share => '分享成功，需用utf-8格式打开';

  @override
  String get tips => '提示';

  @override
  String get delete_or_move => '是否要删除或移出当前项？';

  @override
  String get b_remove => '移出列表';

  @override
  String get b_delete => '直接删除';

  @override
  String get b_same_number => '同号短信';

  @override
  String get toast_clipboard => '已复制到剪切板';

  @override
  String get b_copy => '复制';

  @override
  String get sms => '短信';

  @override
  String num_sms(String num) {
    return '$num条短信';
  }

  @override
  String get t_all_sms => '所有短信列表';

  @override
  String get t_keyword_filter => '关键字过滤';

  @override
  String get set_permission => '申请短信权限';

  @override
  String get set_settings => '应用权限设置';

  @override
  String get set_default => '设置默认短信应用';

  @override
  String get set_restore => '恢复默认短信应用';

  @override
  String get set_export => '导出csv并分享';

  @override
  String get t_wait => '请稍等';

  @override
  String get t_no_sms => '没有短信';

  @override
  String get b_remove_filter => '移除过滤条件';

  @override
  String get t_delete_all => '删除当前列表所有短信';

  @override
  String get sim => '卡';

  @override
  String get t_list_too_long => '列表太多了，可能需要久一点';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get title => '簡訊清理';

  @override
  String get toast_default => '需要在系統設定中將本應用程式設定為預設簡訊應用程式才能刪除簡訊';

  @override
  String get toast_permission => '需要申請簡訊權限或設定為預設簡訊應用程式';

  @override
  String get keyword => '關鍵字';

  @override
  String get b_confirm => '確定';

  @override
  String get t_confirm_delete => '確認刪除';

  @override
  String delete_num(String num) {
    return '是否刪除這$num則簡訊？';
  }

  @override
  String get b_cancel => '取消';

  @override
  String get operation_failed => '操作失敗';

  @override
  String get operation_completed => '操作成功';

  @override
  String get toast_no => '沒有簡訊可分享';

  @override
  String get sms_list => '簡訊清單';

  @override
  String get toast_share => '分享成功，請使用utf-8格式開啟';

  @override
  String get tips => '提示';

  @override
  String get delete_or_move => '是否要刪除或移出目前項目？';

  @override
  String get b_remove => '移出清單';

  @override
  String get b_delete => '直接刪除';

  @override
  String get b_same_number => '相同號碼簡訊';

  @override
  String get toast_clipboard => '已複製到剪貼簿';

  @override
  String get b_copy => '複製';

  @override
  String get sms => '簡訊';

  @override
  String num_sms(String num) {
    return '$num則簡訊';
  }

  @override
  String get t_all_sms => '所有簡訊清單';

  @override
  String get t_keyword_filter => '關鍵字篩選';

  @override
  String get set_permission => '申請簡訊權限';

  @override
  String get set_settings => '應用程式權限設定';

  @override
  String get set_default => '設定為預設簡訊應用程式';

  @override
  String get set_restore => '還原預設簡訊應用程式';

  @override
  String get set_export => '匯出csv並分享';

  @override
  String get t_wait => '請稍候';

  @override
  String get t_no_sms => '沒有簡訊';

  @override
  String get b_remove_filter => '移除篩選條件';

  @override
  String get t_delete_all => '刪除目前清單中的所有簡訊';

  @override
  String get sim => '卡';

  @override
  String get t_list_too_long => '清單較長，可能需要較多時間';
}
