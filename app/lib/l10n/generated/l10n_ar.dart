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
      zero: 'لا أصناف',
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
  String get kassaCancel => 'إلغاء';

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

  @override
  String get dateMonthJanuary => 'يناير';

  @override
  String get dateMonthFebruary => 'فبراير';

  @override
  String get dateMonthMarch => 'مارس';

  @override
  String get dateMonthApril => 'أبريل';

  @override
  String get dateMonthMay => 'مايو';

  @override
  String get dateMonthJune => 'يونيو';

  @override
  String get dateMonthJuly => 'يوليو';

  @override
  String get dateMonthAugust => 'أغسطس';

  @override
  String get dateMonthSeptember => 'سبتمبر';

  @override
  String get dateMonthOctober => 'أكتوبر';

  @override
  String get dateMonthNovember => 'نوفمبر';

  @override
  String get dateMonthDecember => 'ديسمبر';

  @override
  String get dateWeekdayMonday => 'الاثنين';

  @override
  String get dateWeekdayTuesday => 'الثلاثاء';

  @override
  String get dateWeekdayWednesday => 'الأربعاء';

  @override
  String get dateWeekdayThursday => 'الخميس';

  @override
  String get dateWeekdayFriday => 'الجمعة';

  @override
  String get dateWeekdaySaturday => 'السبت';

  @override
  String get dateWeekdaySunday => 'الأحد';

  @override
  String get dateWeekdayShortMonday => 'الاثنين';

  @override
  String get dateWeekdayShortTuesday => 'الثلاثاء';

  @override
  String get dateWeekdayShortWednesday => 'الأربعاء';

  @override
  String get dateWeekdayShortThursday => 'الخميس';

  @override
  String get dateWeekdayShortFriday => 'الجمعة';

  @override
  String get dateWeekdayShortSaturday => 'السبت';

  @override
  String get dateWeekdayShortSunday => 'الأحد';

  @override
  String dateWeekdayDayMonth(String weekday, int day, String month) {
    return '$weekday، $day $month';
  }

  @override
  String get bonsTitle => 'الفواتير';

  @override
  String bonsToday(String day) {
    return 'اليوم، $day';
  }

  @override
  String bonsDayLabel(String weekday, int day, String month) {
    return '$weekday، $day $month';
  }

  @override
  String get bonsNoneToday => 'لا توجد فواتير اليوم بعد.';

  @override
  String get bonsNoneForFilter => 'لا توجد فواتير بهذا التصنيف.';

  @override
  String get bonsFilterAll => 'الكل';

  @override
  String get bonsCash => 'نقدًا';

  @override
  String get bonsCard => 'بطاقة';

  @override
  String get bonsCashAndCard => 'نقدًا + بطاقة';

  @override
  String get bonsVoided => 'ملغاة';

  @override
  String get bonsVoidReceipt => 'إلغاء';

  @override
  String get bonsKindStart => 'فاتورة البدء';

  @override
  String get bonsKindMonth => 'فاتورة شهرية';

  @override
  String get bonsKindYear => 'فاتورة سنوية';

  @override
  String get bonsKindZero => 'فاتورة صفرية';

  @override
  String get bonsKindCollective => 'فاتورة مجمعة';

  @override
  String get bonsKindClosing => 'الفاتورة الختامية';

  @override
  String bonsNumberShort(int number) {
    return 'رقم $number';
  }

  @override
  String get bonsPrint => 'طباعة';

  @override
  String get bonsVoid => 'إلغاء';

  @override
  String get bonsNothingSelected => 'اضغط على فاتورة لعرضها.';

  @override
  String bonsTime(String time) {
    return '$time';
  }

  @override
  String get bonsDeposit => 'تأمين';

  @override
  String bonsTaxRate(int percent) {
    return 'ضريبة $percent %';
  }

  @override
  String get bonsPayment => 'الدفع';

  @override
  String bonsVoidOf(String number) {
    return 'إلغاء الفاتورة رقم $number';
  }

  @override
  String bonsVoidedBy(String name) {
    return 'ألغاها $name';
  }

  @override
  String bonsCreatedBy(String name) {
    return 'أنشأها $name';
  }

  @override
  String bonsRungUpBy(String name) {
    return 'سجّلها $name';
  }

  @override
  String get bonsVoidedNotCounted =>
      'ملغاة. لا تُحتسب هذه الفاتورة في الإيرادات.';

  @override
  String bonsVoidedByNotCounted(String name) {
    return 'ألغاها $name. لا تُحتسب هذه الفاتورة في الإيرادات.';
  }

  @override
  String bonsCashBoxId(String id) {
    return 'معرّف الصندوق $id';
  }

  @override
  String get bonsTestReceipt => 'فاتورة تجريبية';

  @override
  String get bonsDeviceFailed => 'تعطّل جهاز الأمان';

  @override
  String get bonsProbeSignature => 'فاتورة تجريبية بتوقيع تجريبي.';

  @override
  String get bonsQrOnPaper => 'رمز QR موجود أيضًا على الفاتورة المطبوعة.';

  @override
  String get bonsVoidFailed => 'تعذّر حفظ الإلغاء. يرجى المحاولة مرة أخرى.';

  @override
  String get bonsVoidOlderThanProbe =>
      'هذه الفاتورة أقدم من التوقيع التجريبي ولا يمكن إلغاؤها.';

  @override
  String get bonsVoidFromTestTime =>
      'هذه الفاتورة من فترة التجربة ولا يمكن إلغاؤها.';

  @override
  String bonsVoidQuestion(int number) {
    return 'هل تريد إلغاء الفاتورة رقم $number؟';
  }

  @override
  String bonsVoidCashBack(String amount) {
    return 'تُعيد $amount نقدًا.';
  }

  @override
  String get bonsVoidCardHint =>
      'لا يُعاد المبلغ تلقائيًا. يرجى استرداد الدفعة في تطبيق SumUp.';

  @override
  String get bonsVoidConfirmCard => 'إلغاء، وسأسترد المبلغ في SumUp';

  @override
  String get bonsVoidConfirm => 'نعم، إلغاء';

  @override
  String get itemsTitle => 'الأصناف';

  @override
  String get itemsWithChoice => 'مع خيارات';

  @override
  String itemsPlusDeposit(String amount) {
    return 'زائد $amount تأمين';
  }

  @override
  String get itemsColumnItem => 'الصنف';

  @override
  String get itemsPrice => 'السعر';

  @override
  String get itemsFavorite => 'مفضل';

  @override
  String get itemsInSale => 'متاح للبيع';

  @override
  String itemsFavoriteRemove(String name) {
    return 'إزالة $name من المفضلة';
  }

  @override
  String itemsFavoriteAdd(String name) {
    return 'إضافة $name إلى المفضلة';
  }

  @override
  String itemsInSaleLabel(String name) {
    return '$name متاح للبيع';
  }

  @override
  String get itemsChangePrice => 'تغيير السعر';

  @override
  String itemsDepositToggle(String amount) {
    return 'تأمين $amount';
  }

  @override
  String get itemsVegan => 'نباتي';

  @override
  String get itemsSpicy => 'حار';

  @override
  String get itemsTaxRate => 'نسبة الضريبة';

  @override
  String get itemsChoiceWhenRinging => 'الخيارات عند التسجيل';

  @override
  String itemsChoiceGroups(String groups) {
    return '$groups.';
  }

  @override
  String get itemsFromMenuFile =>
      'تأتي الأسماء والصور والأصناف الجديدة من ملف القائمة.';

  @override
  String get itemsWriteFailed => 'لم ينجح ذلك. يرجى المحاولة مرة أخرى.';

  @override
  String itemsNewPrice(String amount) {
    return 'السعر الجديد، الحالي $amount';
  }

  @override
  String get itemsApply => 'تطبيق';

  @override
  String get overviewTitle => 'نظرة عامة';

  @override
  String get overviewRangeToday => 'اليوم';

  @override
  String get overviewRange7 => '7 أيام';

  @override
  String get overviewRange30 => '30 يومًا';

  @override
  String get overviewLast7 => 'آخر 7 أيام';

  @override
  String get overviewLast30 => 'آخر 30 يومًا';

  @override
  String overviewHourRange(int from, int to) {
    return '$from:00–$to:00';
  }

  @override
  String overviewSameAsWeekday(String weekday) {
    return 'مثل $weekday الماضي';
  }

  @override
  String overviewMoreThanWeekday(int percent, String weekday) {
    return 'أكثر بنسبة $percent % من $weekday الماضي';
  }

  @override
  String overviewLessThanWeekday(int percent, String weekday) {
    return 'أقل بنسبة $percent % من $weekday الماضي';
  }

  @override
  String overviewSameAsDaysBefore(int days) {
    return 'مثل الأيام الـ $days السابقة';
  }

  @override
  String overviewMoreThanDaysBefore(int percent, int days) {
    return 'أكثر بنسبة $percent % من الأيام الـ $days السابقة';
  }

  @override
  String overviewLessThanDaysBefore(int percent, int days) {
    return 'أقل بنسبة $percent % من الأيام الـ $days السابقة';
  }

  @override
  String get overviewRevenue => 'الإيرادات';

  @override
  String get overviewReceipts => 'الفواتير';

  @override
  String get overviewPerReceipt => 'لكل فاتورة';

  @override
  String get overviewVoids => 'الإلغاءات';

  @override
  String get overviewPerHour => 'الإيرادات لكل ساعة';

  @override
  String get overviewPerDay => 'الإيرادات لكل يوم';

  @override
  String get overviewNoneInRange => 'لا توجد فواتير في هذه الفترة بعد.';

  @override
  String overviewBarLabel(String label, String amount) {
    return '$label، $amount';
  }

  @override
  String get overviewLoadFailed => 'تعذّر تحميل الأرقام.';

  @override
  String get overviewRetry => 'حاول مرة أخرى';

  @override
  String get overviewPayments => 'طرق الدفع';

  @override
  String get overviewNoReceipts => 'لا توجد فواتير بعد.';

  @override
  String get overviewTopItems => 'الأكثر مبيعًا';

  @override
  String get overviewByCategory => 'حسب الفئة';

  @override
  String closeClockTime(String time) {
    return '$time';
  }

  @override
  String closeBonCount(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted فاتورة',
      many: '$formatted فاتورة',
      few: '$formatted فواتير',
      two: 'فاتورتان',
      one: 'فاتورة واحدة',
      zero: '$formatted فاتورة',
    );
    return '$_temp0';
  }

  @override
  String get closeReasonBank => 'البنك';

  @override
  String get closeReasonPurchase => 'مشتريات';

  @override
  String get closeReasonChange => 'الفكة';

  @override
  String get closeReasonOther => 'أخرى';

  @override
  String get closeCashIn => 'إيداع نقد';

  @override
  String get closeCashOut => 'سحب نقد';

  @override
  String get closeCloseSheet => 'إغلاق';

  @override
  String get closeAmount => 'المبلغ';

  @override
  String get closeReason => 'السبب';

  @override
  String get closeSaveCashIn => 'حفظ الإيداع';

  @override
  String get closeSaveCashOut => 'حفظ السحب';

  @override
  String get closeFloatTitle => 'الفكة';

  @override
  String get closeFloatQuestionDrawer => 'كم كانت الفكة في الدرج صباحًا؟';

  @override
  String get closeFloatQuestion => 'كم كانت الفكة صباحًا؟';

  @override
  String get closeSaveFloat => 'حفظ الفكة';

  @override
  String get closeNothingTyped => 'لم يُدخل شيء بعد';

  @override
  String get closeExact => 'مطابق تمامًا';

  @override
  String get closeMissing => 'ناقص';

  @override
  String get closeTooMuchDrawer => 'زيادة في الدرج';

  @override
  String get closeTooMuchCash => 'زيادة في النقد';

  @override
  String get closeCountDrawer => 'عدّ درج النقود';

  @override
  String get closeCountCash => 'عدّ النقد';

  @override
  String closeStep(int step, int total) {
    return 'الخطوة $step من $total';
  }

  @override
  String get closeExpectedDrawer => 'المتوقع في الدرج';

  @override
  String get closeExpectedCash => 'النقد المتوقع';

  @override
  String get closeCounted => 'المعدود';

  @override
  String get closeNext => 'التالي';

  @override
  String get closeLeaveInDrawer => 'الإبقاء في الدرج';

  @override
  String get closeFloatForTomorrow => 'فكة الغد';

  @override
  String get closeDifferenceToExpected => 'الفرق عن المتوقع';

  @override
  String get closeLeaveQuestionDrawer => 'كم يبقى في الدرج كفكة؟';

  @override
  String get closeLeaveQuestion => 'كم يبقى كفكة؟';

  @override
  String get closeMoreThanCounted => 'لا يمكن إبقاء أكثر من المبلغ المعدود.';

  @override
  String get closeYouTakeOut => 'تسحب';

  @override
  String get closeBack => 'رجوع';

  @override
  String get closeCloseDay => 'إقفال اليوم';

  @override
  String get closeDayClosed => 'تم إقفال اليوم';

  @override
  String get closeDayIsClosed => 'تم إقفال اليوم.';

  @override
  String get closeNoOpenDay => 'لا يوجد يوم مفتوح.';

  @override
  String get closeNextDayStarts => 'يبدأ اليوم التالي مع أول فاتورة.';

  @override
  String closeTakenOut(String amount) {
    return 'المسحوب: $amount';
  }

  @override
  String closeTomorrowDrawer(String amount) {
    return 'غدًا سيكون في الدرج $amount فكة.';
  }

  @override
  String closeTomorrow(String amount) {
    return 'غدًا ستكون هناك $amount فكة.';
  }

  @override
  String closeClosedBy(String name, String time) {
    return 'أقفله $name الساعة $time';
  }

  @override
  String get closePrintReport => 'طباعة التقرير';

  @override
  String get closeToKassa => 'العودة إلى البيع';

  @override
  String get closeReportPrinted => 'تمت طباعة التقرير.';

  @override
  String get closeTitle => 'إقفال اليوم';

  @override
  String get closeDay => 'اليوم';

  @override
  String get closeMonth => 'الشهر';

  @override
  String get closeClosedPill => 'مُقفل';

  @override
  String get closeLoadFailed => 'لم ينجح ذلك. يرجى فتح هذا القسم مرة أخرى.';

  @override
  String get closeDrawer => 'درج النقود';

  @override
  String get closeCash => 'النقد';

  @override
  String get closeFloatMorning => 'فكة الصباح';

  @override
  String get closeStillOpen => 'لم يُحدد بعد';

  @override
  String get closeCashTakings => 'المقبوضات النقدية';

  @override
  String closeDeposited(String reason) {
    return 'إيداع: $reason';
  }

  @override
  String closeWithdrawn(String reason) {
    return 'سحب: $reason';
  }

  @override
  String get closeDifference => 'الفرق';

  @override
  String get closeIncome => 'المقبوضات';

  @override
  String get closeTotal => 'الإجمالي';

  @override
  String get closeTax => 'الضريبة';

  @override
  String get closeRevenue => 'الإيرادات';

  @override
  String get closeOfWhichVat => 'منها الضريبة';

  @override
  String closeVatRate(int percent) {
    return 'الضريبة $percent %';
  }

  @override
  String get closeDepositNoVat => 'التأمين، بدون ضريبة';

  @override
  String get closeForgotten => 'لم يُقفل اليوم الأخير بعد.';

  @override
  String get closeNow => 'الإقفال الآن';

  @override
  String get dateMonthShortJanuary => 'يناير';

  @override
  String get dateMonthShortFebruary => 'فبراير';

  @override
  String get dateMonthShortMarch => 'مارس';

  @override
  String get dateMonthShortApril => 'أبريل';

  @override
  String get dateMonthShortMay => 'مايو';

  @override
  String get dateMonthShortJune => 'يونيو';

  @override
  String get dateMonthShortJuly => 'يوليو';

  @override
  String get dateMonthShortAugust => 'أغسطس';

  @override
  String get dateMonthShortSeptember => 'سبتمبر';

  @override
  String get dateMonthShortOctober => 'أكتوبر';

  @override
  String get dateMonthShortNovember => 'نوفمبر';

  @override
  String get dateMonthShortDecember => 'ديسمبر';

  @override
  String closeMonthYear(String month, int year) {
    return '$month $year';
  }

  @override
  String closePeriodSameYear(String from, String to, int year) {
    return '$from إلى $to $year';
  }

  @override
  String closePeriodTwoYears(String from, String to) {
    return '$from إلى $to';
  }

  @override
  String closePeriodDates(String from, String to) {
    return '$from إلى $to';
  }

  @override
  String get closeMonthlyReport => 'التقرير الشهري';

  @override
  String get closeReport => 'التقرير';

  @override
  String get closePeriod => 'الفترة';

  @override
  String closeFirstMonthlyReport(String date) {
    return 'يتوفر أول تقرير شهري ابتداءً من $date.';
  }

  @override
  String closeDayMonth(int day, String month) {
    return '$day $month';
  }

  @override
  String get closeNoReceiptsInPeriod => 'لا توجد فواتير في هذه الفترة.';

  @override
  String get closeRangeHint => 'اضغط على الشهر الأول ثم على الأخير.';

  @override
  String closeMonthAvailableHint(String month, String date) {
    return 'يتوفر $month ابتداءً من $date بعد انتهاء الشهر.';
  }

  @override
  String get closeTestMode => 'وضع التجربة';

  @override
  String get closePeriodPrinted => 'تمت طباعة التقرير.';

  @override
  String get closeSignatureYear => 'فاتورة التوقيع السنوية';

  @override
  String get closeSignatureMonth => 'فاتورة التوقيع الشهرية';

  @override
  String get closeSignatureComes => 'تصدر تلقائيًا مع الفاتورة التالية.';

  @override
  String closeSignatureCreated(String date, String time, int number) {
    return 'أُنشئت في $date الساعة $time، رقم الفاتورة $number';
  }

  @override
  String get closePrint => 'طباعة';

  @override
  String get closeDays => 'الأيام';

  @override
  String get closeMonths => 'الأشهر';

  @override
  String get closeScreenOnly => 'على الشاشة فقط، لا على الورق';

  @override
  String get closeAlsoOnPaper => 'تظهر أيضًا على الورق';

  @override
  String get closeOneMonth => 'شهر واحد';

  @override
  String get closeFromTo => 'من – إلى';

  @override
  String get closeYearBefore => 'السنة السابقة';

  @override
  String get closeYearAfter => 'السنة التالية';

  @override
  String get closeNoPrinter => 'لم يتم إعداد طابعة.';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String settingsRegisterAt(String business) {
    return 'Kassa 1 في $business';
  }

  @override
  String get settingsDevices => 'الأجهزة في نقطة البيع هذه';

  @override
  String get settingsDrawer => 'درج النقود';

  @override
  String get settingsDrawerHelp => 'أوقفه إذا لم يكن هناك درج نقود.';

  @override
  String get settingsDeviceTest => 'اختبار الأجهزة';

  @override
  String get settingsDeviceTestHelp => 'طباعة تجريبية، فتح الدرج.';

  @override
  String get settingsDisplay => 'العرض';

  @override
  String get settingsImages => 'الأصناف مع الصور';

  @override
  String get settingsImagesHelp => 'أزرار كبيرة مع صورة.';

  @override
  String get settingsView => 'المظهر';

  @override
  String get settingsViewHelp =>
      'الوضع الداكن أريح في المساء وفي الأماكن المظلمة.';

  @override
  String get settingsThemeSystem => 'مثل الجهاز اللوحي';

  @override
  String get settingsThemeLight => 'فاتح';

  @override
  String get settingsThemeDark => 'داكن';

  @override
  String get settingsRegister => 'البيع';

  @override
  String get settingsVoidChef => 'الإلغاء للمدير فقط';

  @override
  String get settingsVoidChefHelp =>
      'لن يتمكن الموظفون عندها من إلغاء الفواتير.';

  @override
  String get settingsPayments => 'الدفع';

  @override
  String get settingsSplitPayment => 'جزء نقدًا والباقي بالبطاقة';

  @override
  String get settingsCardTip => 'إكرامية عند الدفع بالبطاقة';

  @override
  String get settingsDiscount => 'خصم';

  @override
  String get settingsOpenAmount => 'مبلغ حر';

  @override
  String get settingsAccessOff => 'إيقاف';

  @override
  String get settingsAccessAll => 'الجميع';

  @override
  String get settingsAccessChef => 'للمدير فقط';

  @override
  String settingsVersion(String version) {
    return 'Kassa الإصدار $version';
  }

  @override
  String get kitchenTitle => 'المطبخ';

  @override
  String get kitchenVoided => 'إلغاء';

  @override
  String get kitchenCopy => 'نسخة';

  @override
  String get kitchenSample => 'تجربة';

  @override
  String get settingsKitchen => 'المطبخ';

  @override
  String get settingsKitchenMode => 'تذكرة المطبخ';

  @override
  String get settingsKitchenOff => 'إيقاف';

  @override
  String get settingsKitchenAtReceiptPrinter => 'على طابعة الفواتير';

  @override
  String get settingsKitchenAtKitchenPrinter => 'على طابعة المطبخ';

  @override
  String get settingsKitchenLanguage => 'لغة تذكرة المطبخ';

  @override
  String get settingsKitchenNoPrinter =>
      'لم يتم إعداد طابعة المطبخ. لن تُطبع تذكرة المطبخ.';

  @override
  String get settingsKitchenCategories => 'الفئات الخاصة بالمطبخ';

  @override
  String get settingsKitchenCategoryOn => 'تظهر في تذكرة المطبخ';

  @override
  String get settingsKitchenCategoryOff => 'لا تظهر في تذكرة المطبخ';

  @override
  String get settingsKitchenPreview => 'معاينة';

  @override
  String get settingsKitchenSample => 'طباعة نموذج';

  @override
  String get settingsKitchenSamplePrinting => 'جارٍ الطباعة…';

  @override
  String get settingsKitchenSamplePrinted => 'تمت طباعة النموذج.';

  @override
  String get kassaKitchenNotPrinted => 'لم تُطبع تذكرة المطبخ';

  @override
  String get kassaKitchenPrint => 'طباعة تذكرة المطبخ';

  @override
  String get kassaKitchenPrinting => 'جارٍ طباعة تذكرة المطبخ…';

  @override
  String get kassaKitchenPrinted => 'تمت طباعة تذكرة المطبخ.';

  @override
  String get bonsKitchenNothing => 'لا يوجد في هذه الفاتورة شيء للمطبخ.';

  @override
  String get settingsKitchenNoReceiptPrinter =>
      'لم يتم إعداد طابعة الفواتير. لن تُطبع تذكرة المطبخ.';

  @override
  String kassaKitchenLateMore(int count) {
    return 'تذاكر مطبخ أخرى لم تُطبع: $count';
  }

  @override
  String get kassaKitchenDismiss => 'إخفاء';
}
