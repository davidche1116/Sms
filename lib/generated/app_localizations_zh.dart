// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '短信清理';

  @override
  String get homeTitle => '短信';

  @override
  String selectedCount(int count) {
    return '已选 $count';
  }

  @override
  String loadedPartial(int loaded, int total) {
    return '已加载 $loaded / $total 条';
  }

  @override
  String loadedCount(int loaded) {
    return '已加载 $loaded 条';
  }

  @override
  String messageCount(int count) {
    return '$count 条';
  }

  @override
  String get selectAll => '全选';

  @override
  String get searchFilter => '搜索 / 筛选';

  @override
  String get settings => '设置';

  @override
  String get more => '更多';

  @override
  String get exportSelected => '导出选中';

  @override
  String get deleteSelected => '删除选中';

  @override
  String get queryFailedRetry => '查询失败，下拉或点重试';

  @override
  String get deleteFailedNeedDefault => '删除失败：请先设为默认短信应用';

  @override
  String get deleteFailedRetry => '删除失败，请重试';

  @override
  String deletedCount(int count) {
    return '已删除 $count 条';
  }

  @override
  String get alreadyDefaultSms => '已是默认短信应用';

  @override
  String get confirmInSystemDialog => '请在系统弹窗中确认';

  @override
  String get confirmSetDefaultInDialog => '请在系统弹窗中点「设为默认应用」';

  @override
  String get systemNoResult => '系统未返回结果，可在设置中手动开启';

  @override
  String get removedFromList => '已移出列表';

  @override
  String get nothingToDelete => '没有可删除的短信';

  @override
  String get needPermissionTitle => '需要短信权限';

  @override
  String get noMatchTitle => '没有匹配的短信';

  @override
  String get emptyTitle => '没有短信';

  @override
  String get needPermissionBody => '授予读取短信权限后可浏览、搜索与导出；删除还需设为默认短信应用。';

  @override
  String get noMatchBody => '可以清除筛选后重试。';

  @override
  String get emptyBody => '下拉可重新加载。';

  @override
  String get requestSmsPermission => '申请短信权限';

  @override
  String get clearFilters => '清除筛选条件';

  @override
  String get reload => '重新加载';

  @override
  String get setDefaultForDelete => '设为默认短信应用（删除需要）';

  @override
  String get deleteSmsTitle => '删除短信？';

  @override
  String deleteSmsBody(int count) {
    return '将删除 $count 条短信。删除后不可恢复。';
  }

  @override
  String get deleteLargeWarn => '数量较大（>3000），删除可能需要更久。';

  @override
  String deleteProgress(int progress, int count) {
    return '已完成 $progress / $count';
  }

  @override
  String deleteCannotUndo(int count) {
    return '已删 $count，不可撤销';
  }

  @override
  String deletePartialFailed(int deleted, int total) {
    return '已删除 $deleted / $total 条后失败';
  }

  @override
  String deleteCancelled(int count) {
    return '已取消，已删除 $count 条';
  }

  @override
  String get cancel => '取消';

  @override
  String get stopDelete => '停止';

  @override
  String get stoppingDelete => '停止中…';

  @override
  String get deleting => '删除中…';

  @override
  String get confirmDelete => '确认删除';

  @override
  String get keywordLabel => '关键词';

  @override
  String get startDate => '开始日期';

  @override
  String get endDate => '结束日期';

  @override
  String get typeLabel => '类型';

  @override
  String get typeAll => '全部';

  @override
  String get typeInbox => '仅收件箱';

  @override
  String get typeSent => '仅已发送';

  @override
  String get typeMms => '仅彩信';

  @override
  String get mmsBadge => '彩信';

  @override
  String get mmsHasAttachment => '含附件';

  @override
  String get mmsBodyPlaceholder => '[彩信]';

  @override
  String get mmsBodyWithAttachment => '[彩信]·含附件';

  @override
  String get reset => '重置';

  @override
  String get done => '完成';

  @override
  String sameAddressChip(String address) {
    return '同号 $address';
  }

  @override
  String sameSimChip(int sim) {
    return '同卡 $sim';
  }

  @override
  String keywordChip(String keyword) {
    return '“$keyword”';
  }

  @override
  String get clearAllFilters => '清除全部';

  @override
  String get exportAllCsv => '导出全部 CSV';

  @override
  String get importCsv => '导入 CSV';

  @override
  String get importCsvHint => '写入系统短信库（需设为默认）';

  @override
  String get multiSelect => '多选';

  @override
  String simTime(int sim, String time) {
    return '卡$sim · $time';
  }

  @override
  String simBadge(int sim) {
    return '卡$sim';
  }

  @override
  String get sameAddressSms => '同号短信';

  @override
  String get sameAddressHint => '只看这个号码的全部短信';

  @override
  String get sameSimSms => '同卡短信';

  @override
  String get copyAddress => '复制号码';

  @override
  String get copiedAddress => '已复制号码';

  @override
  String get copyBody => '复制正文';

  @override
  String get copiedBody => '已复制正文';

  @override
  String get delete => '删除';

  @override
  String get deleteOneHint => '删除这一条，删除前确认';

  @override
  String get hideFromList => '移出列表';

  @override
  String get hideFromListHint => '仅本地隐藏；悬浮球删除不会带上它们';

  @override
  String get miuiBanner => '可能还看不到 10086 等通知短信，点此开启 MIUI「通知类短信」';

  @override
  String get partialQueryBanner => '部分短信可能未加载';

  @override
  String get partialQueryBannerHint => '点此重试';

  @override
  String get dismissHint => '不再提示';

  @override
  String get miuiGuideTitle => '还要开启「通知类短信」';

  @override
  String get miuiGuideBody =>
      'MIUI 将 10086、银行等通知短信单独管控。请在下一页打开：权限管理 → 其他权限 → 通知类短信。';

  @override
  String get openMiuiNotifSms => '去开启通知类短信';

  @override
  String get later => '稍后再说';

  @override
  String get stillNoPermission => '仍未获得权限，可到系统设置开启';

  @override
  String get smsReadable => '已可读取短信';

  @override
  String get openMiuiPermFailed => '打开 MIUI 权限页失败';

  @override
  String get sectionAppearance => '外观';

  @override
  String get themeColor => '主题色';

  @override
  String get darkMode => '深色模式';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get sectionPermissions => '权限';

  @override
  String get smsPermission => '短信权限';

  @override
  String get smsPermissionGranted => '已授予 · 用于读取与导出';

  @override
  String get smsPermissionDenied => '未授予 · 点击查看与申请';

  @override
  String get checking => '检查中…';

  @override
  String get defaultSmsApp => '默认短信应用';

  @override
  String get defaultSmsIsThisApp => '本应用 · 点击可还原系统短信';

  @override
  String get defaultSmsNotThisApp => '非本应用 · 点击设为默认（删除需要）';

  @override
  String get autoRepair => '一键检查并修复';

  @override
  String get autoRepairHint => '依次申请读权限、设为默认短信';

  @override
  String get sectionData => '数据';

  @override
  String get exportSmsCsv => '导出短信 CSV';

  @override
  String get exporting => '导出中…';

  @override
  String get exportSmsHint => '导出全部短信到文件并分享';

  @override
  String get importSmsCsv => '导入短信 CSV';

  @override
  String get importing => '导入中…';

  @override
  String get importSmsHint => '只新增入库，需设为默认短信应用';

  @override
  String get resetHiddenList => '重置本地隐藏列表';

  @override
  String get noHidden => '暂无已移出的短信';

  @override
  String hiddenCountLabel(int count) {
    return '已移出 $count 条，重置后重新显示';
  }

  @override
  String get sectionAbout => '关于';

  @override
  String get version => '版本';

  @override
  String get privacy => '隐私说明';

  @override
  String get privacyHint => '数据仅在本机处理';

  @override
  String get privacyToast => '数据仅在本机处理，不上传、不收集';

  @override
  String get footerTagline => '短信清理 · 本地工具';

  @override
  String get deleteAvailable => '删除短信功能可用';

  @override
  String get restoreSystemSms => '还原为系统短信';

  @override
  String get restoreSystemSmsHint => '打开系统「默认应用」设置，手动选择「信息」';

  @override
  String get keepAsIs => '保持现状';

  @override
  String get openedDefaultSettingsPickOther => '已打开系统默认应用设置，请选择其他短信应用';

  @override
  String get notDefaultNow => '当前不是默认短信应用';

  @override
  String get openSettingsFailed => '打开设置失败';

  @override
  String get openedDefaultSettings => '已打开系统默认应用设置';

  @override
  String get autoRepairReady => '已就绪：可读可删';

  @override
  String get autoRepairIncomplete => '仍有项目未就绪，请检查上方状态';

  @override
  String get hiddenListReset => '已重置本地隐藏列表';

  @override
  String get refreshStatus => '刷新状态';

  @override
  String get readSms => '读取短信';

  @override
  String get readGrantedAppOps => '已授予 · AppOps 正常';

  @override
  String get readDeniedList => '未授予 · 无法读取短信列表';

  @override
  String get defaultSmsDeleteOk => '本应用 · 删除功能可用';

  @override
  String get defaultSmsDeleteNeed => '非本应用 · 删除短信需要设为默认';

  @override
  String get miuiNotifSms => 'MIUI 通知类短信';

  @override
  String get miuiNotifAllowed => '已允许 · 通知类短信可见';

  @override
  String get miuiNotifLikelyOff => '可能未开通 · 10086 等可能读不到';

  @override
  String get miuiNotifOff => '未开通 · 只能读到点对点短信';

  @override
  String get miuiNotifSuggest => 'MIUI 附加权限 · 建议开通';

  @override
  String get permExplainMiui =>
      '读取与删除相互独立：读列表只需短信权限；删除必须是默认短信应用。MIUI 额外有「通知类短信」开关，不开通时 10086/银行等通知类会读不到。在系统中改掉默认短信后，系统可能同时收回读权限，回到本页重新申请即可。';

  @override
  String get permExplain =>
      '读取与删除相互独立：读列表只需短信权限；删除必须是默认短信应用。在系统中改掉默认短信后，系统可能同时收回读权限，回到本页重新申请即可。';

  @override
  String get setDefaultSms => '设为默认短信应用';

  @override
  String get openMiuiNotifSmsBtn => '开启 MIUI 通知类短信';

  @override
  String get miuiPath => '路径：应用信息 → 权限管理 → 其他权限 → 通知类短信';

  @override
  String get openAppSettings => '打开应用设置';

  @override
  String get openDefaultSmsSettings => '打开系统默认应用设置';

  @override
  String get openAppSettingsFailed => '打开应用设置失败';

  @override
  String get openDefaultSettingsFailed => '打开默认应用设置失败';

  @override
  String get themeHint => '选择强调色，立即作用于主按钮、选中项与图标。';

  @override
  String get preset => '预设';

  @override
  String get custom => '自定义';

  @override
  String get colorValue => '颜色值';

  @override
  String get invalidColor => '请输入合法颜色值，如 #2BAE67';

  @override
  String get applyCustomColor => '应用自定义颜色';

  @override
  String get preview => '预览';

  @override
  String get primaryButtonSample => '主按钮示例';

  @override
  String get filterChipSample => '筛选 Chip';

  @override
  String get sameAddressSample => '同号 10086';

  @override
  String get seedGreen => '绿';

  @override
  String get seedBlue => '蓝';

  @override
  String get seedPurple => '紫';

  @override
  String get seedOrange => '橙';

  @override
  String get seedRed => '红';

  @override
  String get seedCyan => '青';

  @override
  String get seedPink => '粉';

  @override
  String get seedGraphite => '石墨';

  @override
  String get dayUnknown => '未知';

  @override
  String get dayToday => '今天';

  @override
  String get dayYesterday => '昨天';

  @override
  String get exportFailedRetry => '导出失败，请重试';

  @override
  String get exportEmpty => '没有可导出的短信';

  @override
  String exportedShareText(int count) {
    return '已导出 $count 条短信';
  }

  @override
  String get importCancelled => '已取消导入';

  @override
  String get importReadFailed => '读取文件失败';

  @override
  String get importEmptyFile => '文件中没有可导入的短信';

  @override
  String get importUnknown => '未知错误';

  @override
  String get importNeedDefault => '导入需先设为默认短信应用';

  @override
  String get importFailedRetry => '导入失败，请重试';

  @override
  String importFailedWith(String error) {
    return '导入失败：$error';
  }

  @override
  String importedPartial(int inserted, int parsed, int failed) {
    return '已导入 $inserted / $parsed 条（$failed 条失败）';
  }

  @override
  String importedAll(int inserted, int parsed) {
    return '已导入 $inserted / $parsed 条';
  }

  @override
  String errorSummaryMore(int count) {
    return ' 等 $count 条';
  }

  @override
  String get errorSummarySeparator => '；';

  @override
  String get insertErrNotDefault => '非默认短信应用';

  @override
  String get insertErrFailed => '写入失败';

  @override
  String get insertErrInvalid => '数据格式非法';

  @override
  String get insertErrUnknown => '未知错误';

  @override
  String get deleteErrNotDefault => '非默认短信应用';

  @override
  String get deleteErrFailed => '删除失败';

  @override
  String get deleteErrUnknown => '未知错误';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageZhTw => '繁體中文';

  @override
  String get languageEn => 'English';

  @override
  String get openSourceLicenses => '开源许可';

  @override
  String get openSourceLicensesHint => '第三方组件与许可证';

  @override
  String get feedback => '问题反馈';

  @override
  String get feedbackHint => 'GitHub Issues';

  @override
  String get feedbackOpenFailed => '无法打开浏览器，请手动访问项目仓库';

  @override
  String get privacyDialogTitle => '隐私说明';

  @override
  String get privacyDialogBody =>
      '短信内容仅用于本机展示、筛选与导出；无网络上传，无统计上报。删除不可恢复，请在操作前确认。';

  @override
  String get defaultSmsMmsWarnTitle => '彩信接收有限制';

  @override
  String get defaultSmsMmsWarnBody =>
      '作为默认短信应用时，新彩信只入库发件人/时间/主题，不下载完整正文与附件。需要完整彩信请改回系统「信息」接收。';

  @override
  String get aboutMmsReceiveTitle => '彩信接收说明';

  @override
  String get aboutMmsReceiveBody =>
      '浏览/筛选/删除/导出系统库中的彩信。本应用为默认时，新彩信仅入库元数据骨架，不下载完整正文。';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => '簡訊清理';

  @override
  String get homeTitle => '簡訊';

  @override
  String selectedCount(int count) {
    return '已選 $count';
  }

  @override
  String loadedPartial(int loaded, int total) {
    return '已載入 $loaded / $total 則';
  }

  @override
  String loadedCount(int loaded) {
    return '已載入 $loaded 則';
  }

  @override
  String messageCount(int count) {
    return '$count 則';
  }

  @override
  String get selectAll => '全選';

  @override
  String get searchFilter => '搜尋 / 篩選';

  @override
  String get settings => '設定';

  @override
  String get more => '更多';

  @override
  String get exportSelected => '匯出所選';

  @override
  String get deleteSelected => '刪除所選';

  @override
  String get queryFailedRetry => '查詢失敗，下拉或點重試';

  @override
  String get deleteFailedNeedDefault => '刪除失敗：請先設為預設簡訊應用程式';

  @override
  String get deleteFailedRetry => '刪除失敗，請重試';

  @override
  String deletedCount(int count) {
    return '已刪除 $count 則';
  }

  @override
  String get alreadyDefaultSms => '已是預設簡訊應用程式';

  @override
  String get confirmInSystemDialog => '請在系統對話框中確認';

  @override
  String get confirmSetDefaultInDialog => '請在系統對話框中點「設為預設應用程式」';

  @override
  String get systemNoResult => '系統未回傳結果，可在設定中手動開啟';

  @override
  String get removedFromList => '已移出清單';

  @override
  String get nothingToDelete => '沒有可刪除的簡訊';

  @override
  String get needPermissionTitle => '需要簡訊權限';

  @override
  String get noMatchTitle => '沒有符合的簡訊';

  @override
  String get emptyTitle => '沒有簡訊';

  @override
  String get needPermissionBody => '授予讀取簡訊權限後可瀏覽、搜尋與匯出；刪除還需設為預設簡訊應用程式。';

  @override
  String get noMatchBody => '可以清除篩選後重試。';

  @override
  String get emptyBody => '下拉可重新載入。';

  @override
  String get requestSmsPermission => '申請簡訊權限';

  @override
  String get clearFilters => '清除篩選條件';

  @override
  String get reload => '重新載入';

  @override
  String get setDefaultForDelete => '設為預設簡訊應用程式（刪除需要）';

  @override
  String get deleteSmsTitle => '刪除簡訊？';

  @override
  String deleteSmsBody(int count) {
    return '將刪除 $count 則簡訊。刪除後不可復原。';
  }

  @override
  String get deleteLargeWarn => '數量較大（>3000），刪除可能需要更久。';

  @override
  String deleteProgress(int progress, int count) {
    return '已完成 $progress / $count';
  }

  @override
  String deleteCannotUndo(int count) {
    return '已刪 $count，不可撤銷';
  }

  @override
  String deletePartialFailed(int deleted, int total) {
    return '已刪除 $deleted / $total 則後失敗';
  }

  @override
  String deleteCancelled(int count) {
    return '已取消，已刪除 $count 則';
  }

  @override
  String get cancel => '取消';

  @override
  String get stopDelete => '停止';

  @override
  String get stoppingDelete => '停止中…';

  @override
  String get deleting => '刪除中…';

  @override
  String get confirmDelete => '確認刪除';

  @override
  String get keywordLabel => '關鍵字';

  @override
  String get startDate => '開始日期';

  @override
  String get endDate => '結束日期';

  @override
  String get typeLabel => '類型';

  @override
  String get typeAll => '全部';

  @override
  String get typeInbox => '僅收件匣';

  @override
  String get typeSent => '僅已傳送';

  @override
  String get typeMms => '僅多媒體簡訊';

  @override
  String get mmsBadge => '多媒體';

  @override
  String get mmsHasAttachment => '含附件';

  @override
  String get mmsBodyPlaceholder => '[多媒體簡訊]';

  @override
  String get mmsBodyWithAttachment => '[多媒體簡訊]·含附件';

  @override
  String get reset => '重設';

  @override
  String get done => '完成';

  @override
  String sameAddressChip(String address) {
    return '同號 $address';
  }

  @override
  String sameSimChip(int sim) {
    return '同卡 $sim';
  }

  @override
  String keywordChip(String keyword) {
    return '「$keyword」';
  }

  @override
  String get clearAllFilters => '清除全部';

  @override
  String get exportAllCsv => '匯出全部 CSV';

  @override
  String get importCsv => '匯入 CSV';

  @override
  String get importCsvHint => '寫入系統簡訊庫（需設為預設）';

  @override
  String get multiSelect => '多選';

  @override
  String simTime(int sim, String time) {
    return '卡$sim · $time';
  }

  @override
  String simBadge(int sim) {
    return '卡$sim';
  }

  @override
  String get sameAddressSms => '同號簡訊';

  @override
  String get sameAddressHint => '只看這個號碼的全部簡訊';

  @override
  String get sameSimSms => '同卡簡訊';

  @override
  String get copyAddress => '複製號碼';

  @override
  String get copiedAddress => '已複製號碼';

  @override
  String get copyBody => '複製內文';

  @override
  String get copiedBody => '已複製內文';

  @override
  String get delete => '刪除';

  @override
  String get deleteOneHint => '刪除這一則，刪除前確認';

  @override
  String get hideFromList => '移出清單';

  @override
  String get hideFromListHint => '僅本機隱藏；懸浮球刪除不會帶上它們';

  @override
  String get miuiBanner => '可能還看不到 10086 等通知簡訊，點此開啟 MIUI「通知類簡訊」';

  @override
  String get partialQueryBanner => '部分簡訊可能未載入';

  @override
  String get partialQueryBannerHint => '點此重試';

  @override
  String get dismissHint => '不再提示';

  @override
  String get miuiGuideTitle => '還要開啟「通知類簡訊」';

  @override
  String get miuiGuideBody =>
      'MIUI 將 10086、銀行等通知簡訊單獨管控。請在下一頁開啟：權限管理 → 其他權限 → 通知類簡訊。';

  @override
  String get openMiuiNotifSms => '去開啟通知類簡訊';

  @override
  String get later => '稍後再說';

  @override
  String get stillNoPermission => '仍未取得權限，可到系統設定開啟';

  @override
  String get smsReadable => '已可讀取簡訊';

  @override
  String get openMiuiPermFailed => '開啟 MIUI 權限頁失敗';

  @override
  String get sectionAppearance => '外觀';

  @override
  String get themeColor => '主題色';

  @override
  String get darkMode => '深色模式';

  @override
  String get themeSystem => '跟隨系統';

  @override
  String get themeLight => '淺色';

  @override
  String get themeDark => '深色';

  @override
  String get sectionPermissions => '權限';

  @override
  String get smsPermission => '簡訊權限';

  @override
  String get smsPermissionGranted => '已授予 · 用於讀取與匯出';

  @override
  String get smsPermissionDenied => '未授予 · 點擊查看與申請';

  @override
  String get checking => '檢查中…';

  @override
  String get defaultSmsApp => '預設簡訊應用程式';

  @override
  String get defaultSmsIsThisApp => '本應用程式 · 點擊可還原系統簡訊';

  @override
  String get defaultSmsNotThisApp => '非本應用程式 · 點擊設為預設（刪除需要）';

  @override
  String get autoRepair => '一鍵檢查並修復';

  @override
  String get autoRepairHint => '依序申請讀取權限、設為預設簡訊';

  @override
  String get sectionData => '資料';

  @override
  String get exportSmsCsv => '匯出簡訊 CSV';

  @override
  String get exporting => '匯出中…';

  @override
  String get exportSmsHint => '匯出全部簡訊到檔案並分享';

  @override
  String get importSmsCsv => '匯入簡訊 CSV';

  @override
  String get importing => '匯入中…';

  @override
  String get importSmsHint => '只新增入庫，需設為預設簡訊應用程式';

  @override
  String get resetHiddenList => '重設本機隱藏清單';

  @override
  String get noHidden => '暫無已移出的簡訊';

  @override
  String hiddenCountLabel(int count) {
    return '已移出 $count 則，重設後重新顯示';
  }

  @override
  String get sectionAbout => '關於';

  @override
  String get version => '版本';

  @override
  String get privacy => '隱私說明';

  @override
  String get privacyHint => '資料僅在本機處理';

  @override
  String get privacyToast => '資料僅在本機處理，不上傳、不收集';

  @override
  String get footerTagline => '簡訊清理 · 本機工具';

  @override
  String get deleteAvailable => '刪除簡訊功能可用';

  @override
  String get restoreSystemSms => '還原為系統簡訊';

  @override
  String get restoreSystemSmsHint => '開啟系統「預設應用程式」設定，手動選擇「訊息」';

  @override
  String get keepAsIs => '保持現狀';

  @override
  String get openedDefaultSettingsPickOther => '已開啟系統預設應用程式設定，請選擇其他簡訊應用程式';

  @override
  String get notDefaultNow => '目前不是預設簡訊應用程式';

  @override
  String get openSettingsFailed => '開啟設定失敗';

  @override
  String get openedDefaultSettings => '已開啟系統預設應用程式設定';

  @override
  String get autoRepairReady => '已就緒：可讀可刪';

  @override
  String get autoRepairIncomplete => '仍有項目未就緒，請檢查上方狀態';

  @override
  String get hiddenListReset => '已重設本機隱藏清單';

  @override
  String get refreshStatus => '重新整理狀態';

  @override
  String get readSms => '讀取簡訊';

  @override
  String get readGrantedAppOps => '已授予 · AppOps 正常';

  @override
  String get readDeniedList => '未授予 · 無法讀取簡訊清單';

  @override
  String get defaultSmsDeleteOk => '本應用程式 · 刪除功能可用';

  @override
  String get defaultSmsDeleteNeed => '非本應用程式 · 刪除簡訊需要設為預設';

  @override
  String get miuiNotifSms => 'MIUI 通知類簡訊';

  @override
  String get miuiNotifAllowed => '已允許 · 通知類簡訊可見';

  @override
  String get miuiNotifLikelyOff => '可能未開通 · 10086 等可能讀不到';

  @override
  String get miuiNotifOff => '未開通 · 只能讀到點對點簡訊';

  @override
  String get miuiNotifSuggest => 'MIUI 附加權限 · 建議開通';

  @override
  String get permExplainMiui =>
      '讀取與刪除相互獨立：讀清單只需簡訊權限；刪除必須是預設簡訊應用程式。MIUI 額外有「通知類簡訊」開關，不開通時 10086/銀行等通知類會讀不到。在系統中改掉預設簡訊後，系統可能同時收回讀取權限，回到本頁重新申請即可。';

  @override
  String get permExplain =>
      '讀取與刪除相互獨立：讀清單只需簡訊權限；刪除必須是預設簡訊應用程式。在系統中改掉預設簡訊後，系統可能同時收回讀取權限，回到本頁重新申請即可。';

  @override
  String get setDefaultSms => '設為預設簡訊應用程式';

  @override
  String get openMiuiNotifSmsBtn => '開啟 MIUI 通知類簡訊';

  @override
  String get miuiPath => '路徑：應用程式資訊 → 權限管理 → 其他權限 → 通知類簡訊';

  @override
  String get openAppSettings => '開啟應用程式設定';

  @override
  String get openDefaultSmsSettings => '開啟系統預設應用程式設定';

  @override
  String get openAppSettingsFailed => '開啟應用程式設定失敗';

  @override
  String get openDefaultSettingsFailed => '開啟預設應用程式設定失敗';

  @override
  String get themeHint => '選擇強調色，立即作用於主按鈕、所選項目與圖示。';

  @override
  String get preset => '預設';

  @override
  String get custom => '自訂';

  @override
  String get colorValue => '顏色值';

  @override
  String get invalidColor => '請輸入合法顏色值，如 #2BAE67';

  @override
  String get applyCustomColor => '套用自訂顏色';

  @override
  String get preview => '預覽';

  @override
  String get primaryButtonSample => '主按鈕範例';

  @override
  String get filterChipSample => '篩選 Chip';

  @override
  String get sameAddressSample => '同號 10086';

  @override
  String get seedGreen => '綠';

  @override
  String get seedBlue => '藍';

  @override
  String get seedPurple => '紫';

  @override
  String get seedOrange => '橙';

  @override
  String get seedRed => '紅';

  @override
  String get seedCyan => '青';

  @override
  String get seedPink => '粉';

  @override
  String get seedGraphite => '石墨';

  @override
  String get dayUnknown => '未知';

  @override
  String get dayToday => '今天';

  @override
  String get dayYesterday => '昨天';

  @override
  String get exportFailedRetry => '匯出失敗，請重試';

  @override
  String get exportEmpty => '沒有可匯出的簡訊';

  @override
  String exportedShareText(int count) {
    return '已匯出 $count 則簡訊';
  }

  @override
  String get importCancelled => '已取消匯入';

  @override
  String get importReadFailed => '讀取檔案失敗';

  @override
  String get importEmptyFile => '檔案中沒有可匯入的簡訊';

  @override
  String get importUnknown => '未知錯誤';

  @override
  String get importNeedDefault => '匯入需先設為預設簡訊應用程式';

  @override
  String get importFailedRetry => '匯入失敗，請重試';

  @override
  String importFailedWith(String error) {
    return '匯入失敗：$error';
  }

  @override
  String importedPartial(int inserted, int parsed, int failed) {
    return '已匯入 $inserted / $parsed 則（$failed 則失敗）';
  }

  @override
  String importedAll(int inserted, int parsed) {
    return '已匯入 $inserted / $parsed 則';
  }

  @override
  String errorSummaryMore(int count) {
    return ' 等 $count 則';
  }

  @override
  String get errorSummarySeparator => '；';

  @override
  String get insertErrNotDefault => '非預設簡訊應用程式';

  @override
  String get insertErrFailed => '寫入失敗';

  @override
  String get insertErrInvalid => '資料格式非法';

  @override
  String get insertErrUnknown => '未知錯誤';

  @override
  String get deleteErrNotDefault => '非預設簡訊應用程式';

  @override
  String get deleteErrFailed => '刪除失敗';

  @override
  String get deleteErrUnknown => '未知錯誤';

  @override
  String get language => '語言';

  @override
  String get languageSystem => '跟隨系統';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageZhTw => '繁體中文';

  @override
  String get languageEn => 'English';

  @override
  String get openSourceLicenses => '開源許可';

  @override
  String get openSourceLicensesHint => '第三方元件與授權條款';

  @override
  String get feedback => '問題回饋';

  @override
  String get feedbackHint => 'GitHub Issues';

  @override
  String get feedbackOpenFailed => '無法開啟瀏覽器，請手動造訪專案倉庫';

  @override
  String get privacyDialogTitle => '隱私說明';

  @override
  String get privacyDialogBody =>
      '簡訊內容僅用於本機顯示、篩選與匯出；無網路上傳，無統計回報。刪除不可復原，請在操作前確認。';

  @override
  String get defaultSmsMmsWarnTitle => '多媒體簡訊接收有限制';

  @override
  String get defaultSmsMmsWarnBody =>
      '作為預設簡訊應用程式時，新多媒體簡訊只入庫發件人/時間/主題，不下載完整內文與附件。需要完整多媒體簡訊請改回系統「訊息」接收。';

  @override
  String get aboutMmsReceiveTitle => '多媒體簡訊接收說明';

  @override
  String get aboutMmsReceiveBody =>
      '瀏覽/篩選/刪除/匯出系統庫中的多媒體簡訊。本應用程式為預設時，新多媒體簡訊僅入庫中繼資料骨架，不下載完整內文。';
}
