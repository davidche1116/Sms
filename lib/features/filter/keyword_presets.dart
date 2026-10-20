import 'dart:ui' show Locale;

import '../../generated/app_localizations.dart';

/// 常见短信类别预设：一个预设展开成一组关键词，组内 **OR** 匹配（任一命中即可）。
///
/// 单个关键词表达不了「银行通知」这类语义（银行 / 信用卡 / 尾号 / 账单…），
/// 所以走 `keywords` 列表下推给原生 SQL，而不是退化成客户端全量过滤。
enum SmsKeywordPreset { verification, carrier, bank, ecommerce, promo }

/// 选词原则：只收**强特征词**。
///
/// 反例：「支付」「订单」这类泛词会把支付宝 / 微信、个人聊天一并捞进来，
/// 造成类别互相污染，已刻意避开。
const Map<SmsKeywordPreset, List<String>> _zh = {
  SmsKeywordPreset.verification: [
    '验证码',
    '校验码',
    '动态码',
    '动态密码',
    '一次性密码',
    '验证代码',
    '安全码',
    'OTP',
  ],
  SmsKeywordPreset.carrier: [
    '中国移动',
    '中国联通',
    '中国电信',
    '10086',
    '10010',
    '10000',
    '流量',
    '话费',
    '套餐',
    '积分',
    '停机',
    '宽带',
    '增值业务',
    '国际漫游',
  ],
  SmsKeywordPreset.bank: [
    '银行',
    '信用卡',
    '借记卡',
    '储蓄卡',
    '尾号',
    '余额',
    '账户',
    '转账',
    '到账',
    '扣款',
    '还款',
    '账单',
    '额度',
    '分期',
    '取现',
    'ATM',
    '网银',
  ],
  SmsKeywordPreset.ecommerce: [
    '快递',
    '物流',
    '运单',
    '签收',
    '派送',
    '揽收',
    '菜鸟',
    '丰巢',
    '驿站',
    '取件码',
    '京东',
    '淘宝',
    '天猫',
    '拼多多',
    '唯品会',
    '苏宁',
    '订单号',
  ],
  SmsKeywordPreset.promo: [
    '优惠券',
    '限时',
    '秒杀',
    '立减',
    '满减',
    '返现',
    '免费领',
    '专享',
    '爆款',
    '大促',
    '活动价',
    '退订',
    '回T退订',
    'TD退订',
  ],
};

const Map<SmsKeywordPreset, List<String>> _zhHant = {
  SmsKeywordPreset.verification: [
    '驗證碼',
    '驗證代碼',
    '動態碼',
    '動態密碼',
    '一次性密碼',
    '安全碼',
    'OTP',
  ],
  SmsKeywordPreset.carrier: [
    '中華電信',
    '台灣大哥大',
    '遠傳電信',
    '台灣之星',
    '亞太電信',
    '流量',
    '資費',
    '通話費',
    '月租費',
    '積分',
    '停機',
    '寬頻',
    '漫遊',
  ],
  SmsKeywordPreset.bank: [
    '銀行',
    '信用卡',
    '金融卡',
    '帳戶',
    '餘額',
    '轉帳',
    '入帳',
    '扣款',
    '還款',
    '帳單',
    '額度',
    '分期',
    '提款',
    'ATM',
    '網銀',
  ],
  SmsKeywordPreset.ecommerce: [
    '宅配',
    '物流',
    '貨運',
    '取件',
    '簽收',
    '配送',
    '超商',
    '取貨',
    '蝦皮',
    'momo',
    'PChome',
    '訂單',
    '出貨',
    '取件碼',
  ],
  SmsKeywordPreset.promo: [
    '優惠券',
    '限時',
    '秒殺',
    '現折',
    '滿額',
    '折價',
    '免運',
    '好禮',
    '專屬',
    '活動價',
    '退訂',
  ],
};

/// 英文界面同样保留高频中文词：英文用户收到的国内短信仍然是中文。
const Map<SmsKeywordPreset, List<String>> _en = {
  SmsKeywordPreset.verification: [
    'verification code',
    'verify code',
    'one-time',
    'one time password',
    'security code',
    'passcode',
    'OTP',
    '验证码',
    '驗證碼',
  ],
  SmsKeywordPreset.carrier: [
    'china mobile',
    'china unicom',
    'china telecom',
    '10086',
    '10010',
    '10000',
    'data usage',
    'data balance',
    'recharge',
    'top-up',
    'plan',
    '流量',
    '话费',
  ],
  SmsKeywordPreset.bank: [
    'bank',
    'credit card',
    'debit card',
    'card ending',
    'balance',
    'transaction',
    'deposit',
    'withdrawal',
    'statement',
    'due date',
    '银行',
    '信用卡',
    '余额',
  ],
  SmsKeywordPreset.ecommerce: [
    'delivery',
    'tracking',
    'shipped',
    'shipment',
    'out for delivery',
    'parcel',
    'courier',
    'pickup code',
    'JD',
    'Taobao',
    '快递',
    '物流',
    '签收',
  ],
  SmsKeywordPreset.promo: [
    'discount',
    'coupon',
    'promo',
    'limited time',
    'sale ends',
    'save now',
    'unsubscribe',
    '优惠',
    '促销',
  ],
};

/// 关键词表按界面语言切换（arb 不支持 List 类型，词表只能落在 Dart 侧）。
String _langKey(Locale? locale) {
  if (locale == null || locale.languageCode != 'zh') return 'en';
  final script = locale.scriptCode;
  final country = locale.countryCode;
  if (script == 'Hant' ||
      country == 'TW' ||
      country == 'HK' ||
      country == 'MO') {
    return 'zh_Hant';
  }
  return 'zh';
}

/// 取 [preset] 在 [locale] 下的关键词组；未命中返回空组（等价于不筛选）。
List<String> presetKeywords(SmsKeywordPreset preset, Locale? locale) {
  final table = switch (_langKey(locale)) {
    'zh' => _zh,
    'zh_Hant' => _zhHant,
    _ => _en,
  };
  return table[preset] ?? const <String>[];
}

/// Chip / 按钮文案（显示名走 l10n）。
String presetLabel(AppLocalizations l10n, SmsKeywordPreset preset) {
  return switch (preset) {
    SmsKeywordPreset.verification => l10n.presetVerification,
    SmsKeywordPreset.carrier => l10n.presetCarrier,
    SmsKeywordPreset.bank => l10n.presetBank,
    SmsKeywordPreset.ecommerce => l10n.presetEcommerce,
    SmsKeywordPreset.promo => l10n.presetPromo,
  };
}
