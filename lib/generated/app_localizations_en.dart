// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SMS Cleaner';

  @override
  String get homeTitle => 'Messages';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String loadedPartial(int loaded, int total) {
    return '$loaded / $total loaded';
  }

  @override
  String loadedCount(int loaded) {
    return '$loaded loaded';
  }

  @override
  String messageCount(int count) {
    return '$count messages';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get searchFilter => 'Search / Filter';

  @override
  String get settings => 'Settings';

  @override
  String get more => 'More';

  @override
  String get exportSelected => 'Export selected';

  @override
  String get deleteSelected => 'Delete selected';

  @override
  String get queryFailedRetry => 'Query failed. Pull to refresh or tap retry.';

  @override
  String get deleteFailedNeedDefault =>
      'Delete failed: set this app as default SMS app first';

  @override
  String deletedCount(int count) {
    return 'Deleted $count';
  }

  @override
  String get alreadyDefaultSms => 'Already the default SMS app';

  @override
  String get confirmInSystemDialog => 'Confirm in the system dialog';

  @override
  String get confirmSetDefaultInDialog =>
      'Tap “Set as default” in the system dialog';

  @override
  String get systemNoResult =>
      'No result from the system. You can enable it in Settings.';

  @override
  String get removedFromList => 'Removed from list';

  @override
  String get nothingToDelete => 'Nothing to delete';

  @override
  String get needPermissionTitle => 'SMS permission required';

  @override
  String get noMatchTitle => 'No matching messages';

  @override
  String get emptyTitle => 'No messages';

  @override
  String get needPermissionBody =>
      'Grant SMS read permission to browse, search, and export. Deleting also requires setting this app as the default SMS app.';

  @override
  String get noMatchBody => 'Clear the filters and try again.';

  @override
  String get emptyBody => 'Pull down to reload.';

  @override
  String get requestSmsPermission => 'Request SMS permission';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get reload => 'Reload';

  @override
  String get setDefaultForDelete =>
      'Set as default SMS app (required for delete)';

  @override
  String get deleteSmsTitle => 'Delete messages?';

  @override
  String deleteSmsBody(int count) {
    return 'Delete $count message(s)? This cannot be undone.';
  }

  @override
  String get deleteLargeWarn =>
      'Large batch (>3000). Deletion may take longer.';

  @override
  String deleteProgress(int progress, int count) {
    return '$progress / $count done';
  }

  @override
  String deleteCannotUndo(int count) {
    return '$count deleted, cannot be undone';
  }

  @override
  String deletePartialFailed(int deleted, int total) {
    return 'Failed after deleting $deleted / $total';
  }

  @override
  String deleteCancelled(int count) {
    return 'Cancelled after deleting $count';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get stopDelete => 'Stop';

  @override
  String get stoppingDelete => 'Stopping…';

  @override
  String get deleting => 'Deleting…';

  @override
  String get confirmDelete => 'Delete';

  @override
  String get keywordLabel => 'Keyword';

  @override
  String get startDate => 'Start date';

  @override
  String get endDate => 'End date';

  @override
  String get typeLabel => 'Type';

  @override
  String get typeAll => 'All';

  @override
  String get typeInbox => 'Inbox only';

  @override
  String get typeSent => 'Sent only';

  @override
  String get typeMms => 'MMS only';

  @override
  String get mmsBadge => 'MMS';

  @override
  String get mmsHasAttachment => 'Attachment';

  @override
  String get mmsBodyPlaceholder => '[MMS]';

  @override
  String get mmsBodyWithAttachment => '[MMS] · attachment';

  @override
  String get reset => 'Reset';

  @override
  String get done => 'Done';

  @override
  String sameAddressChip(String address) {
    return 'Same number $address';
  }

  @override
  String sameSimChip(int sim) {
    return 'Same SIM $sim';
  }

  @override
  String keywordChip(String keyword) {
    return '“$keyword”';
  }

  @override
  String get clearAllFilters => 'Clear all';

  @override
  String get exportAllCsv => 'Export all CSV';

  @override
  String get importCsv => 'Import CSV';

  @override
  String get importCsvHint =>
      'Writes to the system SMS database (default app required)';

  @override
  String get multiSelect => 'Multi-select';

  @override
  String simTime(int sim, String time) {
    return 'SIM $sim · $time';
  }

  @override
  String simBadge(int sim) {
    return 'SIM $sim';
  }

  @override
  String get sameAddressSms => 'Messages from this number';

  @override
  String get sameAddressHint => 'Show all messages from this number';

  @override
  String get sameSimSms => 'Messages on this SIM';

  @override
  String get copyAddress => 'Copy number';

  @override
  String get copiedAddress => 'Number copied';

  @override
  String get copyBody => 'Copy text';

  @override
  String get copiedBody => 'Text copied';

  @override
  String get delete => 'Delete';

  @override
  String get deleteOneHint => 'Delete this message after confirmation';

  @override
  String get hideFromList => 'Hide from list';

  @override
  String get hideFromListHint =>
      'Hidden locally only; bulk delete won’t include them';

  @override
  String get miuiBanner =>
      'You may still miss notification SMS like 10086. Tap to enable MIUI “Notification SMS”.';

  @override
  String get dismissHint => 'Don’t show again';

  @override
  String get miuiGuideTitle => 'Also enable “Notification SMS”';

  @override
  String get miuiGuideBody =>
      'MIUI controls notification SMS (10086, banks, etc.) separately. On the next screen open: Permissions → Other permissions → Notification SMS.';

  @override
  String get openMiuiNotifSms => 'Enable notification SMS';

  @override
  String get later => 'Later';

  @override
  String get stillNoPermission =>
      'Still no permission. Enable it in system settings.';

  @override
  String get smsReadable => 'SMS is now readable';

  @override
  String get openMiuiPermFailed => 'Failed to open the MIUI permission page';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get themeColor => 'Theme color';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get sectionPermissions => 'Permissions';

  @override
  String get smsPermission => 'SMS permission';

  @override
  String get smsPermissionGranted => 'Granted · for reading and export';

  @override
  String get smsPermissionDenied => 'Not granted · tap to view and request';

  @override
  String get checking => 'Checking…';

  @override
  String get defaultSmsApp => 'Default SMS app';

  @override
  String get defaultSmsIsThisApp => 'This app · tap to restore system SMS';

  @override
  String get defaultSmsNotThisApp =>
      'Not this app · tap to set default (required for delete)';

  @override
  String get autoRepair => 'Check & fix';

  @override
  String get autoRepairHint =>
      'Request read permission, then set as default SMS';

  @override
  String get sectionData => 'Data';

  @override
  String get exportSmsCsv => 'Export SMS CSV';

  @override
  String get exporting => 'Exporting…';

  @override
  String get exportSmsHint => 'Export all messages to a file and share';

  @override
  String get importSmsCsv => 'Import SMS CSV';

  @override
  String get importing => 'Importing…';

  @override
  String get importSmsHint => 'Insert only. Default SMS app required.';

  @override
  String get resetHiddenList => 'Reset hidden list';

  @override
  String get noHidden => 'No hidden messages';

  @override
  String hiddenCountLabel(int count) {
    return '$count hidden · reset to show again';
  }

  @override
  String get sectionAbout => 'About';

  @override
  String get version => 'Version';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacyHint => 'Data stays on this device';

  @override
  String get privacyToast =>
      'Data stays on this device. Nothing is uploaded or collected.';

  @override
  String get footerTagline => 'SMS Cleaner · on-device tool';

  @override
  String get deleteAvailable => 'Delete is available';

  @override
  String get restoreSystemSms => 'Restore system SMS';

  @override
  String get restoreSystemSmsHint =>
      'Open system “Default apps” and choose “Messages”';

  @override
  String get keepAsIs => 'Keep as is';

  @override
  String get openedDefaultSettingsPickOther =>
      'Opened system default apps. Choose another SMS app.';

  @override
  String get notDefaultNow => 'Not the default SMS app right now';

  @override
  String get openSettingsFailed => 'Failed to open settings';

  @override
  String get openedDefaultSettings => 'Opened system default apps settings';

  @override
  String get autoRepairReady => 'Ready: can read and delete';

  @override
  String get autoRepairIncomplete =>
      'Some items are not ready. Check the statuses above.';

  @override
  String get hiddenListReset => 'Hidden list reset';

  @override
  String get refreshStatus => 'Refresh status';

  @override
  String get readSms => 'Read SMS';

  @override
  String get readGrantedAppOps => 'Granted · AppOps OK';

  @override
  String get readDeniedList => 'Not granted · cannot read the message list';

  @override
  String get defaultSmsDeleteOk => 'This app · delete available';

  @override
  String get defaultSmsDeleteNeed => 'Not this app · delete requires default';

  @override
  String get miuiNotifSms => 'MIUI notification SMS';

  @override
  String get miuiNotifAllowed => 'Allowed · notification SMS visible';

  @override
  String get miuiNotifLikelyOff => 'Likely off · 10086 etc. may be missing';

  @override
  String get miuiNotifOff => 'Off · only person-to-person SMS';

  @override
  String get miuiNotifSuggest => 'MIUI extra permission · recommended';

  @override
  String get permExplainMiui =>
      'Read and delete are independent: reading only needs SMS permission; delete requires default SMS app. MIUI also has a “Notification SMS” switch — without it, 10086/bank notifications may be missing. If you change the default SMS app in system settings, read permission may be revoked; come back here to request it again.';

  @override
  String get permExplain =>
      'Read and delete are independent: reading only needs SMS permission; delete requires default SMS app. If you change the default SMS app in system settings, read permission may be revoked; come back here to request it again.';

  @override
  String get setDefaultSms => 'Set as default SMS app';

  @override
  String get openMiuiNotifSmsBtn => 'Enable MIUI notification SMS';

  @override
  String get miuiPath =>
      'Path: App info → Permissions → Other permissions → Notification SMS';

  @override
  String get openAppSettings => 'Open app settings';

  @override
  String get openDefaultSmsSettings => 'Open system default apps settings';

  @override
  String get openAppSettingsFailed => 'Failed to open app settings';

  @override
  String get openDefaultSettingsFailed =>
      'Failed to open default apps settings';

  @override
  String get themeHint =>
      'Pick an accent color. It applies to primary buttons, selected items, and icons.';

  @override
  String get preset => 'Presets';

  @override
  String get custom => 'Custom';

  @override
  String get colorValue => 'Color value';

  @override
  String get invalidColor => 'Enter a valid color, e.g. #2BAE67';

  @override
  String get applyCustomColor => 'Apply custom color';

  @override
  String get preview => 'Preview';

  @override
  String get primaryButtonSample => 'Primary button';

  @override
  String get filterChipSample => 'Filter chip';

  @override
  String get sameAddressSample => 'Same number 10086';

  @override
  String get seedGreen => 'Green';

  @override
  String get seedBlue => 'Blue';

  @override
  String get seedPurple => 'Purple';

  @override
  String get seedOrange => 'Orange';

  @override
  String get seedRed => 'Red';

  @override
  String get seedCyan => 'Cyan';

  @override
  String get seedPink => 'Pink';

  @override
  String get seedGraphite => 'Graphite';

  @override
  String get dayUnknown => 'Unknown';

  @override
  String get dayToday => 'Today';

  @override
  String get dayYesterday => 'Yesterday';

  @override
  String get exportFailedRetry => 'Export failed. Please retry.';

  @override
  String get exportEmpty => 'Nothing to export';

  @override
  String exportedShareText(int count) {
    return 'Exported $count messages';
  }

  @override
  String get importCancelled => 'Import cancelled';

  @override
  String get importReadFailed => 'Failed to read the file';

  @override
  String get importEmptyFile => 'No messages to import in this file';

  @override
  String get importUnknown => 'Unknown error';

  @override
  String get importNeedDefault =>
      'Import requires this app to be the default SMS app';

  @override
  String get importFailedRetry => 'Import failed. Please retry.';

  @override
  String importFailedWith(String error) {
    return 'Import failed: $error';
  }

  @override
  String importedPartial(int inserted, int parsed, int failed) {
    return 'Imported $inserted / $parsed ($failed failed)';
  }

  @override
  String importedAll(int inserted, int parsed) {
    return 'Imported $inserted / $parsed';
  }

  @override
  String errorSummaryMore(int count) {
    return ' and $count more';
  }

  @override
  String get errorSummarySeparator => '; ';

  @override
  String get defaultSmsMmsWarnTitle => 'MMS receive is limited';

  @override
  String get defaultSmsMmsWarnBody =>
      'As the default SMS app, new MMS messages only store sender/time/subject. Full body and attachments are not downloaded. Use the system Messages app if you need complete MMS.';

  @override
  String get aboutMmsReceiveTitle => 'MMS receive';

  @override
  String get aboutMmsReceiveBody =>
      'Browse/filter/delete/export MMS from the system database. When this app is default, new MMS is stored as metadata only (no full body download).';
}
