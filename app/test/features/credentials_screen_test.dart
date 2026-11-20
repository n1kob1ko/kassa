// Der Bildschirm "Zugangsdaten von A-Trust" (Plan Task 5): Eingabe mit der
// Tastatur, gespeicherte Zugangsdaten, Löschen und der Weg zu "Verbindung
// prüfen" am echten System, gegen den nachgebauten Dienst von A-Trust. Die
// Zugangsdaten sind erfunden.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/data/database.dart';
import 'package:kassa/data/providers.dart';
import 'package:kassa/features/shell/shell_screen.dart';
import 'package:kassa/rksv/online/atrust_client.dart';
import 'package:kassa/rksv/online/online_providers.dart';
import 'package:kassa/rksv/rksv_secrets.dart';
import 'package:kassa/rksv/rksv_state.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_atrust.dart';
import '../support/kassa_pump.dart' show containerOf;
import '../support/settings_pump.dart';
import '../support/signature_pump.dart';

const _user = 'u-beispiel';
const _password = 'geheim-beispiel ';
const _intro =
    'Benutzername und Passwort hast du von A-Trust bekommen, als das Konto '
    'für diesen Betrieb angelegt wurde. Die Kassa speichert sie geschützt auf '
    'diesem Tablet.';
const _empty = 'Bitte beides ausfüllen.';
const _saveFailed =
    'Die Zugangsdaten konnten nicht gespeichert werden. Bitte noch einmal.';
const _liveNote =
    'Das ist das echte System von A-Trust. Jede Prüfung zählt bei A-Trust als '
    'eine Signatur.';
const _testNote = 'Das ist das Testsystem von A-Trust. Bons bleiben Testbons.';

const _login = 'PUT /Session/$_user';

Finder _key(String key) => find.byKey(Key(key));

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(_key(key));
  await t.pumpAndSettle();
  await t.tap(_key(key));
  await t.pumpAndSettle();
}

/// Ein A-Trust, dessen Zertifikat heute gilt (am echten System ist ein
/// abgelaufenes ein Fehler).
FakeAtrust _fake() => FakeAtrust(validFrom: DateTime.utc(2024, 1, 1));

/// Einstellungen als Chef mit [fake] als A-Trust, dann "Zugangsdaten von
/// A-Trust" geöffnet.
Future<void> _open(
  WidgetTester t, {
  FakeAtrust? fake,
  MemoryRksvSecrets? secrets,
  bool edit = false,
  RksvMode? mode,
}) async {
  await pumpSettings(
    t,
    extra: onlineOverrides(fake ?? _fake(), secrets: secrets),
  );
  if (mode != null) await _setMode(t, mode);
  openCredentials(t.element(_key('area-settings')), edit: edit);
  await t.pumpAndSettle();
}

Future<void> _setMode(WidgetTester t, RksvMode mode) async {
  final db = containerOf(t).read(databaseProvider);
  await (db.update(db.rksvStateRows)..where((r) => r.id.equals(1))).write(
    RksvStateRowsCompanion(mode: Value(mode.name)),
  );
  await t.pumpAndSettle();
}

TextField _field(WidgetTester t, String key) => t.widget<TextField>(
  find.descendant(of: _key(key), matching: find.byType(TextField)),
);

Future<void> _type(WidgetTester t, {String? user, String? password}) async {
  if (user != null) {
    await t.enterText(
      find.descendant(
        of: _key('credentials-user'),
        matching: find.byType(TextField),
      ),
      user,
    );
  }
  if (password != null) {
    await t.enterText(
      find.descendant(
        of: _key('credentials-password'),
        matching: find.byType(TextField),
      ),
      password,
    );
  }
  await t.pump();
}

/// Ein geschützter Speicher, der "abgelehnt" nicht schreiben kann.
class _NoRejectWrites extends MemoryRksvSecrets {
  @override
  Future<void> writeAtrustRejected(bool rejected, {bool live = false}) async =>
      throw StateError('Der sichere Speicher ist nicht beschreibbar.');
}

