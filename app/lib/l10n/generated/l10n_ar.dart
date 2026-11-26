// ignore_for_file: deprecated_member_use

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class L10nAr extends L10n {
  L10nAr([String locale = 'ar']) : super(locale);

  @override
  String get languageSectionTitle => 'اللغة';

  @override
  String get languageSheetTitle => 'اللغة';

  @override
  String get languageChangeLabel => 'تغيير اللغة';

  @override
  String get loginTitle => 'أدخل رمز PIN';

  @override
  String get loginHint => 'لكل شخص رمز PIN خاص به';

  @override
  String get loginWrongPin => 'رمز PIN هذا غير مسجَّل.';

  @override
  String get loginFailed => 'لم ينجح ذلك. يرجى المحاولة مرة أخرى.';

  @override
  String loginDigitsEntered(int filled) {
    return 'تم إدخال $filled من 4 أرقام';
  }

  @override
  String get shellTabKassa => 'البيع';

  @override
  String get shellTabBons => 'الفواتير';

  @override
  String get shellTabOverview => 'نظرة عامة';

  @override
  String get shellTabItems => 'الأصناف';

  @override
  String get shellTabClose => 'الإقفال';

  @override
  String get shellOffline => 'لا يوجد إنترنت. البيع نقدًا مستمر.';

  @override
  String shellSwitchStaff(String name) {
    return 'تبديل الموظف، المسجَّل حاليًا: $name';
  }

  @override
  String get shellSettings => 'الإعدادات';

  @override
  String get uiUndo => 'تراجع';

  @override
  String get uiKeypadComma => 'فاصلة';

  @override
  String get uiKeypadDot => 'نقطة';

  @override
  String get uiKeypadDelete => 'حذف آخر رقم';

  @override
  String get uiReceiptQr => 'رمز QR للفاتورة';

  @override
  String get uiListSeparator => '، ';

  @override
  String kassaItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صنف',
      many: '$count صنفًا',
      few: '$count أصناف',
      two: 'صنفان',
      one: 'صنف واحد',
      zero: '$count صنف',
    );
    return '$_temp0';
  }

  @override
  String kassaCategoryLabel(String name, String items) {
    return '$name، $items';
  }

  @override
  String get kassaFavorites => 'المفضلة';

  @override
  String get kassaWithImages => 'مع الصور';

  @override
  String get kassaCompact => 'مضغوط';

  @override
  String get kassaPlusDeposit => '+ تأمين';

  @override
  String get kassaNotForSale => 'غير متاح للبيع';

  @override
  String kassaOnReceipt(int count) {
    return '$count في الفاتورة';
  }

  @override
  String get kassaTagVegan => 'نباتي';

  @override
  String get kassaTagSpicy => 'حار';

  @override
  String kassaOneLess(String name) {
    return 'إنقاص واحد: $name';
  }

  @override
  String kassaOneMore(String name) {
    return 'إضافة واحد: $name';
  }

  @override
  String get kassaReceipt => 'الفاتورة';

  @override
  String get kassaClearCart => 'مسح الفاتورة';

  @override
  String get kassaCartCleared => 'تم مسح الفاتورة';

  @override
  String get kassaEmptyTitle => 'لا توجد أصناف بعد';

  @override
  String get kassaEmptyHint =>
      'اضغط على صنف. كل ضغطة تضيفه مرة واحدة إلى الفاتورة.';

  @override
  String get kassaTotal => 'الإجمالي';

  @override
  String kassaDepositIncluded(String amount) {
    return 'منها تأمين $amount';
  }

  @override
  String kassaTaxIncluded(String amount) {
    return 'شامل الضريبة $amount';
  }

  @override
  String get kassaCash => 'نقدًا';

  @override
  String get kassaCard => 'بطاقة';

  @override
  String get kassaCardNotSetUp => 'غير مُعدّة';

  @override
  String get kassaCardLoggedOut => 'غير مسجَّلة';

  @override
  String get kassaCardNoInternet => 'لا إنترنت';

  @override
  String kassaCardFrom(String amount) {
    return 'من $amount';
  }

  @override
  String get kassaCancel => 'إغلاق';

  @override
  String get kassaAddToReceipt => 'أضف إلى الفاتورة';

  @override
  String kassaStillToChoose(String groups) {
    return 'يجب اختيار: $groups';
  }

  @override
  String get kassaPickOne => 'اختيار واحد';

  @override
  String get kassaAtMostOne => 'واحد على الأكثر';

  @override
  String kassaAtLeast(int min) {
    return '$min على الأقل';
  }

  @override
  String kassaUpTo(int max) {
    return 'حتى $max';
  }

  @override
  String get kassaPleaseChoose => 'يرجى الاختيار';

  @override
  String kassaChosenCount(int count) {
    return 'تم اختيار $count';
  }

  @override
  String kassaOptionChosen(String name) {
    return '$name، تم اختياره';
  }

  @override
  String get kassaPayCashTitle => 'الدفع نقدًا';

  @override
  String get kassaBackToReceipt => 'العودة إلى الفاتورة';

  @override
  String get kassaAmountDue => 'المبلغ المطلوب';

  @override
  String get kassaGiven => 'المبلغ المستلم';

  @override
  String get kassaExact => 'بالضبط';

  @override
  String get kassaOtherAmount => 'مبلغ آخر';

  @override
  String get kassaShowSuggestions => 'عرض الاقتراحات';

  @override
  String get kassaStillMissing => 'المتبقي';

  @override
  String get kassaChange => 'الباقي';

  @override
  String get kassaSaveFailed => 'تعذّر حفظ الفاتورة. يرجى المحاولة مرة أخرى.';

  @override
  String get kassaFinish => 'إتمام';

  @override
  String get kassaFinishAndPrint => 'إتمام وطباعة الفاتورة';

  @override
  String get kassaWaitingForCard => 'في انتظار البطاقة';

  @override
  String get kassaCardHint => 'يقرّب العميل البطاقة أو الهاتف من الجهاز.';

  @override
  String get kassaPaid => 'تم الدفع';

  @override
  String kassaReceiptNumber(int number) {
    return 'رقم الفاتورة $number';
  }

  @override
  String get kassaPaidExact => 'تم الدفع بالمبلغ المضبوط';

  @override
  String get kassaGiveChange => 'أعطِ الباقي';

  @override
  String get kassaGiveChangeFromDrawer => 'أعطِ الباقي من الدرج';

  @override
  String get kassaPaidByCard => 'تم الدفع بالبطاقة';

  @override
  String get kassaNextCustomer => 'العميل التالي';

  @override
  String get kassaPrinting => 'جارٍ طباعة الفاتورة…';

  @override
  String get kassaPrinted => 'تمت طباعة الفاتورة';

  @override
  String get kassaPrintAgain => 'إعادة الطباعة';

  @override
  String get cardAlreadyRunning => 'هناك دفع بالبطاقة قيد التنفيذ.';

  @override
  String get cardEmptyReceipt => 'الفاتورة فارغة.';

  @override
  String cardMinimum(String amount) {
    return 'الدفع بالبطاقة يبدأ من $amount.';
  }

  @override
  String get cardNotStarted => 'تعذّر بدء الدفع بالبطاقة.';

  @override
  String get cardDeclined => 'لم يكتمل الدفع بالبطاقة.';

  @override
  String get cardCancelled => 'تم إلغاء الدفع بالبطاقة.';

  @override
  String get cardNoInternet => 'لا يوجد إنترنت. الدفع بالبطاقة غير ممكن الآن.';

  @override
  String get cardNotLoggedIn =>
      'SumUp غير مسجَّل الدخول. يرجى تسجيل الدخول من الإعدادات.';

  @override
  String get cardNoReader =>
      'لا يوجد قارئ بطاقات متصل. يرجى توصيله من الإعدادات.';

  @override
  String get cardPermission => 'يحتاج Kassa إلى إذن البلوتوث والموقع.';

  @override
  String get cardFailed => 'فشل الدفع بالبطاقة.';

  @override
  String cardFailedDetail(String detail) {
    return 'فشل الدفع بالبطاقة. ($detail)';
  }

  @override
  String get printNotSetUp => 'لم يتم إعداد طابعة الفواتير.';

  @override
  String get printUnreachable => 'الطابعة غير جاهزة. هل هي مشغّلة ومتصلة؟';

  @override
  String get printNoPermission =>
      'لا يُسمح لـ Kassa باستخدام الطابعة. يرجى منح الإذن.';

  @override
  String get printPaperOut => 'الطابعة غير جاهزة. نفد الورق.';

  @override
  String get printCoverOpen => 'الطابعة غير جاهزة. الغطاء مفتوح.';

  @override
  String get printTimeout => 'الطابعة غير جاهزة. لا تستجيب.';

  @override
  String outageTitle(String since) {
    return 'التوقيع معطّل منذ $since';
  }

  @override
  String get outageSellOn => 'يمكنك مواصلة البيع كالمعتاد.';

  @override
  String get outageKeepsWorking => 'يستمر Kassa في العمل. يرجى إبلاغ المدير.';

  @override
  String get outageRejected =>
      'رفضت A-Trust بيانات الدخول. يرجى استدعاء المدير.';

  @override
  String get outageNotYet => 'لا يعمل بعد.';

  @override
  String get outageBack => 'عاد التوقيع للعمل.';

  @override
  String get outageRetry => 'إعادة الفحص';

  @override
  String get outageRepin => 'إعادة إدخال رمز PIN';

  @override
  String get unclearTitle => 'هل نجح هذا الدفع بالبطاقة؟';

  @override
  String unclearStarted(String time, String name) {
    return 'بدأه $name الساعة $time';
  }

  @override
  String unclearMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'و$count صنف آخر',
      many: 'و$count صنفًا آخر',
      few: 'و$count أصناف أخرى',
      two: 'وصنفان آخران',
      one: 'وصنف آخر',
      zero: 'و$count أصناف أخرى',
    );
    return '$_temp0';
  }

  @override
  String unclearNoAnswer(String amount, String time) {
    return 'لم يتلقَّ Kassa ردًا من SumUp. تحقّق في تطبيق SumUp ضمن «المبيعات» مما إذا كان مبلغ $amount قد وصل الساعة $time.';
  }

  @override
  String get unclearUnreadable =>
      'لم يعد بالإمكان إنشاء الفاتورة لأن قائمة الطعام تغيّرت. اختر «لا». إذا وصل المبلغ إلى SumUp، فأعِده من تطبيق SumUp واقبض من جديد.';

  @override
  String get unclearFailed => 'لم ينجح ذلك. يرجى المحاولة مرة أخرى.';

  @override
  String get unclearYes => 'نعم، وصل';

  @override
  String get unclearNo => 'لا، لم يصل';

  @override
  String get unclearEffectPaidPrint =>
      'يسجّل Kassa الفاتورة كدفع بالبطاقة ويطبعها.';

  @override
  String get unclearEffectPaid => 'يسجّل Kassa الفاتورة كدفع بالبطاقة.';

  @override
  String get unclearEffectRestore =>
      'يتجاهل Kassa الدفع ويعيد الأصناف إلى الفاتورة.';

  @override
  String get unclearEffectDiscard =>
      'يتجاهل Kassa الدفع. تبقى الفاتورة الحالية كما هي.';

  @override
  String get unclearConfirm => 'تأكيد';

  @override
  String get unclearBack => 'رجوع';
}
