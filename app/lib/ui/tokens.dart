import 'package:material_ui/material_ui.dart';

/// Alle Maße, Abstände, Rundungen und Zeiten aus DESIGN.md.
/// Farben stehen in [KassaColors] (zwei Paletten, hell und dunkel).
class KassaTokens {
  const KassaTokens._();

  /// Akzent Petrol, in beiden Ansichten gleich.
  static const Color accent = Color(0xFF0F766E);

  /// Schrift und Symbole auf [accent] (immer Weiß).
  static const Color onAccent = Color(0xFFFFFFFF);

  /// Abdunkelung hinter einem Blatt, das alles darunter sperrt: Tinte der
  /// hellen Ansicht (#14171A) zu 50 %, in beiden Ansichten gleich dunkel.
  static const Color scrim = Color(0x8014171A);

  // Tippflächen
  static const double minTap = 48.0;
  static const double primaryActionHeight = 72.0;
  static const double mainActionHeight = 80.0;
  static const double secondaryActionHeight = 72.0;

  /// Reiter, Segmente und Plus/Minus sind im Entwurf 44 dp hoch. Das
  /// Aussehen bleibt, die Antippfläche wird unsichtbar auf [minTap] erweitert.
  static const double drawnControlHeight = 44.0;
  static const double minGapBetweenTaps = 6.0;

  // Bewegung (120 bis 320 ms, nur um Zustand zu zeigen)
  static const Duration motionFast = Duration(milliseconds: 120);
  static const Duration motionSwitch = Duration(milliseconds: 160);
  static const Duration motionFade = Duration(milliseconds: 180);
  static const Duration motionSnack = Duration(milliseconds: 220);
  static const Duration motionSlow = Duration(milliseconds: 320);

  /// Aufleuchten einer neuen Bon-Zeile. Der Entwurf zeichnet 700 ms, die App
  /// begrenzt auf 320 ms (Bewegung nie länger als 320 ms).
  static const Duration receiptLineFlash = motionSlow;
  static const Duration snackStay = Duration(seconds: 7);
  static const Curve motionCurve = Cubic(0.2, 0.8, 0.2, 1);
  static const double pressScale = 0.97;
  static const double pressBrightness = 0.95;
  static const double disabledOpacity = 0.4;

  // Rundungen
  static const double radiusXs = 5.0;
  static const double radiusSm = 7.0;
  static const double radiusMd = 10.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 14.0;
  static const double radiusXxl = 16.0;
  static const double radiusCard = 20.0;
  static const double radiusPill = 999.0;

  // Abstände
  static const double spaceXxs = 2.0;
  static const double spaceXs = 4.0;
  static const double spaceSm = 6.0;
  static const double spaceMd = 8.0;
  static const double spaceLg = 10.0;
  static const double spaceXl = 12.0;
  static const double spaceXxl = 16.0;
  static const double spaceHuge = 24.0;

  // Ränder
  static const double borderThin = 1.0;
  static const double borderButton = 1.5;
  static const double borderStrong = 2.0;
  static const double focusRing = 3.0;
  static const double focusRingGap = 2.0;

  // Layout (Entwurf 1280 x 800)
  static const double designWidth = 1280.0;
  static const double designHeight = 800.0;
  static const double headerHeight = 60.0;
  static const double categoryColumnWidth = 196.0;
  static const double receiptColumnWidth = 392.0;
  static const double gridGap = 10.0;
  static const double gridRowHeightImage = 157.0;
  static const double gridRowHeightCompact = 90.0;
  static const double receiptHeaderHeight = 64.0;
  static const double receiptLineMinHeight = 64.0;
  static const double categoryButtonHeight = 52.0;
  static const double keypadKeyHeight = 56.0;
  static const double keypadInputHeight = 60.0;

  /// Tasten der Sprachauswahl (Einstellungen, Blatt am Anmeldebildschirm).
  static const double languageButtonHeight = 64.0;

  /// Sprachtaste oben am Anmeldebildschirm.
  static const double loginLanguageButtonHeight = 52.0;

  // Schrift
  static const String fontFamily = 'Figtree';

  /// Hinter Figtree: die mitgelieferten Schriften für Arabisch und
  /// Chinesisch, dann die Schrift des Geräts für seltene Zeichen.
  static const List<String> fontFallback = [
    'Noto Sans Arabic',
    'Noto Sans SC',
    'Roboto',
  ];

  /// Schrift mit gleich breiten Zeichen für Werte, die jemand abschreibt
  /// (Kennungen, Schlüssel): Null mit Punkt, I, l und 1 deutlich verschieden.
  /// Nur SemiBold (600) liegt bei.
  static const String monoFontFamily = 'JetBrains Mono';

  /// Systemschrift darf die Oberfläche höchstens so weit vergrößern.
  static const double maxTextScale = 1.3;
}

/// Die Farbpalette einer Ansicht. Hell und dunkel haben dieselben Namen.
@immutable
class KassaColors extends ThemeExtension<KassaColors> {
  const KassaColors({
    required this.accent,
    required this.accentSoft,
    required this.accentInk,
    required this.accentSnack,
    required this.onAccent,
    required this.ground,
    required this.card,
    required this.fill,
    required this.fill2,
    required this.line,
    required this.ink,
    required this.ink2,
    required this.solid,
    required this.solidInk,
    required this.red,
    required this.green,
    required this.warnBg,
    required this.warnInk,
    required this.veganBg,
    required this.veganFg,
    required this.spicyBg,
    required this.spicyFg,
    required this.cardShadow,
  });