void main() {
  testWidgets('leer: Titel, Erklärung, zwei Felder und "Speichern und '
      'prüfen"', (t) async {
    final fake = _fake();
    await _open(t, fake: fake);
    expect(_key('credentials'), findsOneWidget);
    expect(find.text('Zugangsdaten von A-Trust'), findsOneWidget);
    expect(find.text(_intro), findsOneWidget);
    expect(find.text('Benutzername'), findsOneWidget);
    expect(find.text('Passwort'), findsOneWidget);
    expect(find.text('Anzeigen'), findsOneWidget);
    expect(
      find.descendant(
        of: _key('credentials-save'),
        matching: find.text('Speichern und prüfen'),
      ),
      findsOneWidget,
    );
    expect(t.getSize(_key('credentials-user')).height, 64);
    expect(t.getSize(_key('credentials-password')).height, 64);
    expect(
      t.getSize(_key('credentials-save')).height,
      greaterThanOrEqualTo(64),
    );
    // Felder und Haupttaste in einer Reihe, über der Tastatur.
    expect(
      t.getTopLeft(_key('credentials-save')).dy,
      t.getTopLeft(_key('credentials-user')).dy,
    );
    expect(fake.requests, isEmpty);
  });

  testWidgets('große Schrift und offene Tastatur: nichts läuft über, die '
      'Seite rollt', (t) async {
    await pumpSettings(t, textScale: 1.3, extra: onlineOverrides(_fake()));
    openCredentials(t.element(_key('area-settings')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    // Die Tastatur deckt die untere Hälfte ab.
    t.view.viewInsets = FakeViewPadding(bottom: t.view.physicalSize.height / 2);
    addTearDown(t.view.resetViewInsets);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.ensureVisible(_key('credentials-save'));
    await t.pumpAndSettle();
    await _type(t, user: _user);
    expect(find.text(_user), findsOneWidget);
  });

  testWidgets('Tastatur ohne Vorschläge, Autokorrektur, Großschreiben und '
      'Ausfüllhilfe', (t) async {
    await _open(t);
    void quiet(String key) {
      final f = _field(t, key);
      expect(f.autocorrect, isFalse, reason: key);
      expect(f.enableSuggestions, isFalse, reason: key);
      expect(f.textCapitalization, TextCapitalization.none, reason: key);
      expect(f.autofillHints, isNull, reason: key);
      expect(f.enableIMEPersonalizedLearning, isFalse, reason: key);
    }

    /// Das Passwortfeld meldet der Tastatur nie "sichtbares Passwort": Auf
    /// Android ginge sonst die Variante "Passwort" verloren, an der
    /// Tastaturen ihren geschützten Modus festmachen.
    void protectedPassword() {
      final f = _field(t, 'credentials-password');
      expect(f.keyboardType, TextInputType.text);
      expect(f.keyboardType, isNot(TextInputType.visiblePassword));
    }

    quiet('credentials-user');
    quiet('credentials-password');
    // Der Benutzername ist sichtbarer Text ohne Vorschläge.
    expect(
      _field(t, 'credentials-user').keyboardType,
      TextInputType.visiblePassword,
    );
    protectedPassword();
    expect(_field(t, 'credentials-user').obscureText, isFalse);
    expect(_field(t, 'credentials-user').textInputAction, TextInputAction.next);
    expect(_field(t, 'credentials-password').obscureText, isTrue);
    expect(
      _field(t, 'credentials-password').textInputAction,
      TextInputAction.done,
    );

    // Mit "Anzeigen" bleibt die Tastatur genauso still und geschützt.
    await _tap(t, 'credentials-show');
    expect(_field(t, 'credentials-password').obscureText, isFalse);
    quiet('credentials-password');
    protectedPassword();
    await _tap(t, 'credentials-show');
    expect(_field(t, 'credentials-password').obscureText, isTrue);
    quiet('credentials-password');
    protectedPassword();
  });

  testWidgets('"Anzeigen" zeigt das Passwort, "Verbergen" verdeckt es', (
    t,
  ) async {
    await _open(t);
    await _type(t, password: _password);
    expect(_field(t, 'credentials-password').obscureText, isTrue);
    await _tap(t, 'credentials-show');
    expect(_field(t, 'credentials-password').obscureText, isFalse);
    expect(
      find.descendant(
        of: _key('credentials-show'),
        matching: find.text('Verbergen'),
      ),
      findsOneWidget,
    );
    await _tap(t, 'credentials-show');
    expect(_field(t, 'credentials-password').obscureText, isTrue);
    expect(find.text('Anzeigen'), findsOneWidget);
  });

  testWidgets('Speichern schreibt genau die getippten Werte und öffnet die '
      'Prüfung am echten System mit genau einer Anmeldung', (t) async {
    final fake = _fake()..password = _password;
    final secrets = MemoryRksvSecrets();
    await _open(t, fake: fake, secrets: secrets);
    await _type(t, user: '  $_user ', password: _password);
    await _tap(t, 'credentials-save');

    final stored = await secrets.atrustCredentials();
    expect(stored!.user, _user);
    expect(stored.password, _password);

    expect(_key('connection-check'), findsOneWidget);
    expect(_key('credentials'), findsNothing);
    expect(fake.requests.where((r) => r == _login), hasLength(1));
    expect(fake.requests.where((r) => r.startsWith('PUT')), hasLength(1));
    final check = containerOf(t)
        .read(connectionCheckProvider(AtrustSystem.live));
    expect(check.state.value.facts!.system, AtrustSystem.live);
    expect(find.text(_liveNote), findsOneWidget);
    expect(find.text(_testNote), findsNothing);
    expect(find.text('Online-Probe starten'), findsNothing);
    expect(_key('connection-start'), findsNothing);
    expect(_key('connection-retry'), findsOneWidget);
    expect(_key('connection-share'), findsOneWidget);
    expect(
      find.descendant(
        of: _key('connection-continue'),
        matching: find.text('Weiter'),
      ),
      findsOneWidget,
    );

    // "Weiter" öffnet "Angaben für FinanzOnline" (Task 6), ohne neue
    // Anmeldung.
    await _tap(t, 'connection-continue');
    expect(_key('connection-check'), findsNothing);
    expect(_key('setup-facts'), findsOneWidget);
    expect(fake.requests.where((r) => r.startsWith('PUT')), hasLength(1));
  });

  testWidgets('"Fertig" der Tastatur im Passwort ist "Speichern und '
      'prüfen"', (t) async {
    final secrets = MemoryRksvSecrets();
    await _open(t, secrets: secrets);
    await _type(t, user: _user, password: _password);
    await t.showKeyboard(
      find.descendant(
        of: _key('credentials-password'),
        matching: find.byType(TextField),
      ),
    );
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect((await secrets.atrustCredentials())!.user, _user);
    expect(_key('connection-check'), findsOneWidget);
  });

  testWidgets('leeres Feld speichert nichts und fragt nichts', (t) async {
    final fake = _fake();
    final secrets = MemoryRksvSecrets();
    await _open(t, fake: fake, secrets: secrets);
    await _type(t, user: _user);
    await _tap(t, 'credentials-save');
    expect(find.text(_empty), findsOneWidget);
    expect(await secrets.atrustCredentials(), isNull);

    await _type(t, user: '   ', password: _password);
    await _tap(t, 'credentials-save');
    expect(find.text(_empty), findsOneWidget);
    expect(await secrets.atrustCredentials(), isNull);
    expect(_key('connection-check'), findsNothing);
    expect(fake.requests, isEmpty);
  });

  testWidgets('scheitert das Speichern: der Satz, keine Prüfung', (t) async {
    final fake = _fake();
    final secrets = MemoryRksvSecrets()..failWrites = true;
    await _open(t, fake: fake, secrets: secrets);
    await _type(t, user: _user, password: _password);
    await _tap(t, 'credentials-save');
    expect(find.text(_saveFailed), findsOneWidget);
    expect(_key('connection-check'), findsNothing);
    expect(fake.requests, isEmpty);
    secrets.failWrites = false;
    expect(await secrets.atrustCredentials(), isNull);
  });

  testWidgets('scheitert das Aufheben von "abgelehnt": Zugangsdaten bleiben, '
      'die Prüfung meldet es selbst', (t) async {
    final secrets = _NoRejectWrites();
    await _open(t, secrets: secrets);
    await _type(t, user: _user, password: _password);
    await _tap(t, 'credentials-save');
    expect((await secrets.atrustCredentials())!.user, _user);
    expect(_key('connection-check'), findsOneWidget);
    expect(find.text(_saveFailed), findsNothing);
  });

  testWidgets('"abgelehnt" ist nach dem Speichern aufgehoben, und der Halter '
      'hat die Sitzung der alten Zugangsdaten nicht mehr', (t) async {
    final fake = _fake();
    final secrets = MemoryRksvSecrets();
    await secrets.writeAtrustCredentials(
      const AtrustCredentials('u-alt', 'alt-beispiel'),
    );
    await _open(t, fake: fake, secrets: secrets, edit: true);
    final keeper = containerOf(t).read(atrustKeeperProvider(AtrustSystem.live));
    final old = await keeper.session();
    expect(fake.requests, ['PUT /Session/u-alt']);
    await secrets.writeAtrustRejected(true, live: true);

    await _type(t, user: _user, password: _password);
    await _tap(t, 'credentials-save');
    expect(await secrets.atrustRejected(live: true), isFalse);
    expect(keeper.rejected.value, isFalse);
    // Die Prüfung meldet mit den neuen Zugangsdaten an, einmal.
    expect(fake.requests.where((r) => r == _login), hasLength(1));
    expect(fake.requests.where((r) => r.startsWith('PUT')), hasLength(2));
    final now = await keeper.session();
    expect(identical(now, old), isFalse);
    expect(fake.requests.where((r) => r.startsWith('PUT')), hasLength(2));
  });

  testWidgets('gespeichert: Benutzername steht da, kein Passwort im Baum, '
      'Tasten "Weiter", "Neu eingeben" und "Löschen"', (t) async {
    final fake = _fake();
    final secrets = MemoryRksvSecrets();
    await secrets.writeAtrustCredentials(
      const AtrustCredentials(_user, _password),
    );
    await _open(t, fake: fake, secrets: secrets);
    expect(_key('credentials-saved'), findsOneWidget);
    expect(find.text('Zugangsdaten sind gespeichert.'), findsOneWidget);
    expect(find.text('Benutzername $_user'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(EditableText), findsNothing);
    expect(find.textContaining('geheim'), findsNothing);
    expect(
      find.descendant(
        of: _key('credentials-continue'),
        matching: find.text('Weiter'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('credentials-new'),
        matching: find.text('Neu eingeben'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('credentials-delete'),
        matching: find.text('Löschen'),
      ),
      findsOneWidget,
    );
    expect(fake.requests, isEmpty);

    // "Weiter" öffnet die Prüfung am echten System.
    await _tap(t, 'credentials-continue');
    expect(_key('connection-check'), findsOneWidget);
    expect(find.text(_liveNote), findsOneWidget);
    expect(fake.requests.where((r) => r == _login), hasLength(1));
  });

  testWidgets('"Neu eingeben" zeigt leere Felder', (t) async {
    final secrets = MemoryRksvSecrets();
    await secrets.writeAtrustCredentials(
      const AtrustCredentials(_user, _password),
    );
    await _open(t, secrets: secrets);
    await _tap(t, 'credentials-new');
    expect(_field(t, 'credentials-user').controller!.text, isEmpty);
    expect(_field(t, 'credentials-password').controller!.text, isEmpty);
  });

  testWidgets('"Löschen" nach der Nachfrage entfernt Zugangsdaten und '
      'Angaben', (t) async {
    final secrets = MemoryRksvSecrets();
    await secrets.writeAtrustCredentials(
      const AtrustCredentials(_user, _password),
    );
    await secrets.writePendingSetup(
      PendingSetup(cashBoxId: 'K7QM2XB4HN', aesKey: Uint8List(32)),
    );
    await _open(t, secrets: secrets);
    await _tap(t, 'credentials-delete');
    expect(find.text('Zugangsdaten löschen?'), findsOneWidget);
    // Abbrechen lässt alles stehen.
    await _tap(t, 'credentials-delete-cancel');
    expect(find.text('Zugangsdaten löschen?'), findsNothing);
    expect(await secrets.atrustCredentials(), isNotNull);

    await _tap(t, 'credentials-delete');
    expect(
      find.descendant(
        of: _key('credentials-delete-confirm'),
        matching: find.text('Löschen'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('credentials-delete-cancel'),
        matching: find.text('Abbrechen'),
      ),
      findsOneWidget,
    );
    await _tap(t, 'credentials-delete-confirm');
    expect(await secrets.atrustCredentials(), isNull);
    expect(await secrets.pendingSetup(), isNull);
    expect(_key('credentials-saved'), findsNothing);
    expect(_key('credentials-user'), findsOneWidget);
  });

  testWidgets('In Betrieb: kein "Löschen", kein "Weiter", und die Prüfung '
      'nach dem Speichern hat unten keine Taste', (t) async {
    final fake = _fake();
    final secrets = MemoryRksvSecrets();
    await secrets.writeAtrustCredentials(
      const AtrustCredentials('u-alt', 'alt-beispiel'),
    );
    await _open(t, fake: fake, secrets: secrets, mode: RksvMode.live);
    expect(_key('credentials-saved'), findsOneWidget);
    expect(_key('credentials-delete'), findsNothing);
    expect(_key('credentials-continue'), findsNothing);
    expect(find.text('Löschen'), findsNothing);
    expect(find.text('Weiter'), findsNothing);
    expect(_key('credentials-new'), findsOneWidget);

    await _tap(t, 'credentials-new');
    await _type(t, user: _user, password: _password);
    await _tap(t, 'credentials-save');
    expect(_key('connection-check'), findsOneWidget);
    final check = containerOf(t)
        .read(connectionCheckProvider(AtrustSystem.live));
    expect(check.state.value.facts, isNotNull);
    expect(_key('connection-continue'), findsNothing);
    expect(_key('connection-start'), findsNothing);
    expect(find.text('Weiter'), findsNothing);
    expect(find.text(_liveNote), findsOneWidget);
  });

  testWidgets('edit: true zeigt die Felder, obwohl Zugangsdaten gespeichert '
      'sind', (t) async {
    final secrets = MemoryRksvSecrets();
    await secrets.writeAtrustCredentials(
      const AtrustCredentials(_user, _password),
    );
    await _open(t, secrets: secrets, edit: true);
    expect(_key('credentials-user'), findsOneWidget);
    expect(_key('credentials-password'), findsOneWidget);
    expect(_key('credentials-saved'), findsNothing);
    expect(_field(t, 'credentials-user').controller!.text, isEmpty);
  });

  testWidgets('Felder werden beim Verlassen geleert', (t) async {
    await _open(t, edit: true);
    await _type(t, user: _user, password: _password);
    await _tap(t, 'credentials-back');
    expect(_key('credentials'), findsNothing);
    openCredentials(t.element(_key('area-settings')), edit: true);
    await t.pumpAndSettle();
    expect(_field(t, 'credentials-user').controller!.text, isEmpty);
    expect(_field(t, 'credentials-password').controller!.text, isEmpty);
  });

  testWidgets('"Zurück" des Tablets: erst die Prüfung, dann die Zugangsdaten', (
    t,
  ) async {
    await _open(t);
    await _type(t, user: _user, password: _password);
    await _tap(t, 'credentials-save');
    expect(_key('connection-check'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(_key('connection-check'), findsNothing);
    expect(_key('credentials-saved'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(_key('credentials'), findsNothing);
    expect(_key('signature-card'), findsOneWidget);
  });

  testWidgets('Schlussprüfung I3: läuft noch eine Prüfung der alten '
      'Zugangsdaten, zeigt "Speichern und prüfen" erst die Prüfung der neuen; '
      'die alte kommt nie zu "Weiter"', (t) async {
    final fake = _fake()..holdLogins = true;
    final secrets = MemoryRksvSecrets();
    await secrets.writeAtrustCredentials(
      const AtrustCredentials('u-alt', 'alt-beispiel'),
    );
    await _open(t, fake: fake, secrets: secrets);
    // Eine Prüfung mit den alten Zugangsdaten hängt bei der Anmeldung.
    await t.tap(_key('credentials-continue'));
    for (var i = 0; i < 5; i++) {
      await t.pump();
    }
    expect(fake.requests.last, 'PUT /Session/u-alt');
    expect(
      containerOf(t)
          .read(connectionCheckProvider(AtrustSystem.live))
          .state
          .value
          .running,
      isTrue,
    );
    await t.binding.handlePopRoute();
    await t.pump();
    await t.pump();
    expect(_key('credentials-saved'), findsOneWidget);

    await t.tap(_key('credentials-new'));
    await t.pump();
    await _type(t, user: _user, password: _password);
    await t.tap(_key('credentials-save'));
    await t.pump();
    await t.pump();
    expect(_key('connection-check'), findsOneWidget);
    expect(_key('connection-continue'), findsNothing);

    // Die alte Anmeldung antwortet: Ihr Lauf läuft weiter (seine
    // Probe-Unterschrift braucht eine Sitzung, und die meldet sich mit den
    // neuen Zugangsdaten an), sein Ergebnis zeigt die Seite nicht.
    fake.heldLogins.single.complete(200);
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(_key('connection-continue'), findsNothing);
    expect(fake.requests.where((r) => r.startsWith('PUT /Session/')), [
      'PUT /Session/u-alt',
      _login,
    ]);
    expect(fake.heldLogins, hasLength(2));
    fake.heldLogins.last.complete(200);
    await t.pumpAndSettle();
    expect(_key('connection-continue'), findsOneWidget);
    // Erst danach lief die Prüfung der neuen Zugangsdaten, ganz, mit
    // derselben neuen Sitzung.
    final requests = fake.requests;
    final oldEnd = requests.lastIndexOf('GET /u-alt/Certificate');
    final newCertificate = requests.lastIndexOf('GET /$_user/Certificate');
    expect(newCertificate, greaterThan(oldEnd));
    expect(requests.last, endsWith('/Sign/Hash'));
    expect(requests.where((r) => r.startsWith('PUT /Session/')), [
      'PUT /Session/u-alt',
      _login,
    ]);
    await _tap(t, 'connection-continue');
    expect(_key('setup-facts'), findsOneWidget);
  });

  testWidgets('Schlussprüfung: das Passwort lässt sich weder kopieren noch '
      'ausschneiden noch teilen, gezeigt oder verdeckt', (t) async {
    await _open(t);
    await _type(t, user: _user, password: _password);
    final password = find.descendant(
      of: _key('credentials-password'),
      matching: find.byType(EditableText),
    );
    for (final shown in [true, false]) {
      await _tap(t, 'credentials-show');
      expect(_field(t, 'credentials-password').obscureText, !shown);
      final f = _field(t, 'credentials-password');
      expect(f.enableInteractiveSelection, isFalse);
      expect(f.contextMenuBuilder, isNull);
      // Wie ein Finger: lange drücken und doppelt tippen.
      await t.longPress(password);
      await t.pumpAndSettle();
      await t.tap(password);
      await t.pump(const Duration(milliseconds: 50));
      await t.tap(password);
      await t.pumpAndSettle();
      final state = t.state<EditableTextState>(password);
      expect(state.textEditingValue.selection.isCollapsed, isTrue);
      expect(state.selectAllEnabled, isFalse, reason: 'gezeigt: $shown');
      expect(state.shareEnabled, isFalse, reason: 'gezeigt: $shown');
      expect(state.showToolbar(), isFalse, reason: 'gezeigt: $shown');
      // Auch eine Tastatur mit Tasten markiert nichts.
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyA);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.pump();
      expect(
        state.textEditingValue.selection.isCollapsed,
        isTrue,
        reason: 'Tasten, gezeigt: $shown',
      );
      await t.pumpAndSettle();
      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
      for (final word in ['Copy', 'Cut', 'Share', 'Select all']) {
        expect(find.text(word), findsNothing, reason: word);
      }
      expect(
        _field(t, 'credentials-password').keyboardType,
        TextInputType.text,
      );
    }
  });

  group('Löschen (Schlussprüfung)', () {
    const extra =
        'Die Angaben für FinanzOnline gelten dann nicht mehr. Ein gedruckter '
        'Zettel ist ungültig.';

    testWidgets('mit PendingSetup sagt die Nachfrage, was noch weggeht', (
      t,
    ) async {
      final secrets = MemoryRksvSecrets();
      await secrets.writeAtrustCredentials(
        const AtrustCredentials(_user, _password),
      );
      await secrets.writePendingSetup(
        PendingSetup(cashBoxId: 'K7QM2XB4HN', aesKey: Uint8List(32)),
      );
      await _open(t, secrets: secrets);
      await _tap(t, 'credentials-delete');
      expect(
        find.descendant(
          of: _key('credentials-delete-question'),
          matching: find.text('Zugangsdaten löschen?'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('credentials-delete-question'),
          matching: find.text(extra),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ohne PendingSetup bleibt die Nachfrage, wie sie ist', (
      t,
    ) async {
      final secrets = MemoryRksvSecrets();
      await secrets.writeAtrustCredentials(
        const AtrustCredentials(_user, _password),
      );
      await _open(t, secrets: secrets);
      await _tap(t, 'credentials-delete');
      expect(find.text('Zugangsdaten löschen?'), findsOneWidget);
      expect(find.text(extra), findsNothing);
    });

    testWidgets('scheitert das Löschen des PendingSetup: die Sitzung ist '
        'trotzdem vergessen und der Benutzername weg', (t) async {
      final fake = _fake();
      final secrets = _NoPendingWrites();
      await secrets.writeAtrustCredentials(
        const AtrustCredentials(_user, _password),
      );
      await _open(t, fake: fake, secrets: secrets);
      final keeper = containerOf(t)
          .read(atrustKeeperProvider(AtrustSystem.live));
      await keeper.session();
      expect(fake.requests.where((r) => r == _login), hasLength(1));
      expect(find.text('Benutzername $_user'), findsOneWidget);

      await _tap(t, 'credentials-delete');
      await _tap(t, 'credentials-delete-confirm');
      expect(await secrets.atrustCredentials(), isNull);
      expect(
        find.text('Das hat nicht geklappt. Bitte noch einmal.'),
        findsOneWidget,
      );
      expect(find.text('Benutzername $_user'), findsNothing);
      expect(_key('credentials-saved'), findsNothing);
      expect(_key('credentials-user'), findsOneWidget);
      // Die alte Sitzung gilt nicht mehr: Ohne Zugangsdaten meldet sich der
      // Halter nicht an, statt die alte Sitzung zu liefern.
      await expectLater(
        keeper.session(),
        throwsA(
          isA<AtrustException>().having(
            (e) => e.problem,
            'problem',
            AtrustProblem.noCredentials,
          ),
        ),
      );
      expect(fake.requests.where((r) => r == _login), hasLength(1));
    });
  });
}

/// Ein geschützter Speicher, der das PendingSetup nicht schreiben (und
/// nicht löschen) kann.
class _NoPendingWrites extends MemoryRksvSecrets {
  @override
  Future<void> writePendingSetup(PendingSetup? setup) async =>
      throw StateError('Der sichere Speicher ist nicht beschreibbar.');
}
