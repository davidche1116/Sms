// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get title => 'SMS Cleanup';

  @override
  String get toast_default =>
      'To delete SMS messages, please set this app as the default SMS app in System Settings';

  @override
  String get toast_permission =>
      'SMS permission required or set as default SMS app';

  @override
  String get keyword => 'Keyword';

  @override
  String get b_confirm => 'Confirm';

  @override
  String get t_confirm_delete => 'Confirm Deletion';

  @override
  String delete_num(String num) {
    return 'Delete $num message(s)?';
  }

  @override
  String get b_cancel => 'Cancel';

  @override
  String get operation_failed => 'Operation Failed';

  @override
  String get operation_completed => 'Operation Completed';

  @override
  String get toast_no => 'No messages to share';

  @override
  String get sms_list => 'Message List';

  @override
  String get toast_share =>
      'Shared successfully. Please open with UTF-8 encoding';

  @override
  String get tips => 'Tips';

  @override
  String get delete_or_move => 'Delete or remove this item?';

  @override
  String get b_remove => 'Remove from List';

  @override
  String get b_delete => 'Delete';

  @override
  String get b_same_number => 'Messages from Same Number';

  @override
  String get b_same_sim => 'Messages from Same SIM';

  @override
  String get toast_clipboard => 'Copied to clipboard';

  @override
  String get b_copy => 'Copy';

  @override
  String get sms => 'SMS';

  @override
  String num_sms(String num) {
    return '$num message(s)';
  }

  @override
  String get t_all_sms => 'All Messages';

  @override
  String get t_keyword_filter => 'Filter by Keyword';

  @override
  String get set_permission => 'Request SMS Permission';

  @override
  String get set_settings => 'App Settings';

  @override
  String get set_default => 'Set as Default SMS App';

  @override
  String get set_restore => 'Restore Default SMS App';

  @override
  String get set_export => 'Export as CSV';

  @override
  String get t_wait => 'Please wait';

  @override
  String get t_no_sms => 'No messages';

  @override
  String get b_remove_filter => 'Clear Filter';

  @override
  String get t_delete_all => 'Delete All Messages in Current List';

  @override
  String get sim => 'SIM';

  @override
  String get t_list_too_long => 'Large list, may take longer to process';
}
