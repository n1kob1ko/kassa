// Sprachen der Kassa und Art des Küchenbons.

import 'dart:ui';

/// Sprachen der Oberfläche und des Küchenbons. Der Name in der Auswahl steht
/// immer in der Sprache selbst.
enum AppLanguage {
  de('Deutsch'),
  en('English'),
  zh('中文'),
  tr('Türkçe'),
  ar('العربية');

  const AppLanguage(this.nativeName);

  final String nativeName;

  /// Nur Arabisch wird von rechts nach links gelesen.
  bool get isRtl => this == AppLanguage.ar;

  Locale get locale => Locale(name);

  /// Unbekannter oder fehlender Kürzel: Deutsch.
  static AppLanguage byCode(String? code) {
    for (final v in values) {
      if (v.name == code) return v;
    }
    return AppLanguage.de;
  }
}

/// Wohin der Küchenbon geht.
enum KitchenMode { off, receiptPrinter, kitchenPrinter }
