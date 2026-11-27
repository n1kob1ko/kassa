// ignore_for_file: deprecated_member_use

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class L10nTr extends L10n {
  L10nTr([String locale = 'tr']) : super(locale);

  @override
  String get languageSectionTitle => 'Dil';

  @override
  String get languageSheetTitle => 'Dil';

  @override
  String get languageChangeLabel => 'Dili değiştir';

  @override
  String get loginTitle => 'PIN girin';

  @override
  String get loginHint => 'Herkesin kendi PIN\'i var';

  @override
  String get loginWrongPin => 'Bu PIN kayıtlı değil.';

  @override
  String get loginFailed => 'Olmadı. Lütfen tekrar deneyin.';

  @override
  String loginDigitsEntered(int filled) {
    return '4 haneden $filled tanesi girildi';
  }

  @override
  String get shellTabKassa => 'Kasa';

  @override
  String get shellTabBons => 'Fişler';

  @override
  String get shellTabOverview => 'Genel bakış';

  @override
  String get shellTabItems => 'Ürünler';

  @override
  String get shellTabClose => 'Kapanış';

  @override
  String get shellOffline => 'İnternet yok. Nakit satış devam ediyor.';

  @override
  String shellSwitchStaff(String name) {
    return 'Personel değiştir, giriş yapan: $name';
  }

  @override
  String get shellSettings => 'Ayarlar';

  @override
  String get uiUndo => 'Geri al';

  @override
  String get uiKeypadComma => 'Virgül';

  @override
  String get uiKeypadDot => 'Nokta';

  @override
  String get uiKeypadDelete => 'Son haneyi sil';

  @override
  String get uiReceiptQr => 'Fiş QR kodu';

  @override
  String get uiListSeparator => ', ';

  @override
  String kassaItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ürün',
    );
    return '$_temp0';
  }

  @override
  String kassaCategoryLabel(String name, String items) {
    return '$name, $items';
  }

  @override
  String get kassaFavorites => 'Favoriler';

  @override
  String get kassaWithImages => 'Resimli';

  @override
  String get kassaCompact => 'Kompakt';

  @override
  String get kassaPlusDeposit => '+ depozito';

  @override
  String get kassaNotForSale => 'Satışta değil';

  @override
  String kassaOnReceipt(int count) {
    return 'Fişte $count adet';
  }

  @override
  String get kassaTagVegan => 'VEGAN';

  @override
  String get kassaTagSpicy => 'ACI';

  @override
  String kassaOneLess(String name) {
    return 'Bir azalt: $name';
  }

  @override
  String kassaOneMore(String name) {
    return 'Bir artır: $name';
  }

  @override
  String get kassaReceipt => 'Fiş';

  @override
  String get kassaClearCart => 'Fişi temizle';

  @override
  String get kassaCartCleared => 'Fiş temizlendi';

  @override
  String get kassaEmptyTitle => 'Henüz ürün yok';

  @override
  String get kassaEmptyHint =>
      'Bir ürüne dokunun. Her dokunuş fişe bir adet ekler.';

  @override
  String get kassaTotal => 'Toplam';

  @override
  String kassaDepositIncluded(String amount) {
    return 'Depozito dahil $amount';
  }

  @override
  String kassaTaxIncluded(String amount) {
    return 'KDV dahil $amount';
  }

  @override
  String get kassaCash => 'Nakit';

  @override
  String get kassaCard => 'Kart';

  @override
  String get kassaCardNotSetUp => 'kurulmadı';

  @override
  String get kassaCardLoggedOut => 'oturum kapalı';

  @override
  String get kassaCardNoInternet => 'internet yok';

  @override
  String kassaCardFrom(String amount) {
    return 'en az $amount';
  }

  @override
  String get kassaCancel => 'Vazgeç';

  @override
  String get kassaAddToReceipt => 'Fişe ekle';

  @override
  String kassaStillToChoose(String groups) {
    return 'Seçilecek: $groups';
  }

  @override
  String get kassaPickOne => 'bir seçim';

  @override
  String get kassaAtMostOne => 'en fazla bir';

  @override
  String kassaAtLeast(int min) {
    return 'en az $min';
  }

  @override
  String kassaUpTo(int max) {
    return 'en fazla $max';
  }

  @override
  String get kassaPleaseChoose => 'Lütfen seçin';

  @override
  String kassaChosenCount(int count) {
    return '$count seçildi';
  }

  @override
  String kassaOptionChosen(String name) {
    return '$name, seçildi';
  }

  @override
  String get kassaPayCashTitle => 'Nakit ödeme';

  @override
  String get kassaBackToReceipt => 'Fişe dön';

  @override
  String get kassaAmountDue => 'Ödenecek';

  @override
  String get kassaGiven => 'Alınan';

  @override
  String get kassaExact => 'Tam';

  @override
  String get kassaOtherAmount => 'Başka tutar';

  @override
  String get kassaShowSuggestions => 'Önerileri göster';

  @override
  String get kassaStillMissing => 'Eksik';

  @override
  String get kassaChange => 'Para üstü';

  @override
  String get kassaSaveFailed => 'Fiş kaydedilemedi. Lütfen tekrar deneyin.';

  @override
  String get kassaFinish => 'Tamamla';

  @override
  String get kassaFinishAndPrint => 'Tamamla ve fiş yazdır';

  @override
  String get kassaWaitingForCard => 'Kart bekleniyor';

  @override
  String get kassaCardHint =>
      'Müşteri kartını veya telefonunu cihaza yaklaştırır.';

  @override
  String get kassaPaid => 'Ödendi';

  @override
  String kassaReceiptNumber(int number) {
    return 'Fiş No. $number';
  }

  @override
  String get kassaPaidExact => 'Tam ödendi';

  @override
  String get kassaGiveChange => 'Para üstünü verin';

  @override
  String get kassaGiveChangeFromDrawer => 'Para üstünü çekmeceden verin';

  @override
  String get kassaPaidByCard => 'Kartla ödendi';

  @override
  String get kassaNextCustomer => 'Sonraki müşteri';

  @override
  String get kassaPrinting => 'Fiş yazdırılıyor…';

  @override
  String get kassaPrinted => 'Fiş yazdırıldı';

  @override
  String get kassaPrintAgain => 'Tekrar yazdır';

  @override
  String get cardAlreadyRunning => 'Zaten bir kart ödemesi sürüyor.';

  @override
  String get cardEmptyReceipt => 'Fiş boş.';

  @override
  String cardMinimum(String amount) {
    return 'Kartla ödeme en az $amount.';
  }

  @override
  String get cardNotStarted => 'Kart ödemesi başlatılamadı.';

  @override
  String get cardDeclined => 'Kart ödemesi tamamlanmadı.';

  @override
  String get cardCancelled => 'Kart ödemesi iptal edildi.';

  @override
  String get cardNoInternet => 'İnternet yok. Kartla ödeme şu an yapılamıyor.';

  @override
  String get cardNotLoggedIn =>
      'SumUp\'ta oturum açılmamış. Lütfen Ayarlar\'dan oturum açın.';

  @override
  String get cardNoReader =>
      'Kart okuyucu bağlı değil. Lütfen Ayarlar\'dan bağlayın.';

  @override
  String get cardPermission => 'Kassa\'nın Bluetooth ve konum izni gerekiyor.';

  @override
  String get cardFailed => 'Kart ödemesi başarısız oldu.';

  @override
  String cardFailedDetail(String detail) {
    return 'Kart ödemesi başarısız oldu. ($detail)';
  }

  @override
  String get printNotSetUp => 'Fiş yazıcısı kurulmamış.';

  @override
  String get printUnreachable => 'Yazıcı hazır değil. Açık ve bağlı mı?';

  @override
  String get printNoPermission =>
      'Kassa yazıcıyı kullanamıyor. Lütfen izin verin.';

  @override
  String get printPaperOut => 'Yazıcı hazır değil. Kağıt bitti.';

  @override
  String get printCoverOpen => 'Yazıcı hazır değil. Kapak açık.';

  @override
  String get printTimeout => 'Yazıcı hazır değil. Yanıt vermiyor.';

  @override
  String outageTitle(String since) {
    return 'İmza $since itibarıyla devre dışı';
  }

  @override
  String get outageSellOn => 'Satışa normal şekilde devam edebilirsiniz.';

  @override
  String get outageKeepsWorking =>
      'Kassa çalışmaya devam ediyor. Lütfen yöneticiye haber verin.';

  @override
  String get outageRejected =>
      'A-Trust giriş bilgilerini reddetti. Lütfen yöneticiyi çağırın.';

  @override
  String get outageNotYet => 'Henüz çalışmıyor.';

  @override
  String get outageBack => 'İmza yeniden çalışıyor.';

  @override
  String get outageRetry => 'Tekrar kontrol et';

  @override
  String get outageRepin => 'PIN\'i yeniden gir';

  @override
  String get unclearTitle => 'Bu kart ödemesi başarılı oldu mu?';

  @override
  String unclearStarted(String time, String name) {
    return '$name tarafından $time saatinde başlatıldı';
  }

  @override
  String unclearMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 've $count tane daha',
    );
    return '$_temp0';
  }

  @override
  String unclearNoAnswer(String amount, String time) {
    return 'Kassa SumUp\'tan yanıt alamadı. SumUp uygulamasında Satışlar bölümünde $time saatindeki $amount tutarının gelip gelmediğine bakın.';
  }

  @override
  String get unclearUnreadable =>
      'Menü değiştiği için fiş artık oluşturulamıyor. Hayır\'ı seçin. Para SumUp\'a ulaştıysa SumUp uygulamasında iade edin ve yeniden tahsil edin.';

  @override
  String get unclearFailed => 'Olmadı. Lütfen tekrar deneyin.';

  @override
  String get unclearYes => 'Evet, ulaştı';

  @override
  String get unclearNo => 'Hayır, ulaşmadı';

  @override
  String get unclearEffectPaidPrint =>
      'Kassa fişi kartla ödeme olarak kaydeder ve yazdırır.';

  @override
  String get unclearEffectPaid => 'Kassa fişi kartla ödeme olarak kaydeder.';

  @override
  String get unclearEffectRestore =>
      'Kassa ödemeyi siler ve ürünleri yeniden fişe ekler.';

  @override
  String get unclearEffectDiscard =>
      'Kassa ödemeyi siler. Mevcut fiş olduğu gibi kalır.';

  @override
  String get unclearConfirm => 'Onayla';

  @override
  String get unclearBack => 'Geri';

  @override
  String get dateMonthJanuary => 'Ocak';

  @override
  String get dateMonthFebruary => 'Şubat';

  @override
  String get dateMonthMarch => 'Mart';

  @override
  String get dateMonthApril => 'Nisan';

  @override
  String get dateMonthMay => 'Mayıs';

  @override
  String get dateMonthJune => 'Haziran';

  @override
  String get dateMonthJuly => 'Temmuz';

  @override
  String get dateMonthAugust => 'Ağustos';

  @override
  String get dateMonthSeptember => 'Eylül';

  @override
  String get dateMonthOctober => 'Ekim';

  @override
  String get dateMonthNovember => 'Kasım';

  @override
  String get dateMonthDecember => 'Aralık';

  @override
  String get dateWeekdayMonday => 'Pazartesi';

  @override
  String get dateWeekdayTuesday => 'Salı';

  @override
  String get dateWeekdayWednesday => 'Çarşamba';

  @override
  String get dateWeekdayThursday => 'Perşembe';

  @override
  String get dateWeekdayFriday => 'Cuma';

  @override
  String get dateWeekdaySaturday => 'Cumartesi';

  @override
  String get dateWeekdaySunday => 'Pazar';

  @override
  String get dateWeekdayShortMonday => 'Pzt';

  @override
  String get dateWeekdayShortTuesday => 'Sal';

  @override
  String get dateWeekdayShortWednesday => 'Çar';

  @override
  String get dateWeekdayShortThursday => 'Per';

  @override
  String get dateWeekdayShortFriday => 'Cum';

  @override
  String get dateWeekdayShortSaturday => 'Cmt';

  @override
  String get dateWeekdayShortSunday => 'Paz';

  @override
  String dateWeekdayDayMonth(String weekday, int day, String month) {
    return '$day $month $weekday';
  }

  @override
  String get bonsTitle => 'Fişler';

  @override
  String bonsToday(String day) {
    return 'Bugün, $day';
  }

  @override
  String bonsDayLabel(String weekday, int day, String month) {
    return '$day $month $weekday';
  }

  @override
  String get bonsNoneToday => 'Bugün henüz fiş yok.';

  @override
  String get bonsNoneForFilter => 'Bu filtreye uygun fiş yok.';

  @override
  String get bonsFilterAll => 'Tümü';

  @override
  String get bonsCash => 'Nakit';

  @override
  String get bonsCard => 'Kart';

  @override
  String get bonsCashAndCard => 'Nakit + kart';

  @override
  String get bonsVoided => 'İptal edildi';

  @override
  String get bonsVoidReceipt => 'İptal fişi';

  @override
  String get bonsKindStart => 'Başlangıç fişi';

  @override
  String get bonsKindMonth => 'Aylık fiş';

  @override
  String get bonsKindYear => 'Yıllık fiş';

  @override
  String get bonsKindZero => 'Sıfır fiş';

  @override
  String get bonsKindCollective => 'Toplu fiş';

  @override
  String get bonsKindClosing => 'Kapanış fişi';

  @override
  String bonsNumberShort(int number) {
    return 'No. $number';
  }

  @override
  String get bonsPrint => 'Yazdır';

  @override
  String get bonsVoid => 'İptal et';

  @override
  String get bonsNothingSelected => 'Görmek için bir fişe dokunun.';

  @override
  String bonsTime(String time) {
    return '$time';
  }

  @override
  String get bonsDeposit => 'Depozito';

  @override
  String bonsTaxRate(int percent) {
    return 'KDV $percent %';
  }

  @override
  String get bonsPayment => 'Ödeme';

  @override
  String bonsVoidOf(String number) {
    return 'Fiş No. $number iptali';
  }

  @override
  String bonsVoidedBy(String name) {
    return 'İptal eden: $name';
  }

  @override
  String bonsCreatedBy(String name) {
    return 'Oluşturan: $name';
  }

  @override
  String bonsRungUpBy(String name) {
    return 'Kasiyer: $name';
  }

  @override
  String get bonsVoidedNotCounted =>
      'İptal edildi. Bu fiş ciroya dahil edilmez.';

  @override
  String bonsVoidedByNotCounted(String name) {
    return '$name tarafından iptal edildi. Bu fiş ciroya dahil edilmez.';
  }

  @override
  String bonsCashBoxId(String id) {
    return 'Kasa kimliği $id';
  }

  @override
  String get bonsTestReceipt => 'Test fişi';

  @override
  String get bonsDeviceFailed => 'Güvenlik cihazı arızalı';

  @override
  String get bonsProbeSignature => 'Deneme imzalı test fişi.';

  @override
  String get bonsQrOnPaper => 'QR kod basılı fişte de bulunur.';

  @override
  String get bonsVoidFailed => 'İptal kaydedilemedi. Lütfen tekrar deneyin.';

  @override
  String get bonsVoidOlderThanProbe =>
      'Bu fiş deneme imzasından eski ve iptal edilemez.';

  @override
  String get bonsVoidFromTestTime =>
      'Bu fiş test döneminden ve iptal edilemez.';

  @override
  String bonsVoidQuestion(int number) {
    return 'Fiş No. $number iptal edilsin mi?';
  }

  @override
  String bonsVoidCashBack(String amount) {
    return '$amount nakit iade edersiniz.';
  }

  @override
  String get bonsVoidCardHint =>
      'Para otomatik olarak iade edilmez. Lütfen ödemeyi SumUp uygulamasında iade edin.';

  @override
  String get bonsVoidConfirmCard => 'İptal et, iadeyi SumUp\'ta yapacağım';

  @override
  String get bonsVoidConfirm => 'Evet, iptal et';

  @override
  String get itemsTitle => 'Ürünler';

  @override
  String get itemsWithChoice => 'Seçenekli';

  @override
  String itemsPlusDeposit(String amount) {
    return 'artı $amount depozito';
  }

  @override
  String get itemsColumnItem => 'Ürün';

  @override
  String get itemsPrice => 'Fiyat';

  @override
  String get itemsFavorite => 'Favori';

  @override
  String get itemsInSale => 'Satışta';

  @override
  String itemsFavoriteRemove(String name) {
    return '$name favorilerden çıkar';
  }

  @override
  String itemsFavoriteAdd(String name) {
    return '$name favorilere ekle';
  }

  @override
  String itemsInSaleLabel(String name) {
    return '$name satışta';
  }

  @override
  String get itemsChangePrice => 'Fiyatı değiştir';

  @override
  String itemsDepositToggle(String amount) {
    return 'Depozito $amount';
  }

  @override
  String get itemsVegan => 'Vegan';

  @override
  String get itemsSpicy => 'Acı';

  @override
  String get itemsTaxRate => 'KDV oranı';

  @override
  String get itemsChoiceWhenRinging => 'Fişe eklerken seçenekler';

  @override
  String itemsChoiceGroups(String groups) {
    return '$groups.';
  }

  @override
  String get itemsFromMenuFile =>
      'Adlar, fotoğraflar ve yeni ürünler menü dosyasından gelir.';

  @override
  String get itemsWriteFailed => 'Olmadı. Lütfen tekrar deneyin.';

  @override
  String itemsNewPrice(String amount) {
    return 'Yeni fiyat, şu an $amount';
  }

  @override
  String get itemsApply => 'Uygula';

  @override
  String get overviewTitle => 'Genel bakış';

  @override
  String get overviewRangeToday => 'Bugün';

  @override
  String get overviewRange7 => '7 gün';

  @override
  String get overviewRange30 => '30 gün';

  @override
  String get overviewLast7 => 'Son 7 gün';

  @override
  String get overviewLast30 => 'Son 30 gün';

  @override
  String overviewHourRange(int from, int to) {
    return '$from:00–$to:00';
  }

  @override
  String overviewSameAsWeekday(String weekday) {
    return 'Geçen $weekday ile aynı';
  }

  @override
  String overviewMoreThanWeekday(int percent, String weekday) {
    return 'Geçen $weekday gününden $percent % fazla';
  }

  @override
  String overviewLessThanWeekday(int percent, String weekday) {
    return 'Geçen $weekday gününden $percent % az';
  }

  @override
  String overviewSameAsDaysBefore(int days) {
    return 'Önceki $days gün ile aynı';
  }

  @override
  String overviewMoreThanDaysBefore(int percent, int days) {
    return 'Önceki $days günden $percent % fazla';
  }

  @override
  String overviewLessThanDaysBefore(int percent, int days) {
    return 'Önceki $days günden $percent % az';
  }

  @override
  String get overviewRevenue => 'Ciro';

  @override
  String get overviewReceipts => 'Fişler';

  @override
  String get overviewPerReceipt => 'Fiş başına';

  @override
  String get overviewVoids => 'İptaller';

  @override
  String get overviewPerHour => 'Saatlik ciro';

  @override
  String get overviewPerDay => 'Günlük ciro';

  @override
  String get overviewNoneInRange => 'Bu dönemde henüz fiş yok.';

  @override
  String overviewBarLabel(String label, String amount) {
    return '$label, $amount';
  }

  @override
  String get overviewLoadFailed => 'Rakamlar yüklenemedi.';

  @override
  String get overviewRetry => 'Tekrar dene';

  @override
  String get overviewPayments => 'Ödeme yöntemleri';

  @override
  String get overviewNoReceipts => 'Henüz fiş yok.';

  @override
  String get overviewTopItems => 'En çok satanlar';

  @override
  String get overviewByCategory => 'Kategoriye göre';

  @override
  String closeClockTime(String time) {
    return '$time';
  }

  @override
  String closeBonCount(int count, String formatted) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formatted fiş',
    );
    return '$_temp0';
  }

  @override
  String get closeReasonBank => 'Banka';

  @override
  String get closeReasonPurchase => 'Alışveriş';

  @override
  String get closeReasonChange => 'Bozuk para';

  @override
  String get closeReasonOther => 'Diğer';

  @override
  String get closeCashIn => 'Para girişi';

  @override
  String get closeCashOut => 'Para çıkışı';

  @override
  String get closeCloseSheet => 'Kapat';

  @override
  String get closeAmount => 'Tutar';

  @override
  String get closeReason => 'Neden';

  @override
  String get closeSaveCashIn => 'Girişi kaydet';

  @override
  String get closeSaveCashOut => 'Çıkışı kaydet';

  @override
  String get closeFloatTitle => 'Bozuk para';

  @override
  String get closeFloatQuestionDrawer =>
      'Sabah çekmecede ne kadar bozuk para vardı?';

  @override
  String get closeFloatQuestion => 'Sabah ne kadar bozuk para vardı?';

  @override
  String get closeSaveFloat => 'Bozuk parayı kaydet';

  @override
  String get closeNothingTyped => 'Henüz bir şey girilmedi';

  @override
  String get closeExact => 'Tam tutuyor';

  @override
  String get closeMissing => 'Eksik';

  @override
  String get closeTooMuchDrawer => 'Çekmecede fazla';

  @override
  String get closeTooMuchCash => 'Fazla nakit';

  @override
  String get closeCountDrawer => 'Çekmeceyi say';

  @override
  String get closeCountCash => 'Nakdi say';

  @override
  String closeStep(int step, int total) {
    return 'Adım $step/$total';
  }

  @override
  String get closeExpectedDrawer => 'Çekmecede beklenen';

  @override
  String get closeExpectedCash => 'Beklenen nakit';

  @override
  String get closeCounted => 'Sayılan';

  @override
  String get closeNext => 'İleri';

  @override
  String get closeLeaveInDrawer => 'Çekmecede bırak';

  @override
  String get closeFloatForTomorrow => 'Yarın için bozuk para';

  @override
  String get closeDifferenceToExpected => 'Beklenenle fark';

  @override
  String get closeLeaveQuestionDrawer =>
      'Çekmecede ne kadar bozuk para kalsın?';

  @override
  String get closeLeaveQuestion => 'Ne kadar bozuk para kalsın?';

  @override
  String get closeMoreThanCounted => 'Sayılandan fazlası çekmecede kalamaz.';

  @override
  String get closeYouTakeOut => 'Çıkardığınız';

  @override
  String get closeBack => 'Geri';

  @override
  String get closeCloseDay => 'Günü kapat';

  @override
  String get closeDayClosed => 'Gün kapatıldı';

  @override
  String get closeDayIsClosed => 'Gün kapatıldı.';

  @override
  String get closeNoOpenDay => 'Açık gün yok.';

  @override
  String get closeNextDayStarts => 'Sonraki gün ilk fişle başlar.';

  @override
  String closeTakenOut(String amount) {
    return 'Çıkarılan: $amount';
  }

  @override
  String closeTomorrowDrawer(String amount) {
    return 'Yarın çekmecede $amount bozuk para olacak.';
  }

  @override
  String closeTomorrow(String amount) {
    return 'Yarın $amount bozuk para olacak.';
  }

  @override
  String closeClosedBy(String name, String time) {
    return '$name tarafından $time saatinde kapatıldı';
  }

  @override
  String get closePrintReport => 'Raporu yazdır';

  @override
  String get closeToKassa => 'Kasaya dön';

  @override
  String get closeReportPrinted => 'Rapor yazdırıldı.';

  @override
  String get closeTitle => 'Gün sonu';

  @override
  String get closeDay => 'Gün';

  @override
  String get closeMonth => 'Ay';

  @override
  String get closeClosedPill => 'Kapatıldı';

  @override
  String get closeLoadFailed => 'Olmadı. Lütfen bu bölümü yeniden açın.';

  @override
  String get closeDrawer => 'Para çekmecesi';

  @override
  String get closeCash => 'Nakit';

  @override
  String get closeFloatMorning => 'Sabahki bozuk para';

  @override
  String get closeStillOpen => 'Henüz açık';

  @override
  String get closeCashTakings => 'Nakit gelir';

  @override
  String closeDeposited(String reason) {
    return 'Giriş: $reason';
  }

  @override
  String closeWithdrawn(String reason) {
    return 'Çıkış: $reason';
  }

  @override
  String get closeDifference => 'Fark';

  @override
  String get closeIncome => 'Gelirler';

  @override
  String get closeTotal => 'Toplam';

  @override
  String get closeTax => 'Vergi';

  @override
  String get closeRevenue => 'Ciro';

  @override
  String get closeOfWhichVat => 'KDV tutarı';

  @override
  String closeVatRate(int percent) {
    return 'KDV $percent %';
  }

  @override
  String get closeDepositNoVat => 'Depozito, KDV\'siz';

  @override
  String get closeForgotten => 'Son gün henüz kapatılmadı.';

  @override
  String get closeNow => 'Şimdi kapat';

  @override
  String get dateMonthShortJanuary => 'Oca';

  @override
  String get dateMonthShortFebruary => 'Şub';

  @override
  String get dateMonthShortMarch => 'Mar';

  @override
  String get dateMonthShortApril => 'Nis';

  @override
  String get dateMonthShortMay => 'May';

  @override
  String get dateMonthShortJune => 'Haz';

  @override
  String get dateMonthShortJuly => 'Tem';

  @override
  String get dateMonthShortAugust => 'Ağu';

  @override
  String get dateMonthShortSeptember => 'Eyl';

  @override
  String get dateMonthShortOctober => 'Eki';

  @override
  String get dateMonthShortNovember => 'Kas';

  @override
  String get dateMonthShortDecember => 'Ara';

  @override
  String closeMonthYear(String month, int year) {
    return '$month $year';
  }

  @override
  String closePeriodSameYear(String from, String to, int year) {
    return '$from – $to $year';
  }

  @override
  String closePeriodTwoYears(String from, String to) {
    return '$from – $to';
  }

  @override
  String closePeriodDates(String from, String to) {
    return '$from – $to';
  }

  @override
  String get closeMonthlyReport => 'Aylık rapor';

  @override
  String get closeReport => 'Rapor';

  @override
  String get closePeriod => 'Dönem';

  @override
  String closeFirstMonthlyReport(String date) {
    return 'İlk aylık rapor $date tarihinden itibaren hazır.';
  }

  @override
  String closeDayMonth(int day, String month) {
    return '$day $month';
  }

  @override
  String get closeNoReceiptsInPeriod => 'Bu dönemde fiş yok.';

  @override
  String get closeRangeHint => 'Önce ilk aya, sonra son aya dokunun.';

  @override
  String closeMonthAvailableHint(String month, String date) {
    return '$month, ay bittiğinde $date tarihinden itibaren hazır.';
  }

  @override
  String get closeTestMode => 'Test modu';

  @override
  String get closePeriodPrinted => 'Rapor yazdırıldı.';

  @override
  String get closeSignatureYear => 'İmzanın yıllık fişi';

  @override
  String get closeSignatureMonth => 'İmzanın aylık fişi';

  @override
  String get closeSignatureComes => 'Sonraki fişle kendiliğinden gelir.';

  @override
  String closeSignatureCreated(String date, String time, int number) {
    return '$date tarihinde $time saatinde oluşturuldu, Fiş No. $number';
  }

  @override
  String get closePrint => 'Yazdır';

  @override
  String get closeDays => 'Günler';

  @override
  String get closeMonths => 'Aylar';

  @override
  String get closeScreenOnly => 'yalnızca ekranda, kâğıtta değil';

  @override
  String get closeAlsoOnPaper => 'kâğıtta da yer alır';

  @override
  String get closeOneMonth => 'Tek ay';

  @override
  String get closeFromTo => 'Başlangıç – bitiş';

  @override
  String get closeYearBefore => 'Önceki yıl';

  @override
  String get closeYearAfter => 'Sonraki yıl';

  @override
  String get closeNoPrinter => 'Yazıcı kurulmadı.';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String settingsRegisterAt(String business) {
    return '$business – Kassa 1';
  }

  @override
  String get settingsDevices => 'Bu kasadaki cihazlar';

  @override
  String get settingsDrawer => 'Para çekmecesi';

  @override
  String get settingsDrawerHelp => 'Para çekmecesi yoksa kapatın.';

  @override
  String get settingsDeviceTest => 'Cihazları test et';

  @override
  String get settingsDeviceTestHelp => 'Test baskısı, çekmeceyi açma.';

  @override
  String get settingsDisplay => 'Görünüm';

  @override
  String get settingsImages => 'Resimli ürünler';

  @override
  String get settingsImagesHelp => 'Fotoğraflı büyük düğmeler.';

  @override
  String get settingsView => 'Tema';

  @override
  String get settingsViewHelp =>
      'Koyu tema akşamları ve karanlık ortamlarda daha rahattır.';

  @override
  String get settingsThemeSystem => 'Tablet gibi';

  @override
  String get settingsThemeLight => 'Açık';

  @override
  String get settingsThemeDark => 'Koyu';

  @override
  String get settingsRegister => 'Kasa';

  @override
  String get settingsVoidChef => 'Yalnızca yönetici iptal edebilir';

  @override
  String get settingsVoidChefHelp => 'Çalışanlar bu durumda fiş iptal edemez.';

  @override
  String get settingsPayments => 'Ödeme';

  @override
  String get settingsSplitPayment => 'Bir kısmı nakit, kalanı kart';

  @override
  String get settingsCardTip => 'Kartla ödemede bahşiş';

  @override
  String get settingsDiscount => 'İndirim';

  @override
  String get settingsOpenAmount => 'Serbest tutar';

  @override
  String get settingsAccessOff => 'Kapalı';

  @override
  String get settingsAccessAll => 'Herkes';

  @override
  String get settingsAccessChef => 'Yalnızca yönetici';

  @override
  String get settingsDepositReturn => 'Depozito iadesi';

  @override
  String get settingsVoucher => 'Hediye çeki';

  @override
  String get settingsVoucherInfo => 'Hediye çeki sat ve kullan';

  @override
  String get settingsInvoice => 'Firmaya fatura';

  @override
  String get settingsInvoiceInfo => 'Fişi müşterinin adı ve adresiyle yazdır';

  @override
  String get settingsReceiptTitle => 'Müşteri fişi';

  @override
  String get settingsReceiptAlways => 'Her zaman yazdır';

  @override
  String get settingsReceiptAlwaysInfo => 'Her satıştan sonra, eskisi gibi';

  @override
  String get settingsReceiptBoth => 'Yazdır ve dijital';

  @override
  String get settingsReceiptBothInfo => 'Yazdır ve ayrıca QR kodu göster';

  @override
  String get settingsReceiptDigital => 'Dijital, istenirse yazdır';

  @override
  String get settingsReceiptDigitalInfo =>
      'QR kodu göster, yalnızca dokununca yazdır';

  @override
  String get settingsReceiptNeedsServer =>
      'Yalnızca Kassa sunucuya bağlıyken çalışır.';

  @override
  String get settingsReceiptQrHint => 'Müşteri QR kodu ekranda görebilmelidir.';

  @override
  String settingsVersion(String version) {
    return 'Kassa sürüm $version';
  }

  @override
  String get kitchenTitle => 'MUTFAK';

  @override
  String get kitchenVoided => 'İPTAL';

  @override
  String get kitchenCopy => 'KOPYA';

  @override
  String get kitchenSample => 'DENEME';

  @override
  String get settingsKitchen => 'Mutfak';

  @override
  String get settingsKitchenMode => 'Mutfak fişi';

  @override
  String get settingsKitchenOff => 'Kapalı';

  @override
  String get settingsKitchenAtReceiptPrinter => 'Fiş yazıcısında';

  @override
  String get settingsKitchenAtKitchenPrinter => 'Mutfak yazıcısında';

  @override
  String get settingsKitchenLanguage => 'Mutfak fişinin dili';

  @override
  String get settingsKitchenNoPrinter =>
      'Mutfak yazıcısı kurulmamış. Mutfak fişi yazdırılmaz.';

  @override
  String get settingsKitchenCategories => 'Mutfak için kategoriler';

  @override
  String get settingsKitchenCategoryOn => 'mutfak fişine yazılır';

  @override
  String get settingsKitchenCategoryOff => 'mutfak fişine yazılmaz';

  @override
  String get settingsKitchenPreview => 'Önizleme';

  @override
  String get settingsKitchenSample => 'Örnek yazdır';

  @override
  String get settingsKitchenSamplePrinting => 'Yazdırılıyor…';

  @override
  String get settingsKitchenSamplePrinted => 'Örnek yazdırıldı.';

  @override
  String get kassaKitchenNotPrinted => 'Mutfak fişi yazdırılmadı';

  @override
  String get kassaKitchenPrint => 'Mutfak fişini yazdır';

  @override
  String get kassaKitchenPrinting => 'Mutfak fişi yazdırılıyor…';

  @override
  String get kassaKitchenPrinted => 'Mutfak fişi yazdırıldı.';

  @override
  String get bonsKitchenNothing => 'Bu fişte mutfak için bir şey yok.';

  @override
  String get settingsKitchenNoReceiptPrinter =>
      'Fiş yazıcısı kurulmamış. Mutfak fişi yazdırılmaz.';

  @override
  String kassaKitchenLateMore(int count) {
    return 'Yazdırılmayan diğer mutfak fişleri: $count';
  }

  @override
  String get kassaKitchenDismiss => 'Gizle';

  @override
  String get tipGuestPays => 'Misafir öder';

  @override
  String get tipTip => 'Bahşiş';

  @override
  String get tipNone => 'Bahşişsiz';

  @override
  String tipToTerminal(String amount) {
    return 'Terminale $amount';
  }

  @override
  String tipConfirm(String amount) {
    return 'Bahşiş $amount?';
  }

  @override
  String get tipConfirmYes => 'Evet, doğru';

  @override
  String get tipConfirmNo => 'Değiştir';

  @override
  String get tipTooLow => 'Tutar toplamdan küçük.';

  @override
  String kassaTipDone(String amount) {
    return 'bunun $amount kadarı bahşiş';
  }

  @override
  String unclearTip(String amount) {
    return 'Bunun $amount kadarı bahşiş';
  }

  @override
  String get closeReasonTip => 'Bahşiş';

  @override
  String get splitWhole => 'Tam tutar';

  @override
  String get splitPart => 'Kısmen nakit';

  @override
  String get splitCashPart => 'Nakit kısmı';

  @override
  String get splitRest => 'Kalanı kartla';

  @override
  String splitGo(String amount) {
    return 'Karta geç $amount';
  }

  @override
  String get splitNeedCash => 'Nakit kısmını girin.';

  @override
  String splitRestTooSmall(String amount) {
    return 'Kartla kalan en az $amount.';
  }

  @override
  String splitCardFailed(String amount) {
    return 'Kart ödenmedi. $amount nakit iade edin veya tekrar deneyin.';
  }

  @override
  String kassaCashPartDone(String amount) {
    return 'Nakit kısmı $amount';
  }

  @override
  String unclearCashPart(String amount) {
    return 'Nakit kısmı $amount zaten alındı.';
  }

  @override
  String unclearReturnCash(String amount) {
    return '$amount nakit iade edin.';
  }

  @override
  String bonsVoidMixedCash(String amount) {
    return '$amount nakit iade edin.';
  }

  @override
  String bonsVoidCardBack(String amount) {
    return '$amount tutarını SumUp\'ta iade edin.';
  }

  @override
  String bonsVoidCardBackTip(String amount, String tip) {
    return '$amount tutarını SumUp\'ta iade edin, bunun $tip kadarı bahşiş.';
  }

  @override
  String get discountTitle => 'İndirim';

  @override
  String discountOn(String what) {
    return 'İndirim: $what';
  }

  @override
  String get discountWholeReceipt => 'tüm fiş';

  @override
  String get discountReason => 'Neden';

  @override
  String get discountReasonRegular => 'Müdavim';

  @override
  String get discountReasonStaff => 'Personel';

  @override
  String get discountReasonComplaint => 'Şikayet';

  @override
  String get discountReasonPromotion => 'Kampanya';

  @override
  String get discountReasonInvitation => 'İkram';

  @override
  String get discountHeight => 'Ne kadar';

  @override
  String get discountAmount => 'Tutar';

  @override
  String get discountNew => 'Yeni';

  @override
  String get discountRemove => 'Kaldır';

  @override
  String get discountApply => 'Uygula';

  @override
  String get discountLineHint => 'Tek bir satır için fişteki satıra dokunun.';

  @override
  String discountRowPercent(int percent, String reason) {
    return '−$percent % $reason';
  }

  @override
  String discountRowAmount(String reason) {
    return 'İndirim $reason';
  }

  @override
  String get openAmountTitle => 'Serbest tutar';

  @override
  String get openAmountAmount => 'Tutar';

  @override
  String get openAmountTax => 'KDV oranı';

  @override
  String get openAmountAdd => 'Fişe ekle';

  @override
  String get openAmountNeedTax => 'Vergi oranı seçin';

  @override
  String openAmountLine(int percent) {
    return 'Çeşitli $percent %';
  }

  @override
  String get closeDiscounts => 'İndirimler';

  @override
  String get closeCardTip => 'Kart bahşişi';

  @override
  String get closeCardAccount => 'Kart hesabına';

  @override
  String get bonsSubtotal => 'Ara toplam';

  @override
  String get bonsTipIncluded => 'bunun bahşişi';

  @override
  String get kassaMore => 'Daha fazla';

  @override
  String get kassaDepositReturn => 'Depozito iadesi';

  @override
  String get depositReturnTotal => 'İade';

  @override
  String get depositReturnAdd => 'Fişe ekle';

  @override
  String kassaPayOut(String amount) {
    return 'Nakit öde $amount';
  }

  @override
  String get kassaPayOutDone => 'Geri öde';
}
