import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'SMS Cleanup'**
  String get title;

  /// No description provided for @toast_default.
  ///
  /// In en, this message translates to:
  /// **'To delete SMS messages, please set this app as the default SMS app in System Settings'**
  String get toast_default;

  /// No description provided for @toast_permission.
  ///
  /// In en, this message translates to:
  /// **'SMS permission required or set as default SMS app'**
  String get toast_permission;

  /// No description provided for @keyword.
  ///
  /// In en, this message translates to:
  /// **'Keyword'**
  String get keyword;

  /// No description provided for @b_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get b_confirm;

  /// No description provided for @t_confirm_delete.
  ///
  /// In en, this message translates to:
  /// **'Confirm Deletion'**
  String get t_confirm_delete;

  /// A message with a single parameter
  ///
  /// In en, this message translates to:
  /// **'Delete {num} message(s)?'**
  String delete_num(String num);

  /// No description provided for @b_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get b_cancel;

  /// No description provided for @operation_failed.
  ///
  /// In en, this message translates to:
  /// **'Operation Failed'**
  String get operation_failed;

  /// No description provided for @operation_completed.
  ///
  /// In en, this message translates to:
  /// **'Operation Completed'**
  String get operation_completed;

  /// No description provided for @toast_no.
  ///
  /// In en, this message translates to:
  /// **'No messages to share'**
  String get toast_no;

  /// No description provided for @sms_list.
  ///
  /// In en, this message translates to:
  /// **'Message List'**
  String get sms_list;

  /// No description provided for @toast_share.
  ///
  /// In en, this message translates to:
  /// **'Shared successfully. Please open with UTF-8 encoding'**
  String get toast_share;

  /// No description provided for @tips.
  ///
  /// In en, this message translates to:
  /// **'Tips'**
  String get tips;

  /// No description provided for @delete_or_move.
  ///
  /// In en, this message translates to:
  /// **'Delete or remove this item?'**
  String get delete_or_move;

  /// No description provided for @b_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove from List'**
  String get b_remove;

  /// No description provided for @b_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get b_delete;

  /// No description provided for @b_same_number.
  ///
  /// In en, this message translates to:
  /// **'Messages from Same Number'**
  String get b_same_number;

  /// No description provided for @toast_clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get toast_clipboard;

  /// No description provided for @b_copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get b_copy;

  /// No description provided for @sms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get sms;

  /// A message with a single parameter
  ///
  /// In en, this message translates to:
  /// **'{num} message(s)'**
  String num_sms(String num);

  /// No description provided for @t_all_sms.
  ///
  /// In en, this message translates to:
  /// **'All Messages'**
  String get t_all_sms;

  /// No description provided for @t_keyword_filter.
  ///
  /// In en, this message translates to:
  /// **'Filter by Keyword'**
  String get t_keyword_filter;

  /// No description provided for @set_permission.
  ///
  /// In en, this message translates to:
  /// **'Request SMS Permission'**
  String get set_permission;

  /// No description provided for @set_settings.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get set_settings;

  /// No description provided for @set_default.
  ///
  /// In en, this message translates to:
  /// **'Set as Default SMS App'**
  String get set_default;

  /// No description provided for @set_restore.
  ///
  /// In en, this message translates to:
  /// **'Restore Default SMS App'**
  String get set_restore;

  /// No description provided for @set_export.
  ///
  /// In en, this message translates to:
  /// **'Export as CSV'**
  String get set_export;

  /// No description provided for @t_wait.
  ///
  /// In en, this message translates to:
  /// **'Please wait'**
  String get t_wait;

  /// No description provided for @t_no_sms.
  ///
  /// In en, this message translates to:
  /// **'No messages'**
  String get t_no_sms;

  /// No description provided for @b_remove_filter.
  ///
  /// In en, this message translates to:
  /// **'Clear Filter'**
  String get b_remove_filter;

  /// No description provided for @t_delete_all.
  ///
  /// In en, this message translates to:
  /// **'Delete All Messages in Current List'**
  String get t_delete_all;

  /// No description provided for @sim.
  ///
  /// In en, this message translates to:
  /// **'SIM'**
  String get sim;

  /// No description provided for @t_list_too_long.
  ///
  /// In en, this message translates to:
  /// **'Large list, may take longer to process'**
  String get t_list_too_long;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
