// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get title => 'Message Cleanup';

  @override
  String get toast_default =>
      'To delete SMS messages, you need to set this application as the default SMS application in system Settings';

  @override
  String get toast_permission =>
      'You need to apply for SMS permission or set it as the default SMS app';

  @override
  String get keyword => 'Keyword';

  @override
  String get b_confirm => 'Confirm';

  @override
  String get t_confirm_delete => 'Confirm Delete';

  @override
  String delete_num(String num) {
    return 'Do you want to delete $num SMS?';
  }

  @override
  String get b_cancel => 'Cancel';

  @override
  String get operation_failed => 'Operation Failed';

  @override
  String get operation_completed => 'Operation Completed';

  @override
  String get toast_no => 'No SMS to share';

  @override
  String get sms_list => 'SMS list';

  @override
  String get toast_share =>
      'The sharing is successful and must be opened in utf-8 format';

  @override
  String get tips => 'TIPS';

  @override
  String get delete_or_move =>
      'Do you want to delete or move the current item?';

  @override
  String get b_remove => 'Remove from list';

  @override
  String get b_delete => 'Delete';

  @override
  String get b_same_number => 'Same number';

  @override
  String get toast_clipboard => 'Copied to clipboard';

  @override
  String get b_copy => 'Copy';

  @override
  String get sms => 'SMS';

  @override
  String num_sms(String num) {
    return '$num SMS';
  }

  @override
  String get t_all_sms => 'List all of SMS';

  @override
  String get t_keyword_filter => 'Keyword filter';

  @override
  String get set_permission => 'Request SMS permission';

  @override
  String get set_settings => 'app settings';

  @override
  String get set_default => 'Set as the default SMS app';

  @override
  String get set_restore => 'Restore the default SMS app';

  @override
  String get set_export => 'Export csv and share';

  @override
  String get t_wait => 'Wait';

  @override
  String get t_no_sms => 'No SMS';

  @override
  String get b_remove_filter => 'Remove filter condition';

  @override
  String get t_delete_all => 'Delete all SMS from the current list';

  @override
  String get sim => 'sim';

  @override
  String get t_list_too_long => 'The list is too long and may take longer';
}
