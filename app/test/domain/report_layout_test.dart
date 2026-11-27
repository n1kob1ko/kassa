import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/day.dart';
import 'package:kassa/domain/period_report.dart';
import 'package:kassa/domain/pricing.dart';
import 'package:kassa/domain/print_document.dart';
import 'package:kassa/domain/report_layout.dart';

List<String> texts(List<PrintOp> d) => [
  for (final o in d)
    if (o is PrintText) o.text,
];

/// Die gedruckten Zeilen, mit 48 Zeichen.
List<String> lines(List<PrintOp> d) => texts(d);

const business = yichi;
final now = printedAt;

const yichi = BusinessInfo(
  name: 'YICHI',
  addressLines: ['Musterstraße 1', '1010 Wien'],
  vatId: 'ATU12345678',
  receiptFooter: 'Danke!',
);

final printedAt = DateTime(2026, 11, 17, 21, 14);
final printedAtMonth = DateTime(2026, 11, 23, 14, 6);

DaySummary daySample({
  DateTime? opened,
  DateTime? closed,
  bool isClosed = true,
  int voidCount = 2,
  int deposit = 950,
  int cardRevenueCents = 79650,
  int discountCount = 0,
  int discountCents = 0,
  int cardTipCents = 0,
  List<StaffTip> tipsByStaff = const [],
}) => DaySummary(
  day: BusinessDay(
    id: 'd1',
    openedAt: opened ?? DateTime(2026, 11, 17, 9, 2),
    closedAt: isClosed ? (closed ?? DateTime(2026, 11, 17, 21, 14)) : null,
    openingFloatCents: 15000,
    countedCents: isClosed ? 66800 : null,
    leftInDrawerCents: isClosed ? 15000 : null,
    expectedCents: isClosed ? 66810 : null,
    differenceCents: isClosed ? -10 : null,
    closedByName: isClosed ? 'Mira' : null,
  ),
  receiptCount: 96,
  cashReceiptCount: 38,
  cardReceiptCount: 58,
  voidCount: voidCount,
  voidedCents: voidCount == 0 ? 0 : 2050,
  revenueCents: 128460,
  cashRevenueCents: 48810,
  cardRevenueCents: cardRevenueCents,
  depositCents: deposit,
  taxLines: const [
    TaxLine(
      rate: TaxRate.normal,
      grossCents: 21250,
      netCents: 17708,
      taxCents: 3542,
    ),
    TaxLine(
      rate: TaxRate.reduced1,
      grossCents: 106260,
      netCents: 96600,
      taxCents: 9660,
    ),
  ],
  openingFloatCents: 15000,
  cashInCents: 5000,
  cashOutCents: 2000,
  expectedCashCents: 66810,
  movements: [
    CashMovement(
      id: 'm1',
      kind: CashMovementKind.deposit,
      amountCents: 5000,
      reason: CashReason.change,
      createdAt: DateTime(2026, 11, 17, 11),
      staffName: 'Mira',
    ),
    CashMovement(
      id: 'm2',
      kind: CashMovementKind.withdrawal,
      amountCents: 2000,
      reason: CashReason.purchase,
      createdAt: DateTime(2026, 11, 17, 15, 30),
      staffName: 'Mira',
    ),
  ],
  firstNumber: 13174,
  lastNumber: 13269,
  discountCount: discountCount,
  discountCents: discountCents,
  cardTipCents: cardTipCents,
  tipsByStaff: tipsByStaff,
);

const monthTax = [
  TaxLine(
    rate: TaxRate.normal,
    grossCents: 318000,
    netCents: 265000,
    taxCents: 53000,
  ),
  TaxLine(
    rate: TaxRate.reduced1,
    grossCents: 1611260,
    netCents: 1464782,
    taxCents: 146478,
  ),
];

