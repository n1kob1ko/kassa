// ignore_for_file: deprecated_member_use

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get languageSheetTitle => 'Language';

  @override
  String get languageChangeLabel => 'Change language';

  @override
  String get loginTitle => 'Enter PIN';

  @override
  String get loginHint => 'Everyone has their own PIN';

  @override
  String get loginWrongPin => 'This PIN is not registered.';

  @override
  String get loginFailed => 'That didn\'t work. Please try again.';

  @override
  String loginDigitsEntered(int filled) {
    return '$filled of 4 digits entered';
  }

  @override
  String get shellTabKassa => 'Register';

  @override
  String get shellTabBons => 'Receipts';

  @override
  String get shellTabOverview => 'Overview';

  @override
  String get shellTabItems => 'Items';

  @override
  String get shellTabClose => 'Closing';

  @override
  String get shellOffline => 'No internet. Cash sales still work.';

  @override
  String shellSwitchStaff(String name) {
    return 'Switch staff, signed in: $name';
  }

  @override
  String get shellSettings => 'Settings';

  @override
  String get uiUndo => 'Undo';

  @override
  String get uiKeypadComma => 'Comma';

  @override
  String get uiKeypadDot => 'Dot';

  @override
  String get uiKeypadDelete => 'Delete last digit';

  @override
  String get uiReceiptQr => 'Receipt QR code';

  @override
  String get uiListSeparator => ', ';

  @override
  String kassaItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String kassaCategoryLabel(String name, String items) {
    return '$name, $items';
  }

  @override
  String get kassaFavorites => 'Favorites';

  @override
  String get kassaWithImages => 'With pictures';

  @override
  String get kassaCompact => 'Compact';

  @override
  String get kassaPlusDeposit => '+ deposit';

  @override
  String get kassaNotForSale => 'Not for sale';

  @override
  String kassaOnReceipt(int count) {
    return '$count on the receipt';
  }

  @override
  String get kassaTagVegan => 'VEGAN';

  @override
  String get kassaTagSpicy => 'SPICY';

  @override
  String kassaOneLess(String name) {
    return 'One less: $name';
  }

  @override
  String kassaOneMore(String name) {
    return 'One more: $name';
  }

  @override
  String get kassaReceipt => 'Receipt';

  @override
  String get kassaClearCart => 'Clear receipt';

  @override
  String get kassaCartCleared => 'Receipt cleared';

  @override
  String get kassaEmptyTitle => 'Nothing rung up yet';

  @override
  String get kassaEmptyHint =>
      'Tap an item. Each tap adds it to the receipt once.';

  @override
  String get kassaTotal => 'Total';

  @override
  String kassaDepositIncluded(String amount) {
    return 'incl. deposit $amount';
  }

  @override
  String kassaTaxIncluded(String amount) {
    return 'incl. $amount VAT';
  }

  @override
  String get kassaCash => 'Cash';

  @override
  String get kassaCard => 'Card';

  @override
  String get kassaCardNotSetUp => 'not set up';

  @override
  String get kassaCardLoggedOut => 'not signed in';

  @override
  String get kassaCardNoInternet => 'no internet';

  @override
  String kassaCardFrom(String amount) {
    return 'from $amount';
  }

  @override
  String get kassaCancel => 'Cancel';

  @override
  String get kassaAddToReceipt => 'Add to receipt';

  @override
  String kassaStillToChoose(String groups) {
    return 'Still to choose: $groups';
  }

  @override
  String get kassaPickOne => 'pick one';

  @override
  String get kassaAtMostOne => 'at most one';

  @override
  String kassaAtLeast(int min) {
    return 'at least $min';
  }

  @override
  String kassaUpTo(int max) {
    return 'up to $max';
  }

  @override
  String get kassaPleaseChoose => 'Please choose';

  @override
  String kassaChosenCount(int count) {
    return '$count selected';
  }

  @override
  String kassaOptionChosen(String name) {
    return '$name, selected';
  }

  @override
  String get kassaPayCashTitle => 'Pay cash';

  @override
  String get kassaBackToReceipt => 'Back to receipt';

  @override
  String get kassaAmountDue => 'Amount due';

  @override
  String get kassaGiven => 'Received';

  @override
  String get kassaExact => 'Exact';

  @override
  String get kassaOtherAmount => 'Other amount';

  @override
  String get kassaShowSuggestions => 'Show suggestions';

  @override
  String get kassaStillMissing => 'Remaining';

  @override
  String get kassaChange => 'Change';

  @override
  String get kassaSaveFailed =>
      'The receipt could not be saved. Please try again.';

  @override
  String get kassaFinish => 'Complete';

  @override
  String get kassaFinishAndPrint => 'Complete and print receipt';

  @override
  String get kassaWaitingForCard => 'Waiting for card';

  @override
  String get kassaCardHint =>
      'The customer holds their card or phone to the reader.';

  @override
  String get kassaPaid => 'Paid';

  @override
  String kassaReceiptNumber(int number) {
    return 'Receipt no. $number';
  }

  @override
  String get kassaPaidExact => 'Exact amount';

  @override
  String get kassaGiveChange => 'Give change';

  @override
  String get kassaGiveChangeFromDrawer => 'Give change from the drawer';

  @override
  String get kassaPaidByCard => 'Paid by card';

  @override
  String get kassaNextCustomer => 'Next customer';

  @override
  String get kassaPrinting => 'Printing receipt…';

  @override
  String get kassaPrinted => 'Receipt printed';

  @override
  String get kassaPrintAgain => 'Print again';

  @override
  String get cardAlreadyRunning => 'A card payment is already in progress.';

  @override
  String get cardEmptyReceipt => 'The receipt is empty.';

  @override
  String cardMinimum(String amount) {
    return 'Card payment only from $amount.';
  }

  @override
  String get cardNotStarted => 'The card payment could not be started.';

  @override
  String get cardDeclined => 'The card payment was not completed.';

  @override
  String get cardCancelled => 'Card payment cancelled.';

  @override
  String get cardNoInternet =>
      'No internet. Card payment is not possible right now.';

  @override
  String get cardNotLoggedIn =>
      'SumUp is not signed in. Please sign in under Settings.';

  @override
  String get cardNoReader =>
      'No card reader connected. Please connect one under Settings.';

  @override
  String get cardPermission =>
      'Kassa needs permission for Bluetooth and location.';

  @override
  String get cardFailed => 'The card payment didn\'t work.';

  @override
  String cardFailedDetail(String detail) {
    return 'The card payment didn\'t work. ($detail)';
  }

  @override
  String get printNotSetUp => 'No receipt printer set up.';

  @override
  String get printUnreachable =>
      'Printer not ready. Is it switched on and connected?';

  @override
  String get printNoPermission =>
      'Kassa is not allowed to use the printer. Please grant permission.';

  @override
  String get printPaperOut => 'Printer not ready. Out of paper.';

  @override
  String get printCoverOpen => 'Printer not ready. The cover is open.';

  @override
  String get printTimeout => 'Printer not ready. It is not responding.';

  @override
  String outageTitle(String since) {
    return 'Signature down since $since';
  }

  @override
  String get outageSellOn => 'You can keep selling as usual.';

  @override
  String get outageKeepsWorking =>
      'Kassa keeps working. Please tell the manager.';

  @override
  String get outageRejected =>
      'A-Trust rejected the login details. Please get the manager.';

  @override
  String get outageNotYet => 'Not working yet.';

  @override
  String get outageBack => 'Signature is working again.';

  @override
  String get outageRetry => 'Check again';

  @override
  String get outageRepin => 'Re-enter PIN';

  @override
  String get unclearTitle => 'Did this card payment go through?';

  @override
  String unclearStarted(String time, String name) {
    return 'Started at $time by $name';
  }

  @override
  String unclearMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count more',
    );
    return '$_temp0';
  }

  @override
  String unclearNoAnswer(String amount, String time) {
    return 'Kassa got no answer from SumUp. Check under Sales in the SumUp app whether $amount arrived at $time.';
  }

  @override
  String get unclearUnreadable =>
      'The receipt can no longer be rebuilt because the menu has changed. Choose No. If the money arrived at SumUp, refund it in the SumUp app and charge again.';

  @override
  String get unclearFailed => 'That didn\'t work. Please try again.';

  @override
  String get unclearYes => 'Yes, it arrived';

  @override
  String get unclearNo => 'No, it didn\'t arrive';

  @override
  String get unclearEffectPaidPrint =>
      'Kassa records the receipt as a card payment and prints it.';

  @override
  String get unclearEffectPaid =>
      'Kassa records the receipt as a card payment.';

  @override
  String get unclearEffectRestore =>
      'Kassa discards the payment and puts the items back on the receipt.';

  @override
  String get unclearEffectDiscard =>
      'Kassa discards the payment. The current receipt stays as it is.';

  @override
  String get unclearConfirm => 'Confirm';

  @override
  String get unclearBack => 'Back';

  @override
  String get dateMonthJanuary => 'January';

  @override
  String get dateMonthFebruary => 'February';

  @override
  String get dateMonthMarch => 'March';

  @override
  String get dateMonthApril => 'April';

  @override
  String get dateMonthMay => 'May';

  @override
  String get dateMonthJune => 'June';

  @override
  String get dateMonthJuly => 'July';

  @override
  String get dateMonthAugust => 'August';

  @override
  String get dateMonthSeptember => 'September';

  @override
  String get dateMonthOctober => 'October';

  @override
  String get dateMonthNovember => 'November';

  @override
  String get dateMonthDecember => 'December';

  @override
  String get dateWeekdayMonday => 'Monday';

  @override
  String get dateWeekdayTuesday => 'Tuesday';

  @override
  String get dateWeekdayWednesday => 'Wednesday';

  @override
  String get dateWeekdayThursday => 'Thursday';

  @override
  String get dateWeekdayFriday => 'Friday';

  @override
  String get dateWeekdaySaturday => 'Saturday';

  @override
  String get dateWeekdaySunday => 'Sunday';

  @override
  String get dateWeekdayShortMonday => 'Mon';

  @override
  String get dateWeekdayShortTuesday => 'Tue';

  @override
  String get dateWeekdayShortWednesday => 'Wed';

  @override
  String get dateWeekdayShortThursday => 'Thu';

  @override
  String get dateWeekdayShortFriday => 'Fri';

  @override
  String get dateWeekdayShortSaturday => 'Sat';

  @override
  String get dateWeekdayShortSunday => 'Sun';

  @override
  String dateWeekdayDayMonth(String weekday, int day, String month) {
    return '$weekday, $day $month';
  }

  @override
  String get bonsTitle => 'Receipts';

  @override
  String bonsToday(String day) {
    return 'Today, $day';
  }

  @override
  String bonsDayLabel(String weekday, int day, String month) {
    return '$weekday, $day $month';
  }

  @override
  String get bonsNoneToday => 'No receipts yet today.';

  @override
  String get bonsNoneForFilter => 'No receipts match this filter.';

  @override
  String get bonsFilterAll => 'All';

  @override
  String get bonsCash => 'Cash';

  @override
  String get bonsCard => 'Card';

  @override
  String get bonsCashAndCard => 'Cash + card';

  @override
  String get bonsVoided => 'Voided';

  @override
  String get bonsVoidReceipt => 'Void';

  @override
  String get bonsKindStart => 'Start receipt';

  @override
  String get bonsKindMonth => 'Monthly receipt';

  @override
  String get bonsKindYear => 'Annual receipt';

  @override
  String get bonsKindZero => 'Zero receipt';

  @override
  String get bonsKindCollective => 'Collective receipt';

  @override
  String get bonsKindClosing => 'Final receipt';

  @override
  String bonsNumberShort(int number) {
    return 'No. $number';
  }

  @override
  String get bonsPrint => 'Print';

  @override
  String get bonsVoid => 'Void';

  @override
  String get bonsNothingSelected => 'Tap a receipt to view it.';

  @override
  String bonsTime(String time) {
    return '$time';
  }

  @override
  String get bonsDeposit => 'Deposit';

  @override
  String bonsTaxRate(int percent) {
    return '$percent % VAT';
  }

  @override
  String get bonsPayment => 'Payment';

  @override
  String bonsVoidOf(String number) {
    return 'Void of receipt no. $number';
  }

  @override
  String bonsVoidedBy(String name) {
    return 'Voided by $name';
  }

  @override
  String bonsCreatedBy(String name) {
    return 'Created by $name';
  }

  @override
  String bonsRungUpBy(String name) {
    return 'Rung up by $name';
  }

  @override
  String get bonsVoidedNotCounted =>
      'Voided. This receipt does not count towards revenue.';

  @override
  String bonsVoidedByNotCounted(String name) {
    return 'Voided by $name. This receipt does not count towards revenue.';
  }

  @override
  String bonsCashBoxId(String id) {
    return 'Register ID $id';
  }

  @override
  String get bonsTestReceipt => 'Test receipt';

  @override
  String get bonsDeviceFailed => 'Signature device failed';

  @override
  String get bonsProbeSignature => 'Test receipt with trial signature.';

  @override
  String get bonsQrOnPaper => 'The QR code is also on the printed receipt.';

  @override
  String get bonsVoidFailed => 'The void could not be saved. Please try again.';

  @override
  String get bonsVoidOlderThanProbe =>
      'This receipt is older than the trial signature and cannot be voided.';

  @override
  String get bonsVoidFromTestTime =>
      'This receipt is from the test period and cannot be voided.';

  @override
  String bonsVoidQuestion(int number) {
    return 'Void receipt no. $number?';
  }

  @override
  String bonsVoidCashBack(String amount) {
    return 'You give back $amount in cash.';
  }

  @override
  String get bonsVoidCardHint =>
      'The money is not refunded automatically. Please refund the payment in the SumUp app.';

  @override
  String get bonsVoidConfirmCard => 'Void, I\'ll refund in SumUp';

  @override
  String get bonsVoidConfirm => 'Yes, void';

  @override
  String get itemsTitle => 'Items';

  @override
  String get itemsWithChoice => 'With choices';

  @override
  String itemsPlusDeposit(String amount) {
    return 'plus $amount deposit';
  }

  @override
  String get itemsColumnItem => 'Item';

  @override
  String get itemsPrice => 'Price';

  @override
  String get itemsFavorite => 'Favorite';

  @override
  String get itemsInSale => 'For sale';

  @override
  String itemsFavoriteRemove(String name) {
    return 'Remove $name from favorites';
  }

  @override
  String itemsFavoriteAdd(String name) {
    return 'Add $name to favorites';
  }

  @override
  String itemsInSaleLabel(String name) {
    return '$name for sale';
  }

  @override
  String get itemsChangePrice => 'Change price';

  @override
  String itemsDepositToggle(String amount) {
    return 'Deposit $amount';
  }

  @override
  String get itemsVegan => 'Vegan';

  @override
  String get itemsSpicy => 'Spicy';

  @override
  String get itemsTaxRate => 'Tax rate';

  @override
  String get itemsChoiceWhenRinging => 'Choices when ringing up';

  @override
  String itemsChoiceGroups(String groups) {
    return '$groups.';
  }

  @override
  String get itemsFromMenuFile =>
      'Names, photos and new items come from the menu file.';

  @override
  String get itemsWriteFailed => 'That didn\'t work. Please try again.';

  @override
  String itemsNewPrice(String amount) {
    return 'New price, currently $amount';
  }

  @override
  String get itemsApply => 'Apply';

  @override
  String get overviewTitle => 'Overview';

  @override
  String get overviewRangeToday => 'Today';

  @override
  String get overviewRange7 => '7 days';

  @override
  String get overviewRange30 => '30 days';

  @override
  String get overviewLast7 => 'Last 7 days';

  @override
  String get overviewLast30 => 'Last 30 days';

  @override
  String overviewHourRange(int from, int to) {
    return '$from:00–$to:00';
  }

  @override
  String overviewSameAsWeekday(String weekday) {
    return 'Same as last $weekday';
  }

  @override
  String overviewMoreThanWeekday(int percent, String weekday) {
    return '$percent % more than last $weekday';
  }

  @override
  String overviewLessThanWeekday(int percent, String weekday) {
    return '$percent % less than last $weekday';
  }

  @override
  String overviewSameAsDaysBefore(int days) {
    return 'Same as the $days days before';
  }

  @override
  String overviewMoreThanDaysBefore(int percent, int days) {
    return '$percent % more than the $days days before';
  }

  @override
  String overviewLessThanDaysBefore(int percent, int days) {
    return '$percent % less than the $days days before';
  }

  @override
  String get overviewRevenue => 'Revenue';

  @override
  String get overviewReceipts => 'Receipts';

  @override
  String get overviewPerReceipt => 'Per receipt';

  @override
  String get overviewVoids => 'Voids';

  @override
  String get overviewPerHour => 'Revenue per hour';

  @override
  String get overviewPerDay => 'Revenue per day';

  @override
  String get overviewNoneInRange => 'No receipts in this period yet.';

  @override
  String overviewBarLabel(String label, String amount) {
    return '$label, $amount';
  }

  @override
  String get overviewLoadFailed => 'The figures could not be loaded.';

  @override
  String get overviewRetry => 'Try again';

  @override
  String get overviewPayments => 'Payment methods';

  @override
  String get overviewNoReceipts => 'No receipts yet.';

  @override
  String get overviewTopItems => 'Best sellers';

  @override
  String get overviewByCategory => 'By category';

  @override
  String closeClockTime(String time) {
    return '$time';
  }

  @override
  String closeBonCount(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted receipts',
      one: '1 receipt',
    );
    return '$_temp0';
  }

  @override
  String get closeReasonBank => 'Bank';

  @override
  String get closeReasonPurchase => 'Purchase';

  @override
  String get closeReasonChange => 'Float';

  @override
  String get closeReasonOther => 'Other';

  @override
  String get closeCashIn => 'Cash in';

  @override
  String get closeCashOut => 'Cash out';

  @override
  String get closeCloseSheet => 'Close';

  @override
  String get closeAmount => 'Amount';

  @override
  String get closeReason => 'Reason';

  @override
  String get closeSaveCashIn => 'Save cash in';

  @override
  String get closeSaveCashOut => 'Save cash out';

  @override
  String get closeFloatTitle => 'Float';

  @override
  String get closeFloatQuestionDrawer =>
      'How much float was in the drawer this morning?';

  @override
  String get closeFloatQuestion => 'How much float was there this morning?';

  @override
  String get closeSaveFloat => 'Save float';

  @override
  String get closeNothingTyped => 'Nothing entered yet';

  @override
  String get closeExact => 'Exactly right';

  @override
  String get closeMissing => 'Short by';

  @override
  String get closeTooMuchDrawer => 'Too much in the drawer';

  @override
  String get closeTooMuchCash => 'Too much cash';

  @override
  String get closeCountDrawer => 'Count cash drawer';

  @override
  String get closeCountCash => 'Count cash';

  @override
  String closeStep(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get closeExpectedDrawer => 'Expected in drawer';

  @override
  String get closeExpectedCash => 'Expected in cash';

  @override
  String get closeCounted => 'Counted';

  @override
  String get closeNext => 'Next';

  @override
  String get closeLeaveInDrawer => 'Leave in drawer';

  @override
  String get closeFloatForTomorrow => 'Float for tomorrow';

  @override
  String get closeDifferenceToExpected => 'Difference to expected';

  @override
  String get closeLeaveQuestionDrawer =>
      'How much stays in the drawer as float?';

  @override
  String get closeLeaveQuestion => 'How much stays as float?';

  @override
  String get closeMoreThanCounted => 'You cannot leave more than was counted.';

  @override
  String get closeYouTakeOut => 'You take out';

  @override
  String get closeBack => 'Back';

  @override
  String get closeCloseDay => 'Close day';

  @override
  String get closeDayClosed => 'Day closed';

  @override
  String get closeDayIsClosed => 'The day is closed.';

  @override
  String get closeNoOpenDay => 'There is no open day.';

  @override
  String get closeNextDayStarts =>
      'The next day starts with the first receipt.';

  @override
  String closeTakenOut(String amount) {
    return 'Taken out: $amount';
  }

  @override
  String closeTomorrowDrawer(String amount) {
    return 'Tomorrow there will be $amount float in the drawer.';
  }

  @override
  String closeTomorrow(String amount) {
    return 'Tomorrow there will be $amount float.';
  }

  @override
  String closeClosedBy(String name, String time) {
    return 'Closed by $name at $time';
  }

  @override
  String get closePrintReport => 'Print report';

  @override
  String get closeToKassa => 'To the register';

  @override
  String get closeReportPrinted => 'Report printed.';

  @override
  String get closeTitle => 'Closing';

  @override
  String get closeDay => 'Day';

  @override
  String get closeMonth => 'Month';

  @override
  String get closeClosedPill => 'Closed';

  @override
  String get closeLoadFailed =>
      'That didn\'t work. Please open this area again.';

  @override
  String get closeDrawer => 'Cash drawer';

  @override
  String get closeCash => 'Cash';

  @override
  String get closeFloatMorning => 'Float this morning';

  @override
  String get closeStillOpen => 'Still open';

  @override
  String get closeCashTakings => 'Cash takings';

  @override
  String closeDeposited(String reason) {
    return 'Cash in: $reason';
  }

  @override
  String closeWithdrawn(String reason) {
    return 'Cash out: $reason';
  }

  @override
  String get closeDifference => 'Difference';

  @override
  String get closeIncome => 'Income';

  @override
  String get closeTotal => 'Total';

  @override
  String get closeTax => 'Tax';

  @override
  String get closeRevenue => 'Revenue';

  @override
  String get closeOfWhichVat => 'of which VAT';

  @override
  String closeVatRate(int percent) {
    return 'VAT $percent %';
  }

  @override
  String get closeDepositNoVat => 'Deposit, no VAT';

  @override
  String get closeForgotten => 'The last day has not been closed yet.';

  @override
  String get closeNow => 'Close now';

  @override
  String get dateMonthShortJanuary => 'Jan';

  @override
  String get dateMonthShortFebruary => 'Feb';

  @override
  String get dateMonthShortMarch => 'Mar';

  @override
  String get dateMonthShortApril => 'Apr';

  @override
  String get dateMonthShortMay => 'May';

  @override
  String get dateMonthShortJune => 'Jun';

  @override
  String get dateMonthShortJuly => 'Jul';

  @override
  String get dateMonthShortAugust => 'Aug';

  @override
  String get dateMonthShortSeptember => 'Sep';

  @override
  String get dateMonthShortOctober => 'Oct';

  @override
  String get dateMonthShortNovember => 'Nov';

  @override
  String get dateMonthShortDecember => 'Dec';

  @override
  String closeMonthYear(String month, int year) {
    return '$month $year';
  }

  @override
  String closePeriodSameYear(String from, String to, int year) {
    return '$from to $to $year';
  }

  @override
  String closePeriodTwoYears(String from, String to) {
    return '$from to $to';
  }

  @override
  String closePeriodDates(String from, String to) {
    return '$from to $to';
  }

  @override
  String get closeMonthlyReport => 'Monthly report';

  @override
  String get closeReport => 'Report';

  @override
  String get closePeriod => 'Period';

  @override
  String closeFirstMonthlyReport(String date) {
    return 'The first monthly report is available from $date.';
  }

  @override
  String closeDayMonth(int day, String month) {
    return '$day $month';
  }

  @override
  String get closeNoReceiptsInPeriod => 'There are no receipts in this period.';

  @override
  String get closeRangeHint => 'Tap the first month, then the last.';

  @override
  String closeMonthAvailableHint(String month, String date) {
    return '$month is available from $date, once the month is over.';
  }

  @override
  String get closeTestMode => 'Test mode';

  @override
  String get closePeriodPrinted => 'Report printed.';

  @override
  String get closeSignatureYear => 'Annual signature receipt';

  @override
  String get closeSignatureMonth => 'Monthly signature receipt';

  @override
  String get closeSignatureComes =>
      'Comes automatically with the next receipt.';

  @override
  String closeSignatureCreated(String date, String time, int number) {
    return 'Created on $date at $time, receipt no. $number';
  }

  @override
  String get closePrint => 'Print';

  @override
  String get closeDays => 'Days';

  @override
  String get closeMonths => 'Months';

  @override
  String get closeScreenOnly => 'on screen only, not on paper';

  @override
  String get closeAlsoOnPaper => 'also on paper';

  @override
  String get closeOneMonth => 'One month';

  @override
  String get closeFromTo => 'From – to';

  @override
  String get closeYearBefore => 'Previous year';

  @override
  String get closeYearAfter => 'Next year';

  @override
  String get closeNoPrinter => 'No printer set up.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String settingsRegisterAt(String business) {
    return 'Kassa 1 at $business';
  }

  @override
  String get settingsDevices => 'Devices on this register';

  @override
  String get settingsDrawer => 'Cash drawer';

  @override
  String get settingsDrawerHelp => 'Turn off if there is no cash drawer.';

  @override
  String get settingsDeviceTest => 'Test devices';

  @override
  String get settingsDeviceTestHelp => 'Test print, open drawer.';

  @override
  String get settingsDisplay => 'Display';

  @override
  String get settingsImages => 'Items with pictures';

  @override
  String get settingsImagesHelp => 'Large buttons with a photo.';

  @override
  String get settingsView => 'Appearance';

  @override
  String get settingsViewHelp =>
      'Dark is easier on the eyes in the evening and in dark rooms.';

  @override
  String get settingsThemeSystem => 'Like the tablet';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsRegister => 'Register';

  @override
  String get settingsVoidChef => 'Only the manager can void';

  @override
  String get settingsVoidChefHelp => 'Staff then cannot void receipts.';

  @override
  String get settingsPayments => 'Payments';

  @override
  String get settingsSplitPayment => 'Part cash, rest by card';

  @override
  String get settingsCardTip => 'Tip on card payments';

  @override
  String get settingsDiscount => 'Discount';

  @override
  String get settingsOpenAmount => 'Open amount';

  @override
  String get settingsAccessOff => 'Off';

  @override
  String get settingsAccessAll => 'Everyone';

  @override
  String get settingsAccessChef => 'Manager only';

  @override
  String get settingsDepositReturn => 'Deposit return';

  @override
  String get settingsVoucher => 'Voucher';

  @override
  String get settingsVoucherInfo => 'Sell and redeem vouchers';

  @override
  String get settingsInvoice => 'Invoice to a business';

  @override
  String get settingsInvoiceInfo =>
      'Print the receipt with the customer\'s name and address';

  @override
  String get settingsReceiptTitle => 'Customer receipt';

  @override
  String get settingsReceiptAlways => 'Always print';

  @override
  String get settingsReceiptAlwaysInfo => 'After every sale, as before';

  @override
  String get settingsReceiptBoth => 'Print and digital';

  @override
  String get settingsReceiptBothInfo => 'Print and also show the QR code';

  @override
  String get settingsReceiptDigital => 'Digital, print on request';

  @override
  String get settingsReceiptDigitalInfo =>
      'Show the QR code, print only on tap';

  @override
  String get settingsReceiptNeedsServer =>
      'Only works when Kassa is connected to the server.';

  @override
  String get settingsReceiptQrHint =>
      'The customer must be able to see the QR code on the screen.';

  @override
  String settingsVersion(String version) {
    return 'Kassa version $version';
  }

  @override
  String get kitchenTitle => 'KITCHEN';

  @override
  String get kitchenVoided => 'VOID';

  @override
  String get kitchenCopy => 'COPY';

  @override
  String get kitchenSample => 'SAMPLE';

  @override
  String get settingsKitchen => 'Kitchen';

  @override
  String get settingsKitchenMode => 'Kitchen ticket';

  @override
  String get settingsKitchenOff => 'Off';

  @override
  String get settingsKitchenAtReceiptPrinter => 'On receipt printer';

  @override
  String get settingsKitchenAtKitchenPrinter => 'On kitchen printer';

  @override
  String get settingsKitchenLanguage => 'Kitchen ticket language';

  @override
  String get settingsKitchenNoPrinter =>
      'No kitchen printer set up. No kitchen ticket will print.';

  @override
  String get settingsKitchenCategories => 'Categories for the kitchen';

  @override
  String get settingsKitchenCategoryOn => 'go on the kitchen ticket';

  @override
  String get settingsKitchenCategoryOff => 'not on the kitchen ticket';

  @override
  String get settingsKitchenPreview => 'Preview';

  @override
  String get settingsKitchenSample => 'Print sample';

  @override
  String get settingsKitchenSamplePrinting => 'Printing…';

  @override
  String get settingsKitchenSamplePrinted => 'Sample printed.';

  @override
  String get kassaKitchenNotPrinted => 'Kitchen ticket not printed';

  @override
  String get kassaKitchenPrint => 'Print kitchen ticket';

  @override
  String get kassaKitchenPrinting => 'Printing kitchen ticket…';

  @override
  String get kassaKitchenPrinted => 'Kitchen ticket printed.';

  @override
  String get bonsKitchenNothing =>
      'Nothing on this receipt is for the kitchen.';

  @override
  String get settingsKitchenNoReceiptPrinter =>
      'No receipt printer set up. No kitchen ticket will print.';

  @override
  String kassaKitchenLateMore(int count) {
    return 'More kitchen tickets not printed: $count';
  }

  @override
  String get kassaKitchenDismiss => 'Dismiss';

  @override
  String get tipGuestPays => 'Guest pays';

  @override
  String get tipTip => 'Tip';

  @override
  String get tipNone => 'No tip';

  @override
  String tipToTerminal(String amount) {
    return 'To terminal $amount';
  }

  @override
  String tipConfirm(String amount) {
    return 'Tip $amount?';
  }

  @override
  String get tipConfirmYes => 'Yes, that\'s right';

  @override
  String get tipConfirmNo => 'Change';

  @override
  String get tipTooLow => 'The amount is less than the total.';

  @override
  String kassaTipDone(String amount) {
    return 'incl. tip $amount';
  }

  @override
  String unclearTip(String amount) {
    return 'Including tip $amount';
  }

  @override
  String get closeReasonTip => 'Tip';

  @override
  String get splitWhole => 'Full amount';

  @override
  String get splitPart => 'Part cash';

  @override
  String get splitCashPart => 'Cash part';

  @override
  String get splitRest => 'Rest by card';

  @override
  String splitGo(String amount) {
    return 'Continue to card $amount';
  }

  @override
  String get splitNeedCash => 'Enter the cash part.';

  @override
  String splitRestTooSmall(String amount) {
    return 'Rest by card at least $amount.';
  }

  @override
  String splitCardFailed(String amount) {
    return 'Card not paid. Give back $amount in cash or try again.';
  }

  @override
  String kassaCashPartDone(String amount) {
    return 'Cash part $amount';
  }

  @override
  String unclearCashPart(String amount) {
    return 'Cash part $amount has already been taken.';
  }

  @override
  String unclearReturnCash(String amount) {
    return 'Give back $amount in cash.';
  }

  @override
  String bonsVoidMixedCash(String amount) {
    return 'Give back $amount in cash.';
  }

  @override
  String bonsVoidCardBack(String amount) {
    return 'Refund $amount in SumUp.';
  }

  @override
  String bonsVoidCardBackTip(String amount, String tip) {
    return 'Refund $amount in SumUp, incl. tip $tip.';
  }

  @override
  String get discountTitle => 'Discount';

  @override
  String discountOn(String what) {
    return 'Discount on: $what';
  }

  @override
  String get discountWholeReceipt => 'whole receipt';

  @override
  String get discountReason => 'Reason';

  @override
  String get discountReasonRegular => 'Regular';

  @override
  String get discountReasonStaff => 'Staff';

  @override
  String get discountReasonComplaint => 'Complaint';

  @override
  String get discountReasonPromotion => 'Promotion';

  @override
  String get discountReasonInvitation => 'On the house';

  @override
  String get discountHeight => 'How much';

  @override
  String get discountAmount => 'Amount';

  @override
  String get discountNew => 'New';

  @override
  String get discountRemove => 'Remove';

  @override
  String get discountApply => 'Apply';

  @override
  String get discountLineHint =>
      'For a single line, tap that line on the receipt.';

  @override
  String discountRowPercent(int percent, String reason) {
    return '−$percent % $reason';
  }

  @override
  String discountRowAmount(String reason) {
    return 'Discount $reason';
  }

  @override
  String get openAmountTitle => 'Open amount';

  @override
  String get openAmountAmount => 'Amount';

  @override
  String get openAmountTax => 'Tax rate';

  @override
  String get openAmountAdd => 'Add to receipt';

  @override
  String get openAmountNeedTax => 'Choose a tax rate';

  @override
  String openAmountLine(int percent) {
    return 'Misc. $percent %';
  }

  @override
  String get closeDiscounts => 'Discounts';

  @override
  String get closeCardTip => 'Card tips';

  @override
  String get closeCardAccount => 'To card account';

  @override
  String get bonsSubtotal => 'Subtotal';

  @override
  String get bonsTipIncluded => 'of which tip';

  @override
  String get kassaMore => 'More';

  @override
  String get kassaDepositReturn => 'Deposit return';

  @override
  String get depositReturnTotal => 'Refund';

  @override
  String get depositReturnAdd => 'Add to receipt';

  @override
  String kassaPayOut(String amount) {
    return 'Pay out cash $amount';
  }

  @override
  String get kassaPayOutDone => 'Pay out';

  @override
  String get kassaVoucher => 'Voucher';

  @override
  String get voucherSell => 'Sell';

  @override
  String get voucherCheck => 'Check';

  @override
  String get voucherOther => 'Other amount';

  @override
  String get voucherAdd => 'Add to receipt';

  @override
  String voucherRange(String min, String max) {
    return 'From $min to $max';
  }

  @override
  String get voucherNotWithRedeem =>
      'This receipt is being paid with a voucher.';

  @override
  String get voucherCode => 'Code';

  @override
  String get voucherValue => 'Value';

  @override
  String get voucherBalance => 'Balance';

  @override
  String get voucherUnknown => 'The register does not know this voucher.';

  @override
  String get voucherStateActive => 'Valid';

  @override
  String get voucherStateEmpty => 'Used up';

  @override
  String get voucherStateVoided => 'Voided';

  @override
  String get voucherStateOverdrawn => 'Overdrawn';

  @override
  String get voucherIsTest => 'Test voucher';

  @override
  String get voucherMoveSale => 'Sold';

  @override
  String get voucherMoveRedeem => 'Redeemed';

  @override
  String get voucherMoveVoidSale => 'Sale voided';

  @override
  String get voucherMoveVoidRedeem => 'Redemption voided';

  @override
  String get voucherPrint => 'Print voucher';

  @override
  String get bonsVoidVoucherRedeemed =>
      'The voucher has already been redeemed. This receipt cannot be voided.';

  @override
  String get bonsVoucherPrinted => 'Voucher printed';

  @override
  String get kassaPayVoucher => 'Voucher';

  @override
  String get voucherRedeemTitle => 'Redeem voucher';

  @override
  String get voucherDue => 'To pay';

  @override
  String get voucherUse => 'Redeemed now';

  @override
  String get voucherLeft => 'Left on voucher';

  @override
  String voucherRedeemAll(String amount) {
    return 'Redeem $amount';
  }

  @override
  String voucherRedeemPart(String amount, String rest) {
    return 'Redeem $amount, $rest left to pay';
  }

  @override
  String get voucherEmpty => 'This voucher is used up.';

  @override
  String get voucherVoided => 'This voucher has been voided.';

  @override
  String get voucherTestOnly => 'This is a test voucher.';

  @override
  String get voucherLiveOnly => 'This voucher is not valid in test mode.';

  @override
  String get voucherAlreadyOnReceipt =>
      'This voucher is already on the receipt.';

  @override
  String get kassaDue => 'Still to pay';

  @override
  String get kassaFinishVoucher => 'Finish with voucher';

  @override
  String get kassaPaidByVoucher => 'Paid with voucher';

  @override
  String get voucherChanged => 'The balance has changed. Please check again.';

  @override
  String unclearVoucherPart(String amount) {
    return 'With voucher $amount';
  }

  @override
  String voucherWithCode(String code) {
    return 'Voucher $code';
  }

  @override
  String get invoiceButton => 'Invoice to company';

  @override
  String get invoiceRecipient => 'Invoice to';

  @override
  String get invoicePrint => 'Print invoice';

  @override
  String get invoiceChange => 'Change';

  @override
  String get invoicePrinted => 'Invoice printed.';

  @override
  String get invoiceHint400 =>
      'Over 400 €: An invoice needs the customer\'s name and address.';

  @override
  String get customerPickerTitle => 'Choose business customer';

  @override
  String get customerAll => 'All';

  @override
  String get customerNew => 'New customer';

  @override
  String get customerEmpty => 'No business customer saved yet.';

  @override
  String get customerFormTitle => 'Invoice recipient';

  @override
  String get customerName => 'Company name';

  @override
  String get customerAddress1 => 'Street and number';

  @override
  String get customerAddress2 => 'Postcode and city';

  @override
  String get customerVatId => 'VAT ID (if any)';

  @override
  String get customerKeep => 'Save as business customer';

  @override
  String get customerSave => 'Apply';

  @override
  String get customerCancel => 'Cancel';

  @override
  String get customerSaveFailed => 'That didn\'t work. Please try again.';

  @override
  String get customerNameMissing => 'Please enter the name.';

  @override
  String get customerAddressMissing => 'Please enter the address.';

  @override
  String get customerVatIdMissing =>
      'Over 10,000 € the invoice needs the customer\'s VAT ID.';

  @override
  String get customerTooLong => 'The text is too long.';

  @override
  String get kassaReceiptQrCaption => 'Take your receipt on your phone';

  @override
  String get kassaPrintReceiptNow => 'Print receipt';

  @override
  String get kassaReceiptOfflinePrinted => 'No internet, printing receipt.';

  @override
  String get kassaReceiptOfflineLater =>
      'No internet: the digital receipt will be available later.';

  @override
  String get bonsDeliveryTitle => 'Receipt';

  @override
  String get bonsDeliveryPrinted => 'Printed';

  @override
  String get bonsDeliveryDigital => 'Offered digitally';

  @override
  String get closeVoucherPaid => 'Paid with voucher';

  @override
  String get closeVoucherSold => 'Vouchers sold';

  @override
  String get closeDepositReturn => 'Deposit return';

  @override
  String get closeTaxVouchers => 'of which vouchers';

  @override
  String get bonsPaymentVoucher => 'Voucher';

  @override
  String get bonsFilterVoucher => 'Voucher';

  @override
  String get bonsVoucherLeft => 'Remaining balance';
}
