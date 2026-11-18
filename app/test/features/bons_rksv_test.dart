import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/domain/receipt.dart';
import 'package:kassa/domain/receipt_layout.dart';
import 'package:kassa/domain/print_document.dart';
import 'package:kassa/features/login/session.dart';
import 'package:kassa/rksv/rksv_providers.dart';
import 'package:kassa/ui/qr_view.dart';
import 'package:kassa/ui/tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../support/bons_pump.dart';
import '../support/demo_fixtures.dart';
import '../support/kassa_pump.dart';
import '../support/pump.dart';
import '../support/signature_pump.dart';

Finder _key(String key) => find.byKey(Key(key));

Finder _inDetail(Finder f) =>
    find.descendant(of: _key('detail-scroll'), matching: f);

/// Ein Barverkauf (Nr. 1) mit festem Eintrag im Protokoll, geöffnet.
Future<Receipt> _stamped(
  WidgetTester t, {
  bool damaged = false,
  bool ended = false,
}) async {
  await pumpBonsWithSales(
    t,
    1,
    overrides: [...await memoryOverrides(), ...signatureOverrides()],
  );
  await seedProbe(t, ended: ended);
  final sale =
      (await containerOf(t)
              .read(databaseProvider)
              .customSelect('SELECT id FROM receipts WHERE number = 1')
              .getSingle())
          .read<String>('id');
  await stampReceipt(t, sale, damaged: damaged);
  await openReceipt(t, 1);
  return containerOf(t).read(receiptRepositoryProvider).byId(sale);
}

void main() {
  testWidgets('Bon mit Signatur: QR-Code 180 dp, Kassen-ID und die zwei '
      'Sätze der Probe', (t) async {
    final receipt = await _stamped(t);
    expect(_inDetail(find.byType(QrView)), findsOneWidget);
    expect(t.getSize(find.byType(QrView)), const Size(180, 180));
    expect(_inDetail(find.text('Kassen-ID $fixedCashBoxId')), findsOneWidget);
    expect(_inDetail(find.text('Testbon mit Probe-Signatur.')), findsOneWidget);
    expect(
      _inDetail(find.text('Der QR-Code steht auch am gedruckten Bon.')),
      findsOneWidget,
    );
    expect(find.text('Sicherheitseinrichtung ausgefallen'), findsNothing);

    // Derselbe Text wie im gedruckten Bon.
    final qr = t.widget<QrView>(find.byType(QrView));
    expect(qr.data, receipt.rksv!.qrText);
    final printed = layoutReceipt(
      receipt,
      catalog.business,
    ).whereType<PrintQr>().single;
    expect(qr.data, printed.data);

    // Links der Code, rechts daneben die Kassen-ID.
    expect(
      t.getTopLeft(find.text('Kassen-ID $fixedCashBoxId')).dx,
      greaterThan(t.getTopRight(find.byType(QrView)).dx),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('Ausfall-Eintrag: "Sicherheitseinrichtung ausgefallen" statt '
      'der zwei Sätze', (t) async {
    await _stamped(t, damaged: true);
    expect(_inDetail(find.byType(QrView)), findsOneWidget);
    expect(
      _inDetail(find.text('Sicherheitseinrichtung ausgefallen')),
      findsOneWidget,
    );
    expect(find.text('Testbon mit Probe-Signatur.'), findsNothing);
    expect(
      find.text('Der QR-Code steht auch am gedruckten Bon.'),
      findsNothing,
    );
  });

  testWidgets('Bon ohne Signatur: kein QR-Code, keine Kassen-ID', (t) async {
    await pumpBonsWithSales(t, 1);
    await openReceipt(t, 1);
    expect(find.byType(QrView), findsNothing);
    expect(find.textContaining('Kassen-ID'), findsNothing);
    expect(find.text('Boniert von Anna'), findsOneWidget);
  });

  testWidgets('QrView: weiß mit Rand, auch im dunklen Modus', (t) async {
    await pumpApp(
      t,
      const Center(child: QrView(data: fixedQrPayload)),
      brightness: Brightness.dark,
    );
    final box = t.widget<Container>(
      find
          .descendant(of: find.byType(QrView), matching: find.byType(Container))
          .first,
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFFFFFFF));
    expect(decoration.border, isNotNull);
    expect(t.getSize(find.byType(QrView)), const Size(180, 180));
  });

  testWidgets('Storno eines Bons von vor der Probe zeigt den Satz, nichts '
      'wird storniert', (t) async {
    await pumpBonsWithSales(
      t,
      1,
      pin: '4711',
      overrides: [...await memoryOverrides(), ...signatureOverrides()],
    );
    final c = containerOf(t);
    await c
        .read(rksvServiceProvider)
        .enableProbe(staff: c.read(sessionProvider)!);
    await t.pumpAndSettle();
    await openReceipt(t, 1);
    await t.tap(_key('void-receipt'));
    await t.pumpAndSettle();
    await t.tap(_key('confirm-void'));
    await t.pumpAndSettle();
    expect(
      find.text(
        'Dieser Bon ist älter als die Probe-Signatur und kann nicht '
        'storniert werden.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Der Storno konnte nicht gespeichert werden. Bitte noch einmal.',
      ),
      findsNothing,
    );
    final kinds = await c
        .read(databaseProvider)
        .customSelect('SELECT kind FROM receipts ORDER BY number')
        .map((r) => r.read<String>('kind'))
        .get();
    expect(kinds, ['sale', 'start']);
  });

  testWidgets('Sonderbeleg: Bezeichnung als Titel, "Erstellt von", Pille in '
      'Akzentfarbe, kein Stornieren, kein QR ohne Eintrag', (t) async {
    await pumpBonsWithSales(t, 1, pin: '4711');
    final c = containerOf(t);
    final staff = c.read(sessionProvider)!;
    final db = c.read(databaseProvider);
    await db
        .into(db.receiptRows)
        .insert(
          ReceiptRowsCompanion.insert(
            id: 'y1',
            number: 2,
            createdAt: c.read(clockProvider).now(),
            staffId: staff.id,
            staffName: staff.name,
            kind: ReceiptKind.year.name,
            goodsCents: 0,
            depositCents: 0,
            totalCents: 0,
          ),
        );
    await t.pumpAndSettle();

    final pill = find.descendant(
      of: _key('receipt-2'),
      matching: find.text('Jahresbeleg'),
    );
    expect(pill, findsOneWidget);
    final colors = KassaColors.of(t.element(pill));
    expect(t.widget<Text>(pill).style!.color, colors.accentInk);
    final pillBox = t.widget<Container>(
      find.ancestor(of: pill, matching: find.byType(Container)).first,
    );
    expect((pillBox.decoration! as BoxDecoration).color, colors.accentSoft);

    await openReceipt(t, 2);
    expect(find.text('Bon Nr. 2'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(Scaffold),
        matching: find.text('Jahresbeleg'),
      ),
      findsNWidgets(2), // Pille in der Liste und Titel rechts
    );
    expect(find.text('Erstellt von Chef'), findsOneWidget);
    expect(find.textContaining('Boniert von'), findsNothing);
    expect(_key('void-receipt'), findsNothing);
    expect(find.byType(QrView), findsNothing);
    expect(t.takeException(), isNull);
  });
}
