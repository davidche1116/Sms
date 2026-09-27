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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'短信清理'**
  String get appTitle;

  /// No description provided for @homeTitle.
  ///
  /// In zh, this message translates to:
  /// **'短信'**
  String get homeTitle;

  /// No description provided for @selectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count}'**
  String selectedCount(int count);

  /// No description provided for @loadedPartial.
  ///
  /// In zh, this message translates to:
  /// **'已加载 {loaded} / {total} 条'**
  String loadedPartial(int loaded, int total);

  /// No description provided for @loadedCount.
  ///
  /// In zh, this message translates to:
  /// **'已加载 {loaded} 条'**
  String loadedCount(int loaded);

  /// No description provided for @messageCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条'**
  String messageCount(int count);

  /// No description provided for @selectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAll;

  /// No description provided for @searchFilter.
  ///
  /// In zh, this message translates to:
  /// **'搜索 / 筛选'**
  String get searchFilter;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @more.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get more;

  /// No description provided for @exportSelected.
  ///
  /// In zh, this message translates to:
  /// **'导出选中'**
  String get exportSelected;

  /// No description provided for @deleteSelected.
  ///
  /// In zh, this message translates to:
  /// **'删除选中'**
  String get deleteSelected;

  /// No description provided for @queryFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'查询失败，下拉或点重试'**
  String get queryFailedRetry;

  /// No description provided for @deleteFailedNeedDefault.
  ///
  /// In zh, this message translates to:
  /// **'删除失败：请先设为默认短信应用'**
  String get deleteFailedNeedDefault;

  /// No description provided for @deletedCount.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {count} 条'**
  String deletedCount(int count);

  /// No description provided for @alreadyDefaultSms.
  ///
  /// In zh, this message translates to:
  /// **'已是默认短信应用'**
  String get alreadyDefaultSms;

  /// No description provided for @confirmInSystemDialog.
  ///
  /// In zh, this message translates to:
  /// **'请在系统弹窗中确认'**
  String get confirmInSystemDialog;

  /// No description provided for @confirmSetDefaultInDialog.
  ///
  /// In zh, this message translates to:
  /// **'请在系统弹窗中点「设为默认应用」'**
  String get confirmSetDefaultInDialog;

  /// No description provided for @systemNoResult.
  ///
  /// In zh, this message translates to:
  /// **'系统未返回结果，可在设置中手动开启'**
  String get systemNoResult;

  /// No description provided for @removedFromList.
  ///
  /// In zh, this message translates to:
  /// **'已移出列表'**
  String get removedFromList;

  /// No description provided for @nothingToDelete.
  ///
  /// In zh, this message translates to:
  /// **'没有可删除的短信'**
  String get nothingToDelete;

  /// No description provided for @needPermissionTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要短信权限'**
  String get needPermissionTitle;

  /// No description provided for @noMatchTitle.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的短信'**
  String get noMatchTitle;

  /// No description provided for @emptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'没有短信'**
  String get emptyTitle;

  /// No description provided for @needPermissionBody.
  ///
  /// In zh, this message translates to:
  /// **'授予读取短信权限后可浏览、搜索与导出；删除还需设为默认短信应用。'**
  String get needPermissionBody;

  /// No description provided for @noMatchBody.
  ///
  /// In zh, this message translates to:
  /// **'可以清除筛选后重试。'**
  String get noMatchBody;

  /// No description provided for @emptyBody.
  ///
  /// In zh, this message translates to:
  /// **'下拉可重新加载。'**
  String get emptyBody;

  /// No description provided for @requestSmsPermission.
  ///
  /// In zh, this message translates to:
  /// **'申请短信权限'**
  String get requestSmsPermission;

  /// No description provided for @clearFilters.
  ///
  /// In zh, this message translates to:
  /// **'清除筛选条件'**
  String get clearFilters;

  /// No description provided for @reload.
  ///
  /// In zh, this message translates to:
  /// **'重新加载'**
  String get reload;

  /// No description provided for @setDefaultForDelete.
  ///
  /// In zh, this message translates to:
  /// **'设为默认短信应用（删除需要）'**
  String get setDefaultForDelete;

  /// No description provided for @deleteSmsTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除短信？'**
  String get deleteSmsTitle;

  /// No description provided for @deleteSmsBody.
  ///
  /// In zh, this message translates to:
  /// **'将删除 {count} 条短信。删除后不可恢复。'**
  String deleteSmsBody(int count);

  /// No description provided for @deleteLargeWarn.
  ///
  /// In zh, this message translates to:
  /// **'数量较大（>3000），删除可能需要更久。'**
  String get deleteLargeWarn;

  /// No description provided for @deleteProgress.
  ///
  /// In zh, this message translates to:
  /// **'已完成 {progress} / {count}'**
  String deleteProgress(int progress, int count);

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @deleting.
  ///
  /// In zh, this message translates to:
  /// **'删除中…'**
  String get deleting;

  /// No description provided for @confirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get confirmDelete;

  /// No description provided for @keywordLabel.
  ///
  /// In zh, this message translates to:
  /// **'关键词'**
  String get keywordLabel;

  /// No description provided for @startDate.
  ///
  /// In zh, this message translates to:
  /// **'开始日期'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In zh, this message translates to:
  /// **'结束日期'**
  String get endDate;

  /// No description provided for @typeLabel.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get typeLabel;

  /// No description provided for @typeAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get typeAll;

  /// No description provided for @typeInbox.
  ///
  /// In zh, this message translates to:
  /// **'仅收件箱'**
  String get typeInbox;

  /// No description provided for @typeSent.
  ///
  /// In zh, this message translates to:
  /// **'仅已发送'**
  String get typeSent;

  /// No description provided for @reset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get reset;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @sameAddressChip.
  ///
  /// In zh, this message translates to:
  /// **'同号 {address}'**
  String sameAddressChip(String address);

  /// No description provided for @sameSimChip.
  ///
  /// In zh, this message translates to:
  /// **'同卡 {sim}'**
  String sameSimChip(int sim);

  /// No description provided for @keywordChip.
  ///
  /// In zh, this message translates to:
  /// **'“{keyword}”'**
  String keywordChip(String keyword);

  /// No description provided for @clearAllFilters.
  ///
  /// In zh, this message translates to:
  /// **'清除全部'**
  String get clearAllFilters;

  /// No description provided for @exportAllCsv.
  ///
  /// In zh, this message translates to:
  /// **'导出全部 CSV'**
  String get exportAllCsv;

  /// No description provided for @importCsv.
  ///
  /// In zh, this message translates to:
  /// **'导入 CSV'**
  String get importCsv;

  /// No description provided for @importCsvHint.
  ///
  /// In zh, this message translates to:
  /// **'写入系统短信库（需设为默认）'**
  String get importCsvHint;

  /// No description provided for @multiSelect.
  ///
  /// In zh, this message translates to:
  /// **'多选'**
  String get multiSelect;

  /// No description provided for @simTime.
  ///
  /// In zh, this message translates to:
  /// **'卡{sim} · {time}'**
  String simTime(int sim, String time);

  /// No description provided for @simBadge.
  ///
  /// In zh, this message translates to:
  /// **'卡{sim}'**
  String simBadge(int sim);

  /// No description provided for @sameAddressSms.
  ///
  /// In zh, this message translates to:
  /// **'同号短信'**
  String get sameAddressSms;

  /// No description provided for @sameAddressHint.
  ///
  /// In zh, this message translates to:
  /// **'只看这个号码的全部短信'**
  String get sameAddressHint;

  /// No description provided for @sameSimSms.
  ///
  /// In zh, this message translates to:
  /// **'同卡短信'**
  String get sameSimSms;

  /// No description provided for @copyAddress.
  ///
  /// In zh, this message translates to:
  /// **'复制号码'**
  String get copyAddress;

  /// No description provided for @copiedAddress.
  ///
  /// In zh, this message translates to:
  /// **'已复制号码'**
  String get copiedAddress;

  /// No description provided for @copyBody.
  ///
  /// In zh, this message translates to:
  /// **'复制正文'**
  String get copyBody;

  /// No description provided for @copiedBody.
  ///
  /// In zh, this message translates to:
  /// **'已复制正文'**
  String get copiedBody;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @deleteOneHint.
  ///
  /// In zh, this message translates to:
  /// **'删除这一条，删除前确认'**
  String get deleteOneHint;

  /// No description provided for @hideFromList.
  ///
  /// In zh, this message translates to:
  /// **'移出列表'**
  String get hideFromList;

  /// No description provided for @hideFromListHint.
  ///
  /// In zh, this message translates to:
  /// **'仅本地隐藏；悬浮球删除不会带上它们'**
  String get hideFromListHint;

  /// No description provided for @miuiBanner.
  ///
  /// In zh, this message translates to:
  /// **'可能还看不到 10086 等通知短信，点此开启 MIUI「通知类短信」'**
  String get miuiBanner;

  /// No description provided for @dismissHint.
  ///
  /// In zh, this message translates to:
  /// **'不再提示'**
  String get dismissHint;

  /// No description provided for @miuiGuideTitle.
  ///
  /// In zh, this message translates to:
  /// **'还要开启「通知类短信」'**
  String get miuiGuideTitle;

  /// No description provided for @miuiGuideBody.
  ///
  /// In zh, this message translates to:
  /// **'MIUI 将 10086、银行等通知短信单独管控。请在下一页打开：权限管理 → 其他权限 → 通知类短信。'**
  String get miuiGuideBody;

  /// No description provided for @openMiuiNotifSms.
  ///
  /// In zh, this message translates to:
  /// **'去开启通知类短信'**
  String get openMiuiNotifSms;

  /// No description provided for @later.
  ///
  /// In zh, this message translates to:
  /// **'稍后再说'**
  String get later;

  /// No description provided for @stillNoPermission.
  ///
  /// In zh, this message translates to:
  /// **'仍未获得权限，可到系统设置开启'**
  String get stillNoPermission;

  /// No description provided for @smsReadable.
  ///
  /// In zh, this message translates to:
  /// **'已可读取短信'**
  String get smsReadable;

  /// No description provided for @openMiuiPermFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开 MIUI 权限页失败'**
  String get openMiuiPermFailed;

  /// No description provided for @sectionAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get sectionAppearance;

  /// No description provided for @themeColor.
  ///
  /// In zh, this message translates to:
  /// **'主题色'**
  String get themeColor;

  /// No description provided for @darkMode.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get darkMode;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @sectionPermissions.
  ///
  /// In zh, this message translates to:
  /// **'权限'**
  String get sectionPermissions;

  /// No description provided for @smsPermission.
  ///
  /// In zh, this message translates to:
  /// **'短信权限'**
  String get smsPermission;

  /// No description provided for @smsPermissionGranted.
  ///
  /// In zh, this message translates to:
  /// **'已授予 · 用于读取与导出'**
  String get smsPermissionGranted;

  /// No description provided for @smsPermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'未授予 · 点击查看与申请'**
  String get smsPermissionDenied;

  /// No description provided for @checking.
  ///
  /// In zh, this message translates to:
  /// **'检查中…'**
  String get checking;

  /// No description provided for @defaultSmsApp.
  ///
  /// In zh, this message translates to:
  /// **'默认短信应用'**
  String get defaultSmsApp;

  /// No description provided for @defaultSmsIsThisApp.
  ///
  /// In zh, this message translates to:
  /// **'本应用 · 点击可还原系统短信'**
  String get defaultSmsIsThisApp;

  /// No description provided for @defaultSmsNotThisApp.
  ///
  /// In zh, this message translates to:
  /// **'非本应用 · 点击设为默认（删除需要）'**
  String get defaultSmsNotThisApp;

  /// No description provided for @autoRepair.
  ///
  /// In zh, this message translates to:
  /// **'一键检查并修复'**
  String get autoRepair;

  /// No description provided for @autoRepairHint.
  ///
  /// In zh, this message translates to:
  /// **'依次申请读权限、设为默认短信'**
  String get autoRepairHint;

  /// No description provided for @sectionData.
  ///
  /// In zh, this message translates to:
  /// **'数据'**
  String get sectionData;

  /// No description provided for @exportSmsCsv.
  ///
  /// In zh, this message translates to:
  /// **'导出短信 CSV'**
  String get exportSmsCsv;

  /// No description provided for @exporting.
  ///
  /// In zh, this message translates to:
  /// **'导出中…'**
  String get exporting;

  /// No description provided for @exportSmsHint.
  ///
  /// In zh, this message translates to:
  /// **'导出全部短信到文件并分享'**
  String get exportSmsHint;

  /// No description provided for @importSmsCsv.
  ///
  /// In zh, this message translates to:
  /// **'导入短信 CSV'**
  String get importSmsCsv;

  /// No description provided for @importing.
  ///
  /// In zh, this message translates to:
  /// **'导入中…'**
  String get importing;

  /// No description provided for @importSmsHint.
  ///
  /// In zh, this message translates to:
  /// **'只新增入库，需设为默认短信应用'**
  String get importSmsHint;

  /// No description provided for @resetHiddenList.
  ///
  /// In zh, this message translates to:
  /// **'重置本地隐藏列表'**
  String get resetHiddenList;

  /// No description provided for @noHidden.
  ///
  /// In zh, this message translates to:
  /// **'暂无已移出的短信'**
  String get noHidden;

  /// No description provided for @hiddenCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'已移出 {count} 条，重置后重新显示'**
  String hiddenCountLabel(int count);

  /// No description provided for @sectionAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get sectionAbout;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// No description provided for @privacy.
  ///
  /// In zh, this message translates to:
  /// **'隐私说明'**
  String get privacy;

  /// No description provided for @privacyHint.
  ///
  /// In zh, this message translates to:
  /// **'数据仅在本机处理'**
  String get privacyHint;

  /// No description provided for @privacyToast.
  ///
  /// In zh, this message translates to:
  /// **'数据仅在本机处理，不上传、不收集'**
  String get privacyToast;

  /// No description provided for @footerTagline.
  ///
  /// In zh, this message translates to:
  /// **'短信清理 · 本地工具'**
  String get footerTagline;

  /// No description provided for @deleteAvailable.
  ///
  /// In zh, this message translates to:
  /// **'删除短信功能可用'**
  String get deleteAvailable;

  /// No description provided for @restoreSystemSms.
  ///
  /// In zh, this message translates to:
  /// **'还原为系统短信'**
  String get restoreSystemSms;

  /// No description provided for @restoreSystemSmsHint.
  ///
  /// In zh, this message translates to:
  /// **'打开系统「默认应用」设置，手动选择「信息」'**
  String get restoreSystemSmsHint;

  /// No description provided for @keepAsIs.
  ///
  /// In zh, this message translates to:
  /// **'保持现状'**
  String get keepAsIs;

  /// No description provided for @openedDefaultSettingsPickOther.
  ///
  /// In zh, this message translates to:
  /// **'已打开系统默认应用设置，请选择其他短信应用'**
  String get openedDefaultSettingsPickOther;

  /// No description provided for @notDefaultNow.
  ///
  /// In zh, this message translates to:
  /// **'当前不是默认短信应用'**
  String get notDefaultNow;

  /// No description provided for @openSettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开设置失败'**
  String get openSettingsFailed;

  /// No description provided for @openedDefaultSettings.
  ///
  /// In zh, this message translates to:
  /// **'已打开系统默认应用设置'**
  String get openedDefaultSettings;

  /// No description provided for @autoRepairReady.
  ///
  /// In zh, this message translates to:
  /// **'已就绪：可读可删'**
  String get autoRepairReady;

  /// No description provided for @autoRepairIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'仍有项目未就绪，请检查上方状态'**
  String get autoRepairIncomplete;

  /// No description provided for @hiddenListReset.
  ///
  /// In zh, this message translates to:
  /// **'已重置本地隐藏列表'**
  String get hiddenListReset;

  /// No description provided for @refreshStatus.
  ///
  /// In zh, this message translates to:
  /// **'刷新状态'**
  String get refreshStatus;

  /// No description provided for @readSms.
  ///
  /// In zh, this message translates to:
  /// **'读取短信'**
  String get readSms;

  /// No description provided for @readGrantedAppOps.
  ///
  /// In zh, this message translates to:
  /// **'已授予 · AppOps 正常'**
  String get readGrantedAppOps;

  /// No description provided for @readDeniedList.
  ///
  /// In zh, this message translates to:
  /// **'未授予 · 无法读取短信列表'**
  String get readDeniedList;

  /// No description provided for @defaultSmsDeleteOk.
  ///
  /// In zh, this message translates to:
  /// **'本应用 · 删除功能可用'**
  String get defaultSmsDeleteOk;

  /// No description provided for @defaultSmsDeleteNeed.
  ///
  /// In zh, this message translates to:
  /// **'非本应用 · 删除短信需要设为默认'**
  String get defaultSmsDeleteNeed;

  /// No description provided for @miuiNotifSms.
  ///
  /// In zh, this message translates to:
  /// **'MIUI 通知类短信'**
  String get miuiNotifSms;

  /// No description provided for @miuiNotifAllowed.
  ///
  /// In zh, this message translates to:
  /// **'已允许 · 通知类短信可见'**
  String get miuiNotifAllowed;

  /// No description provided for @miuiNotifLikelyOff.
  ///
  /// In zh, this message translates to:
  /// **'可能未开通 · 10086 等可能读不到'**
  String get miuiNotifLikelyOff;

  /// No description provided for @miuiNotifOff.
  ///
  /// In zh, this message translates to:
  /// **'未开通 · 只能读到点对点短信'**
  String get miuiNotifOff;

  /// No description provided for @miuiNotifSuggest.
  ///
  /// In zh, this message translates to:
  /// **'MIUI 附加权限 · 建议开通'**
  String get miuiNotifSuggest;

  /// No description provided for @permExplainMiui.
  ///
  /// In zh, this message translates to:
  /// **'读取与删除相互独立：读列表只需短信权限；删除必须是默认短信应用。MIUI 额外有「通知类短信」开关，不开通时 10086/银行等通知类会读不到。在系统中改掉默认短信后，系统可能同时收回读权限，回到本页重新申请即可。'**
  String get permExplainMiui;

  /// No description provided for @permExplain.
  ///
  /// In zh, this message translates to:
  /// **'读取与删除相互独立：读列表只需短信权限；删除必须是默认短信应用。在系统中改掉默认短信后，系统可能同时收回读权限，回到本页重新申请即可。'**
  String get permExplain;

  /// No description provided for @setDefaultSms.
  ///
  /// In zh, this message translates to:
  /// **'设为默认短信应用'**
  String get setDefaultSms;

  /// No description provided for @openMiuiNotifSmsBtn.
  ///
  /// In zh, this message translates to:
  /// **'开启 MIUI 通知类短信'**
  String get openMiuiNotifSmsBtn;

  /// No description provided for @miuiPath.
  ///
  /// In zh, this message translates to:
  /// **'路径：应用信息 → 权限管理 → 其他权限 → 通知类短信'**
  String get miuiPath;

  /// No description provided for @openAppSettings.
  ///
  /// In zh, this message translates to:
  /// **'打开应用设置'**
  String get openAppSettings;

  /// No description provided for @openDefaultSmsSettings.
  ///
  /// In zh, this message translates to:
  /// **'打开系统默认应用设置'**
  String get openDefaultSmsSettings;

  /// No description provided for @openAppSettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开应用设置失败'**
  String get openAppSettingsFailed;

  /// No description provided for @openDefaultSettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开默认应用设置失败'**
  String get openDefaultSettingsFailed;

  /// No description provided for @themeHint.
  ///
  /// In zh, this message translates to:
  /// **'选择强调色，立即作用于主按钮、选中项与图标。'**
  String get themeHint;

  /// No description provided for @preset.
  ///
  /// In zh, this message translates to:
  /// **'预设'**
  String get preset;

  /// No description provided for @custom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get custom;

  /// No description provided for @colorValue.
  ///
  /// In zh, this message translates to:
  /// **'颜色值'**
  String get colorValue;

  /// No description provided for @invalidColor.
  ///
  /// In zh, this message translates to:
  /// **'请输入合法颜色值，如 #2BAE67'**
  String get invalidColor;

  /// No description provided for @applyCustomColor.
  ///
  /// In zh, this message translates to:
  /// **'应用自定义颜色'**
  String get applyCustomColor;

  /// No description provided for @preview.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get preview;

  /// No description provided for @primaryButtonSample.
  ///
  /// In zh, this message translates to:
  /// **'主按钮示例'**
  String get primaryButtonSample;

  /// No description provided for @filterChipSample.
  ///
  /// In zh, this message translates to:
  /// **'筛选 Chip'**
  String get filterChipSample;

  /// No description provided for @sameAddressSample.
  ///
  /// In zh, this message translates to:
  /// **'同号 10086'**
  String get sameAddressSample;

  /// No description provided for @seedGreen.
  ///
  /// In zh, this message translates to:
  /// **'绿'**
  String get seedGreen;

  /// No description provided for @seedBlue.
  ///
  /// In zh, this message translates to:
  /// **'蓝'**
  String get seedBlue;

  /// No description provided for @seedPurple.
  ///
  /// In zh, this message translates to:
  /// **'紫'**
  String get seedPurple;

  /// No description provided for @seedOrange.
  ///
  /// In zh, this message translates to:
  /// **'橙'**
  String get seedOrange;

  /// No description provided for @seedRed.
  ///
  /// In zh, this message translates to:
  /// **'红'**
  String get seedRed;

  /// No description provided for @seedCyan.
  ///
  /// In zh, this message translates to:
  /// **'青'**
  String get seedCyan;

  /// No description provided for @seedPink.
  ///
  /// In zh, this message translates to:
  /// **'粉'**
  String get seedPink;

  /// No description provided for @seedGraphite.
  ///
  /// In zh, this message translates to:
  /// **'石墨'**
  String get seedGraphite;

  /// No description provided for @dayUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get dayUnknown;

  /// No description provided for @dayToday.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get dayToday;

  /// No description provided for @dayYesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get dayYesterday;

  /// No description provided for @exportFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'导出失败，请重试'**
  String get exportFailedRetry;

  /// No description provided for @exportEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有可导出的短信'**
  String get exportEmpty;

  /// No description provided for @exportedShareText.
  ///
  /// In zh, this message translates to:
  /// **'已导出 {count} 条短信'**
  String exportedShareText(int count);

  /// No description provided for @importCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消导入'**
  String get importCancelled;

  /// No description provided for @importReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取文件失败'**
  String get importReadFailed;

  /// No description provided for @importEmptyFile.
  ///
  /// In zh, this message translates to:
  /// **'文件中没有可导入的短信'**
  String get importEmptyFile;

  /// No description provided for @importUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知错误'**
  String get importUnknown;

  /// No description provided for @importNeedDefault.
  ///
  /// In zh, this message translates to:
  /// **'导入需先设为默认短信应用'**
  String get importNeedDefault;

  /// No description provided for @importFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'导入失败，请重试'**
  String get importFailedRetry;

  /// No description provided for @importFailedWith.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{error}'**
  String importFailedWith(String error);

  /// No description provided for @importedPartial.
  ///
  /// In zh, this message translates to:
  /// **'已导入 {inserted} / {parsed} 条（{failed} 条失败）'**
  String importedPartial(int inserted, int parsed, int failed);

  /// No description provided for @importedAll.
  ///
  /// In zh, this message translates to:
  /// **'已导入 {inserted} / {parsed} 条'**
  String importedAll(int inserted, int parsed);

  /// No description provided for @errorSummaryMore.
  ///
  /// In zh, this message translates to:
  /// **' 等 {count} 条'**
  String errorSummaryMore(int count);

  /// No description provided for @errorSummarySeparator.
  ///
  /// In zh, this message translates to:
  /// **'；'**
  String get errorSummarySeparator;
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