PeriodReport monthSample({
  bool testMode = false,
  int voidCount = 9,
  int first = 11292,
  int last = 12399,
  int discountCount = 0,
  int discountCents = 0,
  int cardTipCents = 0,
  List<StaffTip> tipsByStaff = const [],
}) => PeriodReport(
  range: MonthRange(YearMonth(2026, 10), YearMonth(2026, 10)),
  testMode: testMode,
  receiptCount: 1067,
  cashReceiptCount: 412,
  cardReceiptCount: 655,
  voidCount: voidCount,
  voidedCents: 14120,
  revenueCents: 1941210,
  cashRevenueCents: 693040,
  cardRevenueCents: 1248170,
  depositCents: 11950,
  taxLines: monthTax,
  firstNumber: first,
  lastNumber: last,
  rows: [
    PeriodRow(start: DateTime(2026, 10, 1), receiptCount: 40, revenueCents: 1),
  ],
  discountCount: discountCount,
  discountCents: discountCents,
  cardTipCents: cardTipCents,
  tipsByStaff: tipsByStaff,
);

const _months = [
  [1190, 2184030],
  [1121, 2061580],
  [1302, 2390410],
  [1240, 2273160],
  [1318, 2411890],
  [1287, 2356040],
  [1203, 2197720],
  [1215, 2219030],
  [1342, 2460890],
  [1067, 1941210],
];

PeriodReport manySample() => PeriodReport(
  range: MonthRange(YearMonth(2026, 1), YearMonth(2026, 10)),
  testMode: false,
  receiptCount: 12285,
  cashReceiptCount: 4702,
  cardReceiptCount: 7583,
  voidCount: 96,
  voidedCents: 150240,
  revenueCents: 22495960,
  cashRevenueCents: 8041230,
  cardRevenueCents: 14454730,
  depositCents: 138450,
  taxLines: const [
    TaxLine(
      rate: TaxRate.normal,
      grossCents: 3685000,
      netCents: 3070833,
      taxCents: 614167,
    ),
    TaxLine(
      rate: TaxRate.reduced1,
      grossCents: 18672510,
      netCents: 16975009,
      taxCents: 1697501,
    ),
  ],
  firstNumber: 1,
  lastNumber: 12399,
  rows: [
    for (var i = 0; i < 10; i++)
      PeriodRow(
        start: DateTime(2026, i + 1),
        receiptCount: _months[i][0],
        revenueCents: _months[i][1],
      ),
  ],
);

const daySlip42 = [
  'YICHI',
  'Musterstraße 1',
  '1010 Wien',
  'TAGESABSCHLUSS',
  'Dienstag, 17.11.2026',
  'Kassa                                Theke',
  'Von                       17.11.2026 09:02',
  'Bis                       17.11.2026 21:14',
  'Abgeschlossen von                     Mira',
  'Bons Nr.                   13174 bis 13269',
  '------------------------------------------',
  'EINNAHMEN',
  'Bar                 38 Bons         488,10',
  'Karte               58 Bons         796,50',
  'Gesamt              96 Bons       1.284,60',
  'Storniert            2 Bons          20,50',
  '------------------------------------------',
  'STEUER',
  'MwSt 20 %',
  '  Brutto                            212,50',
  '  Netto                             177,08',
  '  Steuer                             35,42',
  'MwSt 10 %',
  '  Brutto                          1.062,60',
  '  Netto                             966,00',
  '  Steuer                             96,60',
  'Pfand, ohne MwSt                      9,50',
  '------------------------------------------',
  'GELDLADE',
  'Wechselgeld am Morgen               150,00',
  'Bar-Einnahmen                       488,10',
  '11:00 Eingelegt: Wechselgeld         50,00',
  '15:30 Entnommen: Einkauf            -20,00',
  'Soll                                668,10',
  'Gezählt                             668,00',
  'Unterschied                          -0,10',
  'In der Lade gelassen                150,00',
  'Entnommen                           518,00',
  '------------------------------------------',
  'Gedruckt 17.11.2026 21:14',
  'Kein Beleg',
];

const monthSlip42 = [
  'YICHI',
  'Musterstraße 1',
  '1010 Wien',
  'MONATSABRECHNUNG',
  'Oktober 2026',
  'Zeitraum         01.10.2026 bis 31.10.2026',
  'Kassa                                Theke',
  'Bons Nr.                   11292 bis 12399',
  '------------------------------------------',
  'EINNAHMEN',
  'Bar                412 Bons       6.930,40',
  'Karte              655 Bons      12.481,70',
  'Gesamt           1.067 Bons      19.412,10',
  'Storniert            9 Bons         141,20',
  '------------------------------------------',
  'STEUER',
  'MwSt 20 %',
  '  Brutto                          3.180,00',
  '  Netto                           2.650,00',
  '  Steuer                            530,00',
  'MwSt 10 %',
  '  Brutto                         16.112,60',
  '  Netto                          14.647,82',
  '  Steuer                          1.464,78',
  'Pfand, ohne MwSt                    119,50',
  '------------------------------------------',
  'Gedruckt 23.11.2026 14:06',
  'Kein Beleg',
];

