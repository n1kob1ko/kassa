// ignore_for_file: deprecated_member_use

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class L10nZh extends L10n {
  L10nZh([String locale = 'zh']) : super(locale);

  @override
  String get languageSectionTitle => '语言';

  @override
  String get languageSheetTitle => '语言';

  @override
  String get languageChangeLabel => '更改语言';

  @override
  String get loginTitle => '输入 PIN';

  @override
  String get loginHint => '每人都有自己的 PIN';

  @override
  String get loginWrongPin => '此 PIN 不存在。';

  @override
  String get loginFailed => '未成功，请重试。';

  @override
  String loginDigitsEntered(int filled) {
    return '已输入 $filled/4 位';
  }

  @override
  String get shellTabKassa => '收银';

  @override
  String get shellTabBons => '小票记录';

  @override
  String get shellTabOverview => '概览';

  @override
  String get shellTabItems => '商品';

  @override
  String get shellTabClose => '结算';

  @override
  String get shellOffline => '无网络。现金收款照常进行。';

  @override
  String shellSwitchStaff(String name) {
    return '切换员工，当前登录：$name';
  }

  @override
  String get shellSettings => '设置';

  @override
  String get uiUndo => '撤销';

  @override
  String get uiKeypadComma => '逗号';

  @override
  String get uiKeypadDot => '点';

  @override
  String get uiKeypadDelete => '删除最后一位';

  @override
  String get uiReceiptQr => '小票二维码';

  @override
  String get uiListSeparator => '、';

  @override
  String kassaItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件商品',
    );
    return '$_temp0';
  }

  @override
  String kassaCategoryLabel(String name, String items) {
    return '$name，$items';
  }

  @override
  String get kassaFavorites => '常用';

  @override
  String get kassaWithImages => '带图片';

  @override
  String get kassaCompact => '紧凑';

  @override
  String get kassaPlusDeposit => '+ 押金';

  @override
  String get kassaNotForSale => '暂停销售';

  @override
  String kassaOnReceipt(int count) {
    return '小票上 $count 件';
  }

  @override
  String get kassaTagVegan => '纯素';

  @override
  String get kassaTagSpicy => '辣';

  @override
  String kassaOneLess(String name) {
    return '减一份：$name';
  }

  @override
  String kassaOneMore(String name) {
    return '加一份：$name';
  }

  @override
  String get kassaReceipt => '小票';

  @override
  String get kassaClearCart => '清空小票';

  @override
  String get kassaCartCleared => '小票已清空';

  @override
  String get kassaEmptyTitle => '还没有商品';

  @override
  String get kassaEmptyHint => '点击商品，每点一次就加一份到小票。';

  @override
  String get kassaTotal => '合计';

  @override
  String kassaDepositIncluded(String amount) {
    return '含押金 $amount';
  }

  @override
  String kassaTaxIncluded(String amount) {
    return '含增值税 $amount';
  }

  @override
  String get kassaCash => '现金';

  @override
  String get kassaCard => '刷卡';

  @override
  String get kassaCardNotSetUp => '未设置';

  @override
  String get kassaCardLoggedOut => '未登录';

  @override
  String get kassaCardNoInternet => '无网络';

  @override
  String kassaCardFrom(String amount) {
    return '$amount 起';
  }

  @override
  String get kassaCancel => '取消';

  @override
  String get kassaAddToReceipt => '加入小票';

  @override
  String kassaStillToChoose(String groups) {
    return '还需选择：$groups';
  }

  @override
  String get kassaPickOne => '单选';

  @override
  String get kassaAtMostOne => '最多一项';

  @override
  String kassaAtLeast(int min) {
    return '至少 $min 项';
  }

  @override
  String kassaUpTo(int max) {
    return '最多 $max 项';
  }

  @override
  String get kassaPleaseChoose => '请选择';

  @override
  String kassaChosenCount(int count) {
    return '已选 $count 项';
  }

  @override
  String kassaOptionChosen(String name) {
    return '$name，已选';
  }

  @override
  String get kassaPayCashTitle => '现金付款';

  @override
  String get kassaBackToReceipt => '返回小票';

  @override
  String get kassaAmountDue => '应付';

  @override
  String get kassaGiven => '实收';

  @override
  String get kassaExact => '正好';

  @override
  String get kassaOtherAmount => '其他金额';

  @override
  String get kassaShowSuggestions => '显示建议金额';

  @override
  String get kassaStillMissing => '还差';

  @override
  String get kassaChange => '找零';

  @override
  String get kassaSaveFailed => '小票未能保存，请重试。';

  @override
  String get kassaFinish => '完成';

  @override
  String get kassaFinishAndPrint => '完成并打印小票';

  @override
  String get kassaWaitingForCard => '等待刷卡';

  @override
  String get kassaCardHint => '请顾客将卡或手机靠近读卡器。';

  @override
  String get kassaPaid => '已付款';

  @override
  String kassaReceiptNumber(int number) {
    return '小票号 $number';
  }

  @override
  String get kassaPaidExact => '金额正好';

  @override
  String get kassaGiveChange => '请找零';

  @override
  String get kassaGiveChangeFromDrawer => '请从钱箱找零';

  @override
  String get kassaPaidByCard => '已刷卡付款';

  @override
  String get kassaNextCustomer => '下一位顾客';

  @override
  String get kassaPrinting => '正在打印小票…';

  @override
  String get kassaPrinted => '小票已打印';

  @override
  String get kassaPrintAgain => '重新打印';

  @override
  String get cardAlreadyRunning => '已有一笔刷卡付款正在进行。';

  @override
  String get cardEmptyReceipt => '小票是空的。';

  @override
  String cardMinimum(String amount) {
    return '刷卡最低金额为 $amount。';
  }

  @override
  String get cardNotStarted => '无法开始刷卡付款。';

  @override
  String get cardDeclined => '刷卡付款未完成。';

  @override
  String get cardCancelled => '刷卡付款已取消。';

  @override
  String get cardNoInternet => '无网络，暂时无法刷卡。';

  @override
  String get cardNotLoggedIn => 'SumUp 未登录，请在设置中登录。';

  @override
  String get cardNoReader => '未连接读卡器，请在设置中连接。';

  @override
  String get cardPermission => 'Kassa 需要蓝牙和位置权限。';

  @override
  String get cardFailed => '刷卡付款失败。';

  @override
  String cardFailedDetail(String detail) {
    return '刷卡付款失败。（$detail）';
  }

  @override
  String get printNotSetUp => '未设置小票打印机。';

  @override
  String get printUnreachable => '打印机未就绪。是否已开机并连接？';

  @override
  String get printNoPermission => 'Kassa 无权使用打印机，请授予权限。';

  @override
  String get printPaperOut => '打印机未就绪。纸已用完。';

  @override
  String get printCoverOpen => '打印机未就绪。机盖未关。';

  @override
  String get printTimeout => '打印机未就绪。没有响应。';

  @override
  String outageTitle(String since) {
    return '签名自 $since 起中断';
  }

  @override
  String get outageSellOn => '可以照常继续销售。';

  @override
  String get outageKeepsWorking => 'Kassa 照常运行。请告知店长。';

  @override
  String get outageRejected => 'A-Trust 拒绝了登录信息。请叫店长来。';

  @override
  String get outageNotYet => '仍未恢复。';

  @override
  String get outageBack => '签名已恢复。';

  @override
  String get outageRetry => '重新检查';

  @override
  String get outageRepin => '重新输入 PIN';

  @override
  String get unclearTitle => '这笔刷卡付款成功了吗？';

  @override
  String unclearStarted(String time, String name) {
    return '$name 于 $time 发起';
  }

  @override
  String unclearMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '还有 $count 项',
    );
    return '$_temp0';
  }

  @override
  String unclearNoAnswer(String amount, String time) {
    return 'Kassa 没有收到 SumUp 的回复。请在 SumUp 应用的“销售”中查看 $time 的 $amount 是否已到账。';
  }

  @override
  String get unclearUnreadable =>
      '菜单已更改，小票无法再重建。请选择“否”。如果款项已到 SumUp，请在 SumUp 应用中退款并重新收款。';

  @override
  String get unclearFailed => '未成功，请重试。';

  @override
  String get unclearYes => '是，已到账';

  @override
  String get unclearNo => '否，未到账';

  @override
  String get unclearEffectPaidPrint => 'Kassa 将小票记为刷卡付款并打印。';

  @override
  String get unclearEffectPaid => 'Kassa 将小票记为刷卡付款。';

  @override
  String get unclearEffectRestore => 'Kassa 放弃这笔付款，并把商品放回小票。';

  @override
  String get unclearEffectDiscard => 'Kassa 放弃这笔付款。当前小票保持不变。';

  @override
  String get unclearConfirm => '确认';

  @override
  String get unclearBack => '返回';

  @override
  String get dateMonthJanuary => '1月';

  @override
  String get dateMonthFebruary => '2月';

  @override
  String get dateMonthMarch => '3月';

  @override
  String get dateMonthApril => '4月';

  @override
  String get dateMonthMay => '5月';

  @override
  String get dateMonthJune => '6月';

  @override
  String get dateMonthJuly => '7月';

  @override
  String get dateMonthAugust => '8月';

  @override
  String get dateMonthSeptember => '9月';

  @override
  String get dateMonthOctober => '10月';

  @override
  String get dateMonthNovember => '11月';

  @override
  String get dateMonthDecember => '12月';

  @override
  String get dateWeekdayMonday => '星期一';

  @override
  String get dateWeekdayTuesday => '星期二';

  @override
  String get dateWeekdayWednesday => '星期三';

  @override
  String get dateWeekdayThursday => '星期四';

  @override
  String get dateWeekdayFriday => '星期五';

  @override
  String get dateWeekdaySaturday => '星期六';

  @override
  String get dateWeekdaySunday => '星期日';

  @override
  String get dateWeekdayShortMonday => '周一';

  @override
  String get dateWeekdayShortTuesday => '周二';

  @override
  String get dateWeekdayShortWednesday => '周三';

  @override
  String get dateWeekdayShortThursday => '周四';

  @override
  String get dateWeekdayShortFriday => '周五';

  @override
  String get dateWeekdayShortSaturday => '周六';

  @override
  String get dateWeekdayShortSunday => '周日';

  @override
  String dateWeekdayDayMonth(String weekday, int day, String month) {
    return '$month$day日 $weekday';
  }

  @override
  String get bonsTitle => '小票记录';

  @override
  String bonsToday(String day) {
    return '今天，$day';
  }

  @override
  String bonsDayLabel(String weekday, int day, String month) {
    return '$month$day日 $weekday';
  }

  @override
  String get bonsNoneToday => '今天还没有小票。';

  @override
  String get bonsNoneForFilter => '没有符合此筛选的小票。';

  @override
  String get bonsFilterAll => '全部';

  @override
  String get bonsCash => '现金';

  @override
  String get bonsCard => '刷卡';

  @override
  String get bonsCashAndCard => '现金 + 刷卡';

  @override
  String get bonsVoided => '已作废';

  @override
  String get bonsVoidReceipt => '作废单';

  @override
  String get bonsKindStart => '启用小票';

  @override
  String get bonsKindMonth => '月度小票';

  @override
  String get bonsKindYear => '年度小票';

  @override
  String get bonsKindZero => '零元小票';

  @override
  String get bonsKindCollective => '汇总小票';

  @override
  String get bonsKindClosing => '终止小票';

  @override
  String bonsNumberShort(int number) {
    return '$number 号';
  }

  @override
  String get bonsPrint => '打印';

  @override
  String get bonsVoid => '作废';

  @override
  String get bonsNothingSelected => '点按一张小票即可查看。';

  @override
  String bonsTime(String time) {
    return '$time';
  }

  @override
  String get bonsDeposit => '押金';

  @override
  String bonsTaxRate(int percent) {
    return '增值税 $percent %';
  }

  @override
  String get bonsPayment => '付款方式';

  @override
  String bonsVoidOf(String number) {
    return '作废 $number 号小票';
  }

  @override
  String bonsVoidedBy(String name) {
    return '作废人：$name';
  }

  @override
  String bonsCreatedBy(String name) {
    return '创建人：$name';
  }

  @override
  String bonsRungUpBy(String name) {
    return '收银员：$name';
  }

  @override
  String get bonsVoidedNotCounted => '已作废。此小票不计入营业额。';

  @override
  String bonsVoidedByNotCounted(String name) {
    return '由 $name 作废。此小票不计入营业额。';
  }

  @override
  String bonsCashBoxId(String id) {
    return '收银机编号 $id';
  }

  @override
  String get bonsTestReceipt => '测试小票';

  @override
  String get bonsDeviceFailed => '安全装置故障';

  @override
  String get bonsProbeSignature => '带试用签名的测试小票。';

  @override
  String get bonsQrOnPaper => '打印的小票上也有二维码。';

  @override
  String get bonsVoidFailed => '作废未能保存。请重试。';

  @override
  String get bonsVoidOlderThanProbe => '此小票早于试用签名，无法作废。';

  @override
  String get bonsVoidFromTestTime => '此小票来自测试期，无法作废。';

  @override
  String bonsVoidQuestion(int number) {
    return '确定作废小票号 $number？';
  }

  @override
  String bonsVoidCashBack(String amount) {
    return '请退还现金 $amount。';
  }

  @override
  String get bonsVoidCardHint => '款项不会自动退回。请在 SumUp 应用中退款。';

  @override
  String get bonsVoidConfirmCard => '作废，我会在 SumUp 中退款';

  @override
  String get bonsVoidConfirm => '确定作废';

  @override
  String get itemsTitle => '商品';

  @override
  String get itemsWithChoice => '含选项';

  @override
  String itemsPlusDeposit(String amount) {
    return '另加押金 $amount';
  }

  @override
  String get itemsColumnItem => '商品';

  @override
  String get itemsPrice => '价格';

  @override
  String get itemsFavorite => '收藏';

  @override
  String get itemsInSale => '在售';

  @override
  String itemsFavoriteRemove(String name) {
    return '将 $name 移出收藏';
  }

  @override
  String itemsFavoriteAdd(String name) {
    return '将 $name 加入收藏';
  }

  @override
  String itemsInSaleLabel(String name) {
    return '$name 在售';
  }

  @override
  String get itemsChangePrice => '修改价格';

  @override
  String itemsDepositToggle(String amount) {
    return '押金 $amount';
  }

  @override
  String get itemsVegan => '纯素';

  @override
  String get itemsSpicy => '辣';

  @override
  String get itemsTaxRate => '税率';

  @override
  String get itemsChoiceWhenRinging => '点单时的选项';

  @override
  String itemsChoiceGroups(String groups) {
    return '$groups。';
  }

  @override
  String get itemsFromMenuFile => '名称、照片和新商品来自菜单文件。';

  @override
  String get itemsWriteFailed => '未成功，请重试。';

  @override
  String itemsNewPrice(String amount) {
    return '新价格，原价 $amount';
  }

  @override
  String get itemsApply => '确定';

  @override
  String get overviewTitle => '概览';

  @override
  String get overviewRangeToday => '今天';

  @override
  String get overviewRange7 => '7 天';

  @override
  String get overviewRange30 => '30 天';

  @override
  String get overviewLast7 => '最近 7 天';

  @override
  String get overviewLast30 => '最近 30 天';

  @override
  String overviewHourRange(int from, int to) {
    return '$from:00–$to:00';
  }

  @override
  String overviewSameAsWeekday(String weekday) {
    return '与上$weekday持平';
  }

  @override
  String overviewMoreThanWeekday(int percent, String weekday) {
    return '比上$weekday多 $percent %';
  }

  @override
  String overviewLessThanWeekday(int percent, String weekday) {
    return '比上$weekday少 $percent %';
  }

  @override
  String overviewSameAsDaysBefore(int days) {
    return '与前 $days 天持平';
  }

  @override
  String overviewMoreThanDaysBefore(int percent, int days) {
    return '比前 $days 天多 $percent %';
  }

  @override
  String overviewLessThanDaysBefore(int percent, int days) {
    return '比前 $days 天少 $percent %';
  }

  @override
  String get overviewRevenue => '营业额';

  @override
  String get overviewReceipts => '小票';

  @override
  String get overviewPerReceipt => '每张小票';

  @override
  String get overviewVoids => '作废';

  @override
  String get overviewPerHour => '每小时营业额';

  @override
  String get overviewPerDay => '每日营业额';

  @override
  String get overviewNoneInRange => '此期间还没有小票。';

  @override
  String overviewBarLabel(String label, String amount) {
    return '$label，$amount';
  }

  @override
  String get overviewLoadFailed => '无法加载数据。';

  @override
  String get overviewRetry => '重试';

  @override
  String get overviewPayments => '付款方式';

  @override
  String get overviewNoReceipts => '还没有小票。';

  @override
  String get overviewTopItems => '畅销商品';

  @override
  String get overviewByCategory => '按分类';

  @override
  String closeClockTime(String time) {
    return '$time';
  }

  @override
  String closeBonCount(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted 张小票',
    );
    return '$_temp0';
  }

  @override
  String get closeReasonBank => '银行';

  @override
  String get closeReasonPurchase => '采购';

  @override
  String get closeReasonChange => '备用零钱';

  @override
  String get closeReasonOther => '其他';

  @override
  String get closeCashIn => '存入现金';

  @override
  String get closeCashOut => '取出现金';

  @override
  String get closeCloseSheet => '关闭';

  @override
  String get closeAmount => '金额';

  @override
  String get closeReason => '原因';

  @override
  String get closeSaveCashIn => '确认存入';

  @override
  String get closeSaveCashOut => '确认取出';

  @override
  String get closeFloatTitle => '备用零钱';

  @override
  String get closeFloatQuestionDrawer => '今早钱箱里有多少备用零钱？';

  @override
  String get closeFloatQuestion => '今早有多少备用零钱？';

  @override
  String get closeSaveFloat => '保存备用零钱';

  @override
  String get closeNothingTyped => '尚未输入';

  @override
  String get closeExact => '完全一致';

  @override
  String get closeMissing => '短缺';

  @override
  String get closeTooMuchDrawer => '钱箱多出';

  @override
  String get closeTooMuchCash => '现金多出';

  @override
  String get closeCountDrawer => '清点钱箱';

  @override
  String get closeCountCash => '清点现金';

  @override
  String closeStep(int step, int total) {
    return '第 $step 步，共 $total 步';
  }

  @override
  String get closeExpectedDrawer => '钱箱应有';

  @override
  String get closeExpectedCash => '现金应有';

  @override
  String get closeCounted => '清点金额';

  @override
  String get closeNext => '下一步';

  @override
  String get closeLeaveInDrawer => '留在钱箱';

  @override
  String get closeFloatForTomorrow => '明天的备用零钱';

  @override
  String get closeDifferenceToExpected => '与应有差额';

  @override
  String get closeLeaveQuestionDrawer => '留多少备用零钱在钱箱里？';

  @override
  String get closeLeaveQuestion => '留多少备用零钱？';

  @override
  String get closeMoreThanCounted => '留存金额不能超过清点金额。';

  @override
  String get closeYouTakeOut => '取出';

  @override
  String get closeBack => '返回';

  @override
  String get closeCloseDay => '完成日结';

  @override
  String get closeDayClosed => '已日结';

  @override
  String get closeDayIsClosed => '今日已完成日结。';

  @override
  String get closeNoOpenDay => '没有未结的营业日。';

  @override
  String get closeNextDayStarts => '下一个营业日从第一张小票开始。';

  @override
  String closeTakenOut(String amount) {
    return '已取出：$amount';
  }

  @override
  String closeTomorrowDrawer(String amount) {
    return '明天钱箱里有 $amount 备用零钱。';
  }

  @override
  String closeTomorrow(String amount) {
    return '明天有 $amount 备用零钱。';
  }

  @override
  String closeClosedBy(String name, String time) {
    return '$name 于 $time 完成日结';
  }

  @override
  String get closePrintReport => '打印报表';

  @override
  String get closeToKassa => '返回收银';

  @override
  String get closeReportPrinted => '报表已打印。';

  @override
  String get closeTitle => '日结';

  @override
  String get closeDay => '日';

  @override
  String get closeMonth => '月';

  @override
  String get closeClosedPill => '已日结';

  @override
  String get closeLoadFailed => '未成功，请重新打开此页面。';

  @override
  String get closeDrawer => '钱箱';

  @override
  String get closeCash => '现金';

  @override
  String get closeFloatMorning => '今早备用零钱';

  @override
  String get closeStillOpen => '待定';

  @override
  String get closeCashTakings => '现金收入';

  @override
  String closeDeposited(String reason) {
    return '存入：$reason';
  }

  @override
  String closeWithdrawn(String reason) {
    return '取出：$reason';
  }

  @override
  String get closeDifference => '差额';

  @override
  String get closeIncome => '收入';

  @override
  String get closeTotal => '合计';

  @override
  String get closeTax => '税';

  @override
  String get closeRevenue => '营业额';

  @override
  String get closeOfWhichVat => '其中增值税';

  @override
  String closeVatRate(int percent) {
    return '增值税 $percent %';
  }

  @override
  String get closeDepositNoVat => '押金，不含增值税';

  @override
  String get closeForgotten => '上一个营业日尚未日结。';

  @override
  String get closeNow => '立即日结';

  @override
  String get dateMonthShortJanuary => '1月';

  @override
  String get dateMonthShortFebruary => '2月';

  @override
  String get dateMonthShortMarch => '3月';

  @override
  String get dateMonthShortApril => '4月';

  @override
  String get dateMonthShortMay => '5月';

  @override
  String get dateMonthShortJune => '6月';

  @override
  String get dateMonthShortJuly => '7月';

  @override
  String get dateMonthShortAugust => '8月';

  @override
  String get dateMonthShortSeptember => '9月';

  @override
  String get dateMonthShortOctober => '10月';

  @override
  String get dateMonthShortNovember => '11月';

  @override
  String get dateMonthShortDecember => '12月';

  @override
  String closeMonthYear(String month, int year) {
    return '$year年$month';
  }

  @override
  String closePeriodSameYear(String from, String to, int year) {
    return '$year年$from至$to';
  }

  @override
  String closePeriodTwoYears(String from, String to) {
    return '$from至$to';
  }

  @override
  String closePeriodDates(String from, String to) {
    return '$from 至 $to';
  }

  @override
  String get closeMonthlyReport => '月度结算';

  @override
  String get closeReport => '结算';

  @override
  String get closePeriod => '期间';

  @override
  String closeFirstMonthlyReport(String date) {
    return '首份月度结算从 $date 起可用。';
  }

  @override
  String closeDayMonth(int day, String month) {
    return '$month$day日';
  }

  @override
  String get closeNoReceiptsInPeriod => '此期间没有小票。';

  @override
  String get closeRangeHint => '先点按第一个月，再点按最后一个月。';

  @override
  String closeMonthAvailableHint(String month, String date) {
    return '$month在月底结束后、自 $date 起可用。';
  }

  @override
  String get closeTestMode => '测试模式';

  @override
  String get closePeriodPrinted => '结算已打印。';

  @override
  String get closeSignatureYear => '签名年度小票';

  @override
  String get closeSignatureMonth => '签名月度小票';

  @override
  String get closeSignatureComes => '将随下一张小票自动生成。';

  @override
  String closeSignatureCreated(String date, String time, int number) {
    return '创建于 $date $time，小票号 $number';
  }

  @override
  String get closePrint => '打印';

  @override
  String get closeDays => '天';

  @override
  String get closeMonths => '月份';

  @override
  String get closeScreenOnly => '仅在屏幕上显示，不打印';

  @override
  String get closeAlsoOnPaper => '也会打印在纸上';

  @override
  String get closeOneMonth => '单月';

  @override
  String get closeFromTo => '起止';

  @override
  String get closeYearBefore => '上一年';

  @override
  String get closeYearAfter => '下一年';

  @override
  String get closeNoPrinter => '未设置打印机。';

  @override
  String get settingsTitle => '设置';

  @override
  String settingsRegisterAt(String business) {
    return '$business 的 Kassa 1';
  }

  @override
  String get settingsDevices => '本收银机的设备';

  @override
  String get settingsDrawer => '钱箱';

  @override
  String get settingsDrawerHelp => '如果没有钱箱，请关闭。';

  @override
  String get settingsDeviceTest => '测试设备';

  @override
  String get settingsDeviceTestHelp => '测试打印、打开钱箱。';

  @override
  String get settingsDisplay => '显示';

  @override
  String get settingsImages => '商品带图片';

  @override
  String get settingsImagesHelp => '带照片的大按钮。';

  @override
  String get settingsView => '外观';

  @override
  String get settingsViewHelp => '晚上和光线暗的地方用深色更舒适。';

  @override
  String get settingsThemeSystem => '跟随平板';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsRegister => '收银';

  @override
  String get settingsVoidChef => '仅店长可作废';

  @override
  String get settingsVoidChefHelp => '员工将无法作废小票。';

  @override
  String get settingsPayments => '付款';

  @override
  String get settingsSplitPayment => '部分现金，其余刷卡';

  @override
  String get settingsCardTip => '刷卡时收小费';

  @override
  String get settingsDiscount => '折扣';

  @override
  String get settingsOpenAmount => '自定义金额';

  @override
  String get settingsAccessOff => '关闭';

  @override
  String get settingsAccessAll => '所有人';

  @override
  String get settingsAccessChef => '仅店长';

  @override
  String settingsVersion(String version) {
    return 'Kassa 版本 $version';
  }

  @override
  String get kitchenTitle => '厨房';

  @override
  String get kitchenVoided => '作废';

  @override
  String get kitchenCopy => '副本';

  @override
  String get kitchenSample => '测试';

  @override
  String get settingsKitchen => '厨房';

  @override
  String get settingsKitchenMode => '厨房单';

  @override
  String get settingsKitchenOff => '关闭';

  @override
  String get settingsKitchenAtReceiptPrinter => '在小票打印机';

  @override
  String get settingsKitchenAtKitchenPrinter => '在厨房打印机';

  @override
  String get settingsKitchenLanguage => '厨房单语言';

  @override
  String get settingsKitchenNoPrinter => '未设置厨房打印机。不会打印厨房单。';

  @override
  String get settingsKitchenCategories => '发送到厨房的分类';

  @override
  String get settingsKitchenCategoryOn => '打印在厨房单上';

  @override
  String get settingsKitchenCategoryOff => '不打印在厨房单上';

  @override
  String get settingsKitchenPreview => '预览';

  @override
  String get settingsKitchenSample => '打印样张';

  @override
  String get settingsKitchenSamplePrinting => '正在打印…';

  @override
  String get settingsKitchenSamplePrinted => '样张已打印。';

  @override
  String get kassaKitchenNotPrinted => '厨房单未打印';

  @override
  String get kassaKitchenPrint => '打印厨房单';

  @override
  String get kassaKitchenPrinting => '正在打印厨房单…';

  @override
  String get kassaKitchenPrinted => '厨房单已打印。';

  @override
  String get bonsKitchenNothing => '这张小票上没有需要厨房制作的内容。';

  @override
  String get settingsKitchenNoReceiptPrinter => '未设置小票打印机。不会打印厨房单。';

  @override
  String kassaKitchenLateMore(int count) {
    return '其他未打印的厨房单：$count';
  }

  @override
  String get kassaKitchenDismiss => '隐藏';
}
