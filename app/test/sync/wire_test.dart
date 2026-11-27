import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kassa/domain/catalog.dart';
import 'package:kassa/domain/staff.dart';
import 'package:kassa/sync/wire.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('../shared/fixtures/sync/$name.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('pull_full.json und pull_delta.json werden gelesen', () {
    final full = PullResponse.fromJson(fixture('pull_full'));
    expect(full.next, 8);
    expect(full.more, isFalse);
    expect(full.business!.name, 'Beispiel-Imbiss');
    expect(full.business!.addressLines, ['Musterstraße 1', '1010 Wien']);
    expect(full.business!.vatId, 'ATU12345678');
    expect(full.business!.receiptFooter, 'Danke und bis bald!');
    expect(full.categories, hasLength(2));
    expect(full.categories.first.id, 'bowls');
    expect(full.categories.first.archived, isFalse);
    expect(full.items, hasLength(3));
    final bowl = full.items.first;
    expect(bowl.id, 'huhn-bowl');
    expect(bowl.priceCents, 990);
    expect(bowl.taxRate, TaxRate.reduced1);
    expect(bowl.tags, {ItemTag.spicy});
    expect(bowl.templateId, 'bowl');
    final cola = full.items.firstWhere((i) => i.id == 'cola');
    expect(cola.taxRate, TaxRate.normal);
    expect(cola.depositCents, 25);
    expect(full.templates, hasLength(1));
    final template = full.templates.single;
    expect(template.id, 'bowl');
    expect(template.groups.first.name, 'Größe');
    expect(template.groups.first.max, 1);
    expect(template.groups.first.options.first.isDefault, isTrue);
    expect(template.groups[1].max, isNull);
    expect(template.groups[1].options.first.surchargeCents, 50);
    expect(full.staff, hasLength(1));
    expect(full.staff.single.name, 'Chefin');
    expect(full.staff.single.role, StaffRole.chef);
    expect(full.staff.single.pinHash, hasLength(64));
    expect(full.staff.single.archived, isFalse);

    final delta = PullResponse.fromJson(fixture('pull_delta'));
    expect(delta.next, 11);
    expect(delta.more, isFalse);
    expect(delta.business, isNull);
    expect(delta.categories, isEmpty);
    expect(delta.items, hasLength(3));
    expect(delta.items.first.priceCents, 1090);
    expect(delta.items.last.archived, isTrue);
    expect(delta.templates, isEmpty);
    expect(delta.staff, isEmpty);
  });

  test('Seite ohne photo und Seite mit photo: null lesen beide', () {
    final full = fixture('pull_full');
    final items = full['items'] as List<dynamic>;
    // Alter Server: der Schlüssel fehlt ganz.
    for (final i in items) {
      (i as Map<String, dynamic>).remove('photo');
    }
    (full['business'] as Map<String, dynamic>).remove('logo');
    final old = PullResponse.fromJson(full);
    expect(old.items.every((i) => i.photo == null), isTrue);
    expect(old.business!.logo, isNull);
    // Neuer Server, nichts hochgeladen: der Schlüssel ist null.
    final current = PullResponse.fromJson(fixture('pull_full'));
    expect(current.items.every((i) => i.photo == null), isTrue);
    expect(current.business!.logo, isNull);
  });

  test('photo und logo werden gelesen', () {
    final full = fixture('pull_full');
    ((full['items'] as List<dynamic>).first as Map<String, dynamic>)['photo'] =
        {'id': 'abc-123', 'color': '#a1b2c3'};
    (full['business'] as Map<String, dynamic>)['logo'] = {
      'id': 'def-456',
      'color': '#ffffff',
    };
    final page = PullResponse.fromJson(full);
    expect(page.items.first.photo!.id, 'abc-123');
    expect(page.items.first.photo!.color, '#a1b2c3');
    expect(page.business!.logo!.id, 'def-456');
    expect(page.business!.logo!.color, '#ffffff');
  });

  test('photo mit falscher Art ist eine FormatException', () {
    final full = fixture('pull_full');
    ((full['items'] as List<dynamic>).first as Map<String, dynamic>)['photo'] =
        {'id': 5, 'color': '#a1b2c3'};
    expect(() => PullResponse.fromJson(full), throwsFormatException);
  });

  test('pair_response.json wird gelesen', () {
    final r = PairResponse.fromJson(fixture('pair_response'));
    expect(r.registerId, '<uuid>');
    expect(r.registerName, 'Kassa 1');
    expect(r.businessId, '<uuid>');
    expect(r.businessName, 'Beispiel-Imbiss');
    expect(r.token, '<token>');
  });

  test('toString von PairResponse verrät den Schlüssel nicht', () {
    final r = PairResponse.fromJson({
      ...fixture('pair_response'),
      'token': 'geheim-123',
    });
    expect(r.toString(), isNot(contains('geheim-123')));
  });

  test(
    'unbekannte Felder stören nicht, fehlendes Pflichtfeld ist FormatException',
    () {
      final json = fixture('pull_full');
      json['zukunft'] = 1;
      (json['items'] as List).first['neuesFeld'] = 'x';
      (json['staff'] as List).first['extra'] = true;
      expect(PullResponse.fromJson(json).items.first.id, 'huhn-bowl');

      for (final key in [
        'next',
        'more',
        'categories',
        'items',
        'templates',
        'staff',
      ]) {
        final j = fixture('pull_full')..remove(key);
        expect(
          () => PullResponse.fromJson(j),
          throwsFormatException,
          reason: key,
        );
      }
      final noName = fixture('pull_full');
      (noName['items'] as List).first.remove('name');
      expect(() => PullResponse.fromJson(noName), throwsFormatException);
      final wrongType = fixture('pull_full');
      (wrongType['items'] as List).first['priceCents'] = '990';
      expect(() => PullResponse.fromJson(wrongType), throwsFormatException);

      for (final key in [
        'registerId',
        'registerName',
        'businessId',
        'businessName',
        'token',
      ]) {
        final j = fixture('pair_response')..remove(key);
        expect(
          () => PairResponse.fromJson(j),
          throwsFormatException,
          reason: key,
        );
      }
    },
  );

  test('Kennzeichen "neu" und Steuersatz 7 sind FormatException', () {
    final tag = fixture('pull_full');
    (tag['items'] as List).first['tags'] = ['neu'];
    expect(() => PullResponse.fromJson(tag), throwsFormatException);

    final tax = fixture('pull_full');
    (tax['items'] as List).first['taxPercent'] = 7;
    expect(() => PullResponse.fromJson(tax), throwsFormatException);

    final optionTax = fixture('pull_full');
    final option =
        ((optionTax['templates'] as List).first['groups'] as List)
                .first['options']
                .first
            as Map;
    option['taxPercent'] = 7;
    expect(() => PullResponse.fromJson(optionTax), throwsFormatException);

    final role = fixture('pull_full');
    (role['staff'] as List).first['role'] = 'boss';
    expect(() => PullResponse.fromJson(role), throwsFormatException);
  });

  group('translations', () {
    test(
      'Antwort ohne translations (älterer Server) ergibt eine leere Liste',
      () {
        final json = fixture('pull_full')..remove('translations');
        expect(PullResponse.fromJson(json).translations, isEmpty);
      },
    );

    test('translations werden gelesen, leere values bleiben leer', () {
      final json = fixture('pull_full')
        ..['translations'] = [
          {
            'source': 'Cola',
            'values': {'en': 'Cola', 'tr': 'Kola'},
          },
          {'source': 'Wasser', 'values': <String, Object?>{}},
        ];
      final t = PullResponse.fromJson(json).translations;
      expect(t.map((e) => e.source), ['Cola', 'Wasser']);
      expect(t.first.values, {'en': 'Cola', 'tr': 'Kola'});
      expect(t.last.values, isEmpty);
    });

    test('ein Wert, der kein Text ist, fällt weg; die anderen Sprachen '
        'der Zeile bleiben', () {
      final json = fixture('pull_full')
        ..['translations'] = [
          {
            'source': 'Cola',
            'values': {'en': 3, 'tr': 'Kola', 'ar': null, 'zh': <String>[]},
          },
          {
            'source': 'Wasser',
            'values': {'en': 'Water'},
          },
        ];
      final t = PullResponse.fromJson(json).translations;
      expect(t.map((e) => e.source), ['Cola', 'Wasser']);
      expect(t.first.values, {'tr': 'Kola'});
      expect(t.last.values, {'en': 'Water'});
    });

    test('values ohne Objekt oder ohne Text: die Zeile gilt als leer', () {
      for (final bad in <Map<String, Object?>>[
        {'source': 'Cola', 'values': 'en'},
        {'source': 'Cola'},
        {
          'source': 'Cola',
          'values': {'en': 3},
        },
      ]) {
        final json = fixture('pull_full')..['translations'] = [bad];
        final t = PullResponse.fromJson(json).translations.single;
        expect(t.source, 'Cola');
        expect(t.values, isEmpty);
      }
    });

    test('eine Zeile ohne source ist eine FormatException', () {
      final json = fixture('pull_full')
        ..['translations'] = [
          {
            'values': {'en': 'Cola'},
          },
        ];
      expect(() => PullResponse.fromJson(json), throwsFormatException);
    });
  });

  group('customers (Stufe 1b)', () {
    test('fehlt die Liste (wie bei pull_full.json), ist sie leer', () {
      expect(PullResponse.fromJson(fixture('pull_full')).customers, isEmpty);
    });

    test('Firmenkunden werden gelesen, vatId darf null sein', () {
      final json = fixture('pull_full')
        ..['customers'] = [
          {
            'id': 'c0000000-0000-4000-8000-000000000001',
            'name': 'Muster GmbH',
            'addressLine1': 'Musterweg 1',
            'addressLine2': '1010 Wien',
            'vatId': 'ATU00000000',
            'archived': false,
          },
          {
            'id': 'c0000000-0000-4000-8000-000000000002',
            'name': 'Alt KG',
            'addressLine1': 'Musterweg 2',
            'addressLine2': '1010 Wien',
            'vatId': null,
            'archived': true,
            'spaeter': 'wird überlesen',
          },
        ];
      final c = PullResponse.fromJson(json).customers;
      expect(c.map((x) => (x.id, x.name, x.vatId, x.archived)), [
        (
          'c0000000-0000-4000-8000-000000000001',
          'Muster GmbH',
          'ATU00000000',
          false,
        ),
        ('c0000000-0000-4000-8000-000000000002', 'Alt KG', null, true),
      ]);
      expect(c.first.addressLine1, 'Musterweg 1');
      expect(c.first.addressLine2, '1010 Wien');
    });

    test('ein Kunde ohne Name ist eine FormatException', () {
      final json = fixture('pull_full')
        ..['customers'] = [
          {
            'id': 'c1',
            'addressLine1': 'Musterweg 1',
            'addressLine2': '1010 Wien',
            'vatId': null,
            'archived': false,
          },
        ];
      expect(() => PullResponse.fromJson(json), throwsFormatException);
    });
  });
  group('voucherMovements (Stufe 1b)', () {
    test('eine Art, die diese Version nicht kennt, wird gelesen, wie sie '
        'kommt; eine leere Art ist eine FormatException', () {
      Map<String, dynamic> withKind(String kind) => fixture('pull_full')
        ..['voucherMovements'] = [
          {
            'voucherId': 'v1',
            'receiptId': 'bon-1',
            'kind': kind,
            'amountCents': 500,
            'createdAt': '2026-11-17T09:00:00.000Z',
          },
        ];
      final m = PullResponse.fromJson(withKind('top_up')).voucherMovements;
      expect(
        m.map((x) => (x.voucherId, x.receiptId, x.kind, x.amountCents)),
        [('v1', 'bon-1', 'top_up', 500)],
      );
      expect(() => PullResponse.fromJson(withKind('')), throwsFormatException);
    });
  });
}
