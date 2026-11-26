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
  String get outageRepin => 'PIN\'i yeniden girin';

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
}
