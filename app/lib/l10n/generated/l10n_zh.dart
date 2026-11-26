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
  String get shellTabBons => '小票';

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
}