const manySlip42 = [
  'YICHI',
  'Musterstraße 1',
  '1010 Wien',
  'ABRECHNUNG',
  'Jänner bis Oktober 2026',
  'Zeitraum         01.01.2026 bis 31.10.2026',
  'Kassa                                Theke',
  'Bons Nr.                       1 bis 12399',
  '------------------------------------------',
  'EINNAHMEN',
  'Bar              4.702 Bons      80.412,30',
  'Karte            7.583 Bons     144.547,30',
  'Gesamt          12.285 Bons     224.959,60',
  'Storniert           96 Bons       1.502,40',
  '------------------------------------------',
  'STEUER',
  'MwSt 20 %',
  '  Brutto                         36.850,00',
  '  Netto                          30.708,33',
  '  Steuer                          6.141,67',
  'MwSt 10 %',
  '  Brutto                        186.725,10',
  '  Netto                         169.750,09',
  '  Steuer                         16.975,01',
  'Pfand, ohne MwSt                  1.384,50',
  '------------------------------------------',
  'MONATE',
  'Jänner 2026      1.190 Bons      21.840,30',
  'Februar 2026     1.121 Bons      20.615,80',
  'März 2026        1.302 Bons      23.904,10',
  'April 2026       1.240 Bons      22.731,60',
  'Mai 2026         1.318 Bons      24.118,90',
  'Juni 2026        1.287 Bons      23.560,40',
  'Juli 2026        1.203 Bons      21.977,20',
  'August 2026      1.215 Bons      22.190,30',
  'September 2026   1.342 Bons      24.608,90',
  'Oktober 2026     1.067 Bons      19.412,10',
  '------------------------------------------',
  'Gedruckt 23.11.2026 14:06',
  'Kein Beleg',
];

List<PrintOp> day(
  DaySummary s, {
  int columns = 42,
  bool drawer = true,
  String? name = 'Theke',
  BusinessInfo business = yichi,
}) => layoutDayReport(
  s,
  business,
  registerName: name,
  drawer: drawer,
  printedAt: printedAt,
  columns: columns,
);

List<PrintOp> period(
  PeriodReport r, {
  int columns = 42,
  String? name = 'Theke',
}) => layoutPeriodReport(
  r,
  yichi,
  registerName: name,
  printedAt: printedAtMonth,
  columns: columns,
);