  final Color accent;
  final Color accentSoft;
  final Color accentInk;
  final Color accentSnack;
  final Color onAccent;
  final Color ground;
  final Color card;
  final Color fill;
  final Color fill2;
  final Color line;
  final Color ink;
  final Color ink2;
  final Color solid;
  final Color solidInk;
  final Color red;
  final Color green;
  final Color warnBg;
  final Color warnInk;
  final Color veganBg;
  final Color veganFg;
  final Color spicyBg;
  final Color spicyFg;

  /// Schatten der Karten: nur hell, dunkel keiner.
  final List<BoxShadow> cardShadow;

  static const light = KassaColors(
    accent: KassaTokens.accent,
    accentSoft: Color(0xFFE7F1F1),
    accentInk: Color(0xFF0C615A),
    accentSnack: Color(0xFFA4CBC8),
    onAccent: KassaTokens.onAccent,
    ground: Color(0xFFF3F4F6),
    card: Color(0xFFFFFFFF),
    fill: Color(0xFFF1F2F4),
    fill2: Color(0xFFE7E9ED),
    line: Color(0xFFE2E5E9),
    ink: Color(0xFF14171A),
    ink2: Color(0xFF5B6470),
    solid: Color(0xFF14171A),
    solidInk: Color(0xFFFFFFFF),
    red: Color(0xFFB42318),
    green: Color(0xFF15803D),
    warnBg: Color(0xFFFFF1CC),
    warnInk: Color(0xFF6B4200),
    veganBg: Color(0xFFDDF3E4),
    veganFg: Color(0xFF14592B),
    spicyBg: Color(0xFFFDE3DF),
    spicyFg: Color(0xFFA1201A),
    cardShadow: [
      BoxShadow(color: Color(0x0F101828), offset: Offset(0, 1), blurRadius: 2),
      BoxShadow(color: Color(0x08101828), offset: Offset(0, 1), blurRadius: 1),
    ],
  );

  static const dark = KassaColors(
    accent: KassaTokens.accent,
    accentSoft: Color(0xFF173233),
    accentInk: Color(0xFF9AC5C2),
    accentSnack: Color(0xFF0D645E),
    onAccent: KassaTokens.onAccent,
    ground: Color(0xFF0E1012),
    card: Color(0xFF191C20),
    fill: Color(0xFF22262B),
    fill2: Color(0xFF2B3036),
    line: Color(0xFF2C3138),
    ink: Color(0xFFF2F4F6),
    ink2: Color(0xFFA3ACB6),
    solid: Color(0xFFF2F4F6),
    solidInk: Color(0xFF14171A),
    red: Color(0xFFFF8A80),
    green: Color(0xFF3DBB6E),
    warnBg: Color(0xFF3D2E00),
    warnInk: Color(0xFFFFD77A),
    veganBg: Color(0xFF173B24),
    veganFg: Color(0xFFB9F0CB),
    spicyBg: Color(0xFF4A1A16),
    spicyFg: Color(0xFFFFC9C2),
    cardShadow: [],
  );

  static KassaColors of(BuildContext context) =>
      Theme.of(context).extension<KassaColors>()!;

  @override
  KassaColors copyWith({
    Color? accent,
    Color? accentSoft,
    Color? accentInk,
    Color? accentSnack,
    Color? onAccent,
    Color? ground,
    Color? card,
    Color? fill,
    Color? fill2,
    Color? line,
    Color? ink,
    Color? ink2,
    Color? solid,
    Color? solidInk,
    Color? red,
    Color? green,
    Color? warnBg,
    Color? warnInk,
    Color? veganBg,
    Color? veganFg,
    Color? spicyBg,
    Color? spicyFg,
    List<BoxShadow>? cardShadow,
  }) {
    return KassaColors(
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentInk: accentInk ?? this.accentInk,
      accentSnack: accentSnack ?? this.accentSnack,
      onAccent: onAccent ?? this.onAccent,
      ground: ground ?? this.ground,
      card: card ?? this.card,
      fill: fill ?? this.fill,
      fill2: fill2 ?? this.fill2,
      line: line ?? this.line,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      solid: solid ?? this.solid,
      solidInk: solidInk ?? this.solidInk,
      red: red ?? this.red,
      green: green ?? this.green,
      warnBg: warnBg ?? this.warnBg,
      warnInk: warnInk ?? this.warnInk,
      veganBg: veganBg ?? this.veganBg,
      veganFg: veganFg ?? this.veganFg,
      spicyBg: spicyBg ?? this.spicyBg,
      spicyFg: spicyFg ?? this.spicyFg,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  KassaColors lerp(ThemeExtension<KassaColors>? other, double t) {
    if (other is! KassaColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return KassaColors(
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      accentInk: l(accentInk, other.accentInk),
      accentSnack: l(accentSnack, other.accentSnack),
      onAccent: l(onAccent, other.onAccent),
      ground: l(ground, other.ground),
      card: l(card, other.card),
      fill: l(fill, other.fill),
      fill2: l(fill2, other.fill2),
      line: l(line, other.line),
      ink: l(ink, other.ink),
      ink2: l(ink2, other.ink2),
      solid: l(solid, other.solid),
      solidInk: l(solidInk, other.solidInk),
      red: l(red, other.red),
      green: l(green, other.green),
      warnBg: l(warnBg, other.warnBg),
      warnInk: l(warnInk, other.warnInk),
      veganBg: l(veganBg, other.veganBg),
      veganFg: l(veganFg, other.veganFg),
      spicyBg: l(spicyBg, other.spicyBg),
      spicyFg: l(spicyFg, other.spicyFg),
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }
}
