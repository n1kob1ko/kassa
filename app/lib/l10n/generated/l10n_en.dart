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
  String get kassaStillMissing => 'Still due';

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
  String get kassaPaidExact => 'Paid exact';

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
}