void main() {
  test('bonsText', () {
    expect(bonsText(1), '1 Bon');
    expect(bonsText(0), '0 Bons');
    expect(bonsText(1067), '1.067 Bons');
    expect(bonsText(-1), '-1 Bons');
  });

  test('Tagesabschluss, 42 Zeichen: Text wie im Entwurf', () {
    expect(texts(day(daySample())), daySlip42);
  });

  test('Monatsabrechnung, 42 Zeichen: Text wie im Entwurf, ohne Tage', () {
    expect(texts(period(monthSample())), monthSlip42);
  });

  test('Mehrere Monate, 42 Zeichen: ABRECHNUNG mit MONATE', () {
    expect(texts(period(manySample())), manySlip42);
  });

  for (final w in [32, 42, 48]) {
    test('Breite $w: keine Zeile ist länger, Beträge stehen rechts', () {
      for (final ops in [
        day(daySample(), columns: w),
        period(monthSample(), columns: w),
        period(manySample(), columns: w),
      ]) {
        for (final t in texts(ops)) {
          expect(t.length, lessThanOrEqualTo(w), reason: t);
        }
      }
      // Zeile mit Betrag: endet mit dem Betrag am rechten Rand.
      final gesamt = texts(period(manySample(), columns: w))
          .firstWhere((t) => t.contains('12.285 Bons'));
      expect(gesamt.length, w);
      expect(gesamt.endsWith('224.959,60'), isTrue);
      // Monatszeile: Betrag rechtsbündig, bei 32 Zeichen steht der Monat
      // allein in der Zeile darüber.
      final lines = texts(period(manySample(), columns: w));
      final oct = lines.firstWhere((t) => t.endsWith('19.412,10'));
      expect(oct.length, w);
      expect(oct, contains('1.067 Bons'));
      if (w >= 42) {
        expect(oct, startsWith('Oktober 2026'));
      } else {
        expect(lines[lines.indexOf(oct) - 1], 'Oktober 2026');
      }
      for (final t in lines.where((t) => RegExp(r'\d,\d\d$').hasMatch(t))) {
        expect(t.length, w, reason: t);
      }
    });
  }

  test('32 Zeichen: "September 2026" steht in eigener Zeile über Anzahl '
      'und Betrag', () {
    final lines = texts(period(manySample(), columns: 32));
    final i = lines.indexOf('September 2026');
    expect(i, greaterThan(0));
    expect(lines[i + 1], '       1.342 Bons      24.608,90');
    expect(lines[i + 1].length, 32);
    expect(lines[i + 1].indexOf('Bons') + 4, 17);
  });

  test('ohne Geldlade heißt der Teil BARGELD', () {
    final lines = texts(day(daySample(), drawer: false));
    expect(lines, contains('BARGELD'));
    expect(lines, isNot(contains('GELDLADE')));
  });

  test('ohne Geldlade heißt der Rest "Wechselgeld für morgen", mit Lade '
      '"In der Lade gelassen"', () {
    final ohne = texts(day(daySample(), drawer: false));
    expect(
      ohne.where((t) => t.startsWith('Wechselgeld für morgen')),
      hasLength(1),
    );
    expect(ohne.where((t) => t.contains('In der Lade')), isEmpty);
    final mit = texts(day(daySample()));
    expect(
      mit.where((t) => t.startsWith('In der Lade gelassen')),
      hasLength(1),
    );
    expect(mit.where((t) => t.contains('Wechselgeld für morgen')), isEmpty);
  });

  test('ohne Namen der Kassa fehlt die Zeile Kassa', () {
    expect(
      texts(day(daySample(), name: null)).where((t) => t.startsWith('Kassa')),
      isEmpty,
    );
    expect(
      texts(period(monthSample(), name: null))
          .where((t) => t.startsWith('Kassa')),
      isEmpty,
    );
  });

  test('Testbetrieb steht unter dem Untertitel', () {
    final lines = texts(period(monthSample(testMode: true)));
    final i = lines.indexOf('Oktober 2026');
    expect(lines[i + 1], 'Testbetrieb');
    expect(texts(period(monthSample())), isNot(contains('Testbetrieb')));
  });

  test('Monat nur mit Storno: "-1 Bons" und "-18,20" rechtsbündig', () {
    final r = PeriodReport(
      range: MonthRange(YearMonth(2026, 10), YearMonth(2026, 10)),
      testMode: false,
      receiptCount: -1,
      cashReceiptCount: -1,
      cardReceiptCount: 0,
      voidCount: 1,
      voidedCents: 1820,
      revenueCents: -1820,
      cashRevenueCents: -1820,
      cardRevenueCents: 0,
      depositCents: 0,
      taxLines: const [],
      firstNumber: 5,
      lastNumber: 5,
      rows: const [],
    );
    final lines = texts(period(r));
    expect(lines, contains('Bar                 -1 Bons         -18,20'));
    expect(lines, contains('Gesamt              -1 Bons         -18,20'));
    expect(lines.where((t) => t.startsWith('Pfand')), isEmpty);
  });

  test('Tag über Mitternacht: Titel trägt den Tag des Öffnens, Bis den '
      'nächsten Tag', () {
    final s = daySample(
      opened: DateTime(2026, 11, 17, 19),
      closed: DateTime(2026, 11, 18, 1, 5),
    );
    final lines = texts(day(s));
    expect(lines, contains('Dienstag, 17.11.2026'));
    expect(lines, contains('Von                       17.11.2026 19:00'));
    expect(lines, contains('Bis                       18.11.2026 01:05'));
  });

  test('offener Tag: ohne Bis, Abgeschlossen von, Gezählt, Entnommen', () {
    final lines = texts(day(daySample(isClosed: false)));
    for (final p in [
      'Bis',
      'Abgeschlossen',
      'Gezählt',
      'Unterschied',
      'In der Lade',
      'Entnommen  ',
    ]) {
      expect(lines.where((t) => t.startsWith(p)), isEmpty, reason: p);
    }
    expect(lines.firstWhere((t) => t.startsWith('Soll')), contains('668,10'));
  });

  test('ohne Storno, Pfand und Bon fehlen die Zeilen', () {
    final lines = texts(day(daySample(voidCount: 0, deposit: 0)));
    expect(lines.where((t) => t.startsWith('Storniert')), isEmpty);
    expect(lines.where((t) => t.startsWith('Pfand')), isEmpty);
  });

  test('langer Name des Betriebs bricht um, nicht druckbare Zeichen werden '
      'ersetzt', () {
    const long = BusinessInfo(
      name: 'Zum goldenen Löwen am Marktplatz „Café“ 😀',
      addressLines: ['Musterstraße 1'],
    );
    final ops = day(daySample(), columns: 32, business: long);
    final lines = texts(ops);
    expect(
      lines.take(3),
      [
        'Zum goldenen Löwen am Marktplatz',
        '„Café“ ?',
        'Musterstraße 1',
      ].map((l) => l.replaceAll('„', '"').replaceAll('“', '"')),
    );
    final first = ops.first as PrintText;
    expect(first.align, PrintAlign.center);
    expect(first.bold, isTrue);
  });

  test('kein QR-Code, keine Lade: nur PrintText und PrintFeed, am Ende '
      'PrintFeed(3) und PrintCut', () {
    for (final ops in [day(daySample()), period(manySample())]) {
      for (final o in ops) {
        expect(o is PrintText || o is PrintFeed || o is PrintCut, isTrue);
      }
      expect(ops[ops.length - 2], isA<PrintFeed>());
      expect((ops[ops.length - 2] as PrintFeed).lines, 3);
      expect(ops.last, isA<PrintCut>());
      expect(ops.whereType<PrintCut>(), hasLength(1));
    }
  });

  test('Jahreswechsel: Untertitel "November 2025 bis Februar 2026", '
      'Zeitraum "01.11.2025 bis 28.02.2026"', () {
    final r = PeriodReport(
      range: MonthRange(YearMonth(2025, 11), YearMonth(2026, 2)),
      testMode: false,
      receiptCount: 0,
      cashReceiptCount: 0,
      cardReceiptCount: 0,
      voidCount: 0,
      voidedCents: 0,
      revenueCents: 0,
      cashRevenueCents: 0,
      cardRevenueCents: 0,
      depositCents: 0,
      taxLines: const [],
      firstNumber: null,
      lastNumber: null,
      rows: [
        for (final m in [
          DateTime(2025, 11),
          DateTime(2025, 12),
          DateTime(2026, 1),
          DateTime(2026, 2),
        ])
          PeriodRow(start: m, receiptCount: 0, revenueCents: 0),
      ],
    );
    final lines = texts(period(r));
    expect(lines, contains('November 2025 bis Februar 2026'));
    expect(lines, contains('Zeitraum         01.11.2025 bis 28.02.2026'));
    expect(lines.where((t) => t.startsWith('Bons Nr.')), isEmpty);
  });

  test('32 Zeichen, Jahreswechsel: "Zeitraum" steht allein, das Datum '
      'rechtsbündig darunter', () {
    final r = PeriodReport(
      range: MonthRange(YearMonth(2025, 11), YearMonth(2026, 2)),
      testMode: false,
      receiptCount: 0,
      cashReceiptCount: 0,
      cardReceiptCount: 0,
      voidCount: 0,
      voidedCents: 0,
      revenueCents: 0,
      cashRevenueCents: 0,
      cardRevenueCents: 0,
      depositCents: 0,
      taxLines: const [],
      firstNumber: null,
      lastNumber: null,
      rows: [
        for (final m in [
          DateTime(2025, 11),
          DateTime(2025, 12),
          DateTime(2026, 1),
          DateTime(2026, 2),
        ])
          PeriodRow(start: m, receiptCount: 0, revenueCents: 0),
      ],
    );
    final lines = texts(period(r, columns: 32));
    final i = lines.indexOf('Zeitraum');
    expect(i, greaterThan(0));
    expect(lines[i + 1], '       01.11.2025 bis 28.02.2026');
    expect(lines.where((t) => t.contains('Zeitra ')), isEmpty);
  });

  group('Rabatte und Trinkgeld', () {
    const tips = [
      StaffTip(staffId: 'a', staffName: 'Anna', cents: 640),
      StaffTip(staffId: 'c', staffName: 'Chef', cents: -320),
    ];

    test('Tagesabschluss mit Rabatten und Trinkgeld', () {
      final s = daySample(
        cardRevenueCents: 12000,
        discountCount: 3,
        discountCents: 1240,
        cardTipCents: 320,
        tipsByStaff: tips,
      );
      final text = lines(
        layoutDayReport(
          s,
          business,
          registerName: null,
          drawer: true,
          printedAt: now,
        ),
      );
      expect(
        text,
        containsAllInOrder([
          contains('Rabatte'),
          'TRINKGELD KARTE',
          startsWith('Anna'),
          startsWith('Chef'),
          startsWith('Gesamt'),
          startsWith('Am Kartenkonto'),
        ]),
      );
      expect(
        text.firstWhere((l) => l.startsWith('Rabatte')),
        allOf(contains('3 Bons'), endsWith('-12,40')),
      );
      expect(
        text.firstWhere((l) => l.startsWith('Am Kartenkonto')),
        endsWith('123,20'),
      );
    });

    test('42 Zeichen: die neuen Zeilen nach EINNAHMEN, vor STEUER', () {
      final t = texts(
        day(
          daySample(
            cardRevenueCents: 12000,
            discountCount: 3,
            discountCents: 1240,
            cardTipCents: 320,
            tipsByStaff: tips,
          ),
        ),
      );
      final i = t.indexOf('Storniert            2 Bons          20,50');
      expect(t.sublist(i, i + 9), [
        'Storniert            2 Bons          20,50',
        'Rabatte              3 Bons         -12,40',
        '------------------------------------------',
        'TRINKGELD KARTE',
        'Anna                                  6,40',
        'Chef                                 -3,20',
        'Gesamt                                3,20',
        'Am Kartenkonto                      123,20',
        '------------------------------------------',
      ]);
      expect(t[i + 9], 'STEUER');
    });

    test('ohne Rabatt und Trinkgeld: kein Wort davon im Ausdruck', () {
      final text = lines(
        layoutDayReport(
          daySample(),
          business,
          registerName: null,
          drawer: true,
          printedAt: now,
        ),
      ).join('\n');
      for (final word in ['Rabatte', 'TRINKGELD', 'Kartenkonto']) {
        expect(text, isNot(contains(word)));
      }
      final month = texts(period(monthSample())).join('\n');
      for (final word in ['Rabatte', 'TRINKGELD', 'Kartenkonto']) {
        expect(month, isNot(contains(word)));
      }
    });

    test('Monatsabrechnung: dieselben Zeilen, ein Storno allein im Monat '
        'steht mit Minus da', () {
      final t = texts(
        period(
          monthSample(
            discountCount: -1,
            discountCents: -284,
            cardTipCents: -80,
            tipsByStaff: const [
              StaffTip(staffId: 'a', staffName: 'Anna', cents: -80),
            ],
          ),
        ),
      );
      expect(
        t,
        containsAllInOrder([
          'EINNAHMEN',
          'Rabatte             -1 Bons           2,84',
          '------------------------------------------',
          'TRINKGELD KARTE',
          'Anna                                 -0,80',
          'Gesamt                               -0,80',
          'Am Kartenkonto                   12.480,90',
          '------------------------------------------',
          'STEUER',
        ]),
      );
    });

    for (final w in [32, 42, 48]) {
      test('Breite $w: die neuen Zeilen passen, Beträge stehen rechts', () {
        final t = texts(
          day(
            daySample(
              discountCount: 3,
              discountCents: 1240,
              cardTipCents: 320,
              tipsByStaff: const [
                StaffTip(
                  staffId: 'x',
                  staffName: 'Anna Maria Musterfrau-Beispiel von Hohenberg',
                  cents: 320,
                ),
              ],
            ),
            columns: w,
          ),
        );
        for (final l in t) {
          expect(l.length, lessThanOrEqualTo(w), reason: l);
        }
        for (final l in t.where((l) => RegExp(r'\d,\d\d$').hasMatch(l))) {
          expect(l.length, w, reason: l);
        }
      });
    }
  });
}
