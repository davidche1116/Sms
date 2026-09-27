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
  String get cancel => '取消';

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
}
