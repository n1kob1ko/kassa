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
}
