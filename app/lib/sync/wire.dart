// Nachrichtenformen zwischen Kassa und Server (Teil C1).
// Reines Dart, ohne Flutter: auch das Werkzeug `tool/menu_fixture.dart` nutzt es.

import '../domain/catalog.dart';
import '../domain/staff.dart';
import '../domain/wire_file.dart';

export '../domain/wire_file.dart' show WireFile;

// Lesen der Antworten des Servers. Jede Form, die nicht passt (Pflichtfeld
// fehlt, falscher Typ, unbekanntes Kennzeichen, nicht erlaubter Steuersatz),
// ist eine FormatException. Unbekannte Felder werden überlesen.

T _field<T>(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v is T) return v;
  throw FormatException(
    v == null ? 'Feld fehlt: $key' : 'Feld hat die falsche Art: $key',
  );
}

T? _optional<T>(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v == null) return null;
  if (v is T) return v;
  throw FormatException('Feld hat die falsche Art: $key');
}

Map<String, dynamic> _object(Object? v, String what) {
  if (v is Map<String, dynamic>) return v;
  throw FormatException('Kein Objekt: $what');
}

List<T> _list<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) read,
) => [for (final e in _field<List<dynamic>>(json, key)) read(_object(e, key))];

/// `photo` und `logo`: fehlt der Schlüssel (alter Server) oder ist er `null`,
/// gibt es kein Bild.
WireFile? _file(Map<String, dynamic> json, String key) {
  final v = _optional<Map<String, dynamic>>(json, key);
  if (v == null) return null;
  return WireFile(id: _field(v, 'id'), color: _field(v, 'color'));
}

TaxRate _taxRate(int percent) {
  try {
    return TaxRate.fromPercent(percent);
  } on ArgumentError {
    throw FormatException('Steuersatz nicht erlaubt: $percent');
  }
}

class WireCategory {
  const WireCategory({
    required this.id,
    required this.name,
    required this.position,
    required this.archived,
  });

  factory WireCategory.fromJson(Map<String, dynamic> json) => WireCategory(
    id: _field(json, 'id'),
    name: _field(json, 'name'),
    position: _field(json, 'position'),
    archived: _field(json, 'archived'),
  );

  final String id;
  final String name;
  final int position;
  final bool archived;
}

class WireItem {
  const WireItem({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.categoryId,
    required this.taxRate,
    required this.depositCents,
    required this.tags,
    required this.info,
    required this.templateId,
    required this.favorite,
    required this.inSale,
    required this.position,
    required this.archived,
    this.photo,
  });

  factory WireItem.fromJson(Map<String, dynamic> json) => WireItem(
    id: _field(json, 'id'),
    name: _field(json, 'name'),
    priceCents: _field(json, 'priceCents'),
    categoryId: _field(json, 'categoryId'),
    taxRate: _taxRate(_field(json, 'taxPercent')),
    depositCents: _field(json, 'depositCents'),
    tags: {
      for (final t in _field<List<dynamic>>(json, 'tags'))
        ItemTag.values.firstWhere(
          (k) => k.name == t,
          orElse: () => throw FormatException('Unbekanntes Kennzeichen: $t'),
        ),
    },
    info: _optional(json, 'info'),
    templateId: _optional(json, 'templateId'),
    favorite: _field(json, 'favorite'),
    inSale: _field(json, 'inSale'),
    position: _field(json, 'position'),
    archived: _field(json, 'archived'),
    photo: _file(json, 'photo'),
  );

  final String id;
  final String name;
  final int priceCents;
  final String categoryId;
  final TaxRate taxRate;
  final int depositCents;
  final Set<ItemTag> tags;
  final String? info;
  final String? templateId;
  final bool favorite;
  final bool inSale;
  final int position;
  final bool archived;

  /// Das Foto des Artikels, oder `null`.
  final WireFile? photo;
}

class WireTemplate {
  const WireTemplate({
    required this.id,
    required this.name,
    required this.archived,
    required this.groups,
  });

  factory WireTemplate.fromJson(Map<String, dynamic> json) => WireTemplate(
    id: _field(json, 'id'),
    name: _field(json, 'name'),
    archived: _field(json, 'archived'),
    groups: _list(json, 'groups', _group),
  );

  static ModifierGroup _group(Map<String, dynamic> json) => ModifierGroup(
    id: _field(json, 'id'),
    name: _field(json, 'name'),
    min: _field(json, 'min'),
    max: _optional(json, 'max'),
    options: _list(json, 'options', _option),
  );

  static ModifierOption _option(Map<String, dynamic> json) {
    final tax = _optional<int>(json, 'taxPercent');
    return ModifierOption(
      id: _field(json, 'id'),
      name: _field(json, 'name'),
      surchargeCents: _field(json, 'surchargeCents'),
      isDefault: _field(json, 'isDefault'),
      taxRate: tax == null ? null : _taxRate(tax),
      depositCents: _optional(json, 'depositCents'),
    );
  }

  final String id;
  final String name;
  final bool archived;
  final List<ModifierGroup> groups;
}

class WireStaff {
  const WireStaff({
    required this.id,
    required this.name,
    required this.role,
    required this.pinSalt,
    required this.pinHash,
    required this.archived,
  });

  factory WireStaff.fromJson(Map<String, dynamic> json) {
    final role = _field<String>(json, 'role');
    return WireStaff(
      id: _field(json, 'id'),
      name: _field(json, 'name'),
      role: switch (role) {
        'chef' => StaffRole.chef,
        'staff' => StaffRole.staff,
        _ => throw FormatException('Unbekannte Rolle: $role'),
      },
      pinSalt: _field(json, 'pinSalt'),
      pinHash: _field(json, 'pinHash'),
      archived: _field(json, 'archived'),
    );
  }

  final String id;
  final String name;
  final StaffRole role;
  final String pinSalt;
  final String pinHash;
  final bool archived;
}

/// Die Übersetzungen eines Namens aus der Speisekarte. Leere [values] heißen:
/// der Eintrag ist gelöscht. Die Sprachkürzel prüft hier niemand.
///
/// Liest tolerant wie das Wörterbuch am Tablet: ein Wert, der kein Text ist,
/// fällt weg, die anderen Sprachen der Zeile bleiben; ist `values` kein
/// Objekt, gilt die Zeile als leer. Eine kaputte Zeile hält so nie den
/// ganzen Abgleich auf (Speisekarte und Personal kämen sonst auch nicht an).
class WireTranslation {
  const WireTranslation({required this.source, required this.values});

  factory WireTranslation.fromJson(Map<String, dynamic> json) {
    final values = json['values'];
    return WireTranslation(
      source: _field(json, 'source'),
      values: {
        if (values is Map<String, dynamic>)
          for (final e in values.entries)
            if (e.value case final String text) e.key: text,
      },
    );
  }

  final String source;
  final Map<String, String> values;
}

/// Ein Firmenkunde für die Rechnung (Spec 5.3). Archiviert heißt: er steht
/// nicht mehr zur Wahl; Bons behalten ihre Kopie von Name und Adresse.
class WireCustomer {
  const WireCustomer({
    required this.id,
    required this.name,
    required this.addressLine1,
    required this.addressLine2,
    required this.vatId,
    required this.archived,
  });

  factory WireCustomer.fromJson(Map<String, dynamic> json) => WireCustomer(
    id: _field(json, 'id'),
    name: _field(json, 'name'),
    addressLine1: _field(json, 'addressLine1'),
    addressLine2: _field(json, 'addressLine2'),
    vatId: _optional(json, 'vatId'),
    archived: _field(json, 'archived'),
  );

  final String id;
  final String name;
  final String addressLine1;
  final String addressLine2;
  final String? vatId;
  final bool archived;
}

/// Zeitpunkt aus dem Abgleich ("2026-11-17T09:00:00.000Z").
DateTime _time(Map<String, dynamic> json, String key) {
  final at = DateTime.tryParse(_field<String>(json, key));
  if (at == null) throw FormatException('Feld hat die falsche Art: $key');
  return at;
}

/// Ein Gutschein vom Server (Spec 5.5), auch einer, den diese Kassa selbst
/// verkauft hat. Code und Wert ändern sich nie; das Guthaben folgt aus den
/// Bewegungen.
class WireVoucher {
  const WireVoucher({
    required this.id,
    required this.code,
    required this.valueCents,
    required this.createdAt,
    required this.isTest,
    required this.soldReceiptId,
  });

  factory WireVoucher.fromJson(Map<String, dynamic> json) => WireVoucher(
    id: _field(json, 'id'),
    code: _field(json, 'code'),
    valueCents: _field(json, 'valueCents'),
    createdAt: _time(json, 'createdAt'),
    isTest: _field(json, 'isTest'),
    soldReceiptId: _optional(json, 'soldReceiptId'),
  );

  final String id;
  final String code;
  final int valueCents;
  final DateTime createdAt;
  final bool isTest;
  final String? soldReceiptId;
}

/// Eine Bewegung am Guthaben vom Server, eine je Gutschein und Bon.
class WireVoucherMovement {
  const WireVoucherMovement({
    required this.voucherId,
    required this.receiptId,
    required this.kind,
    required this.amountCents,
    required this.createdAt,
  });

  factory WireVoucherMovement.fromJson(Map<String, dynamic> json) {
    // Jede Art, die nicht leer ist, kommt an, wie sie ist: eine Art einer
    // späteren Server-Version darf den Abgleich nicht anhalten.
    final kind = _field<String>(json, 'kind');
    if (kind.isEmpty) {
      throw const FormatException('Leere Art einer Bewegung');
    }
    return WireVoucherMovement(
      voucherId: _field(json, 'voucherId'),
      receiptId: _field(json, 'receiptId'),
      kind: kind,
      amountCents: _field(json, 'amountCents'),
      createdAt: _time(json, 'createdAt'),
    );
  }

  final String voucherId;
  final String receiptId;

  /// `sale`, `redeem`, `void_sale`, `void_redeem` oder eine Art einer
  /// späteren Version.
  final String kind;
  final int amountCents;
  final DateTime createdAt;
}

/// Eine Seite der Änderungen vom Server.
class PullResponse {
  const PullResponse({
    required this.next,
    required this.more,
    required this.business,
    required this.categories,
    required this.items,
    required this.templates,
    required this.staff,
    this.translations = const [],
    this.customers = const [],
    this.vouchers = const [],
    this.voucherMovements = const [],
  });

  factory PullResponse.fromJson(Map<String, dynamic> json) {
    final business = _optional<Map<String, dynamic>>(json, 'business');
    return PullResponse(
      next: _field(json, 'next'),
      more: _field(json, 'more'),
      business: business == null
          ? null
          : BusinessInfo(
              name: _field(business, 'name'),
              addressLines: [
                for (final l in _field<List<dynamic>>(business, 'addressLines'))
                  if (l is String)
                    l
                  else
                    throw const FormatException('Anschrift: keine Zeile'),
              ],
              vatId: _optional(business, 'vatId'),
              receiptFooter: _optional(business, 'receiptFooter'),
              logo: _file(business, 'logo'),
            ),
      categories: _list(json, 'categories', WireCategory.fromJson),
      items: _list(json, 'items', WireItem.fromJson),
      templates: _list(json, 'templates', WireTemplate.fromJson),
      staff: _list(json, 'staff', WireStaff.fromJson),
      // Ein älterer Server schickt den Schlüssel nicht.
      translations: json.containsKey('translations')
          ? _list(json, 'translations', WireTranslation.fromJson)
          : const [],
      // Der Server schickt die Liste nur, wenn sie nicht leer ist.
      customers: json.containsKey('customers')
          ? _list(json, 'customers', WireCustomer.fromJson)
          : const [],
      // Gutscheine und Bewegungen ebenso nur, wenn es welche gibt.
      vouchers: json.containsKey('vouchers')
          ? _list(json, 'vouchers', WireVoucher.fromJson)
          : const [],
      voucherMovements: json.containsKey('voucherMovements')
          ? _list(json, 'voucherMovements', WireVoucherMovement.fromJson)
          : const [],
    );
  }

  /// Die höchste Änderungs-Nummer dieser Seite.
  final int next;

  /// Es gibt nach dieser Seite noch mehr.
  final bool more;

  /// Fehlt, wenn sich die Betriebsdaten seit der Anfrage nicht geändert haben.
  final BusinessInfo? business;
  final List<WireCategory> categories;
  final List<WireItem> items;
  final List<WireTemplate> templates;
  final List<WireStaff> staff;

  /// Übersetzungen der Namen aus der Speisekarte.
  final List<WireTranslation> translations;

  /// Firmenkunden (ab Stufe 1b); leer, wenn die Liste fehlt.
  final List<WireCustomer> customers;

  /// Gutscheine des Betriebs (ab Stufe 1b); leer, wenn die Liste fehlt.
  final List<WireVoucher> vouchers;

  /// Bewegungen an den Gutscheinen (ab Stufe 1b); leer, wenn die Liste fehlt.
  /// Eine kann vor ihrem Gutschein kommen.
  final List<WireVoucherMovement> voucherMovements;
}

/// Antwort auf das Koppeln. Der Schlüssel [token] geht nie in Texte oder
/// Protokolle ein.
class PairResponse {
  const PairResponse({
    required this.registerId,
    required this.registerName,
    required this.businessId,
    required this.businessName,
    required this.token,
  });

  factory PairResponse.fromJson(Map<String, dynamic> json) => PairResponse(
    registerId: _field(json, 'registerId'),
    registerName: _field(json, 'registerName'),
    businessId: _field(json, 'businessId'),
    businessName: _field(json, 'businessName'),
    token: _field(json, 'token'),
  );

  final String registerId;
  final String registerName;
  final String businessId;
  final String businessName;
  final String token;

  @override
  String toString() =>
      'PairResponse(registerId: $registerId, businessId: $businessId)';
}

/// Die Speisekarte in der Form der Nachrichten ohne `archived`, `favorite`
/// und `inSale`. Das ist auch die Form, die der Server beim Lesen der
/// Speisekarten-Datei erzeugt.
Map<String, Object?> catalogToWire(Catalog c) => {
  'business': {
    'name': c.business.name,
    'addressLines': c.business.addressLines,
    'vatId': c.business.vatId,
    'receiptFooter': c.business.receiptFooter,
  },
  'categories': [
    for (final k in c.categories)
      {'id': k.id, 'name': k.name, 'position': k.position},
  ],
  'items': [
    for (final i in c.items)
      {
        'id': i.id,
        'name': i.name,
        'priceCents': i.priceCents,
        'categoryId': i.categoryId,
        'taxPercent': i.taxRate.percent,
        'depositCents': i.depositCents,
        'tags': [for (final t in i.tags) t.name],
        'info': i.info,
        'templateId': i.templateId,
        'position': i.position,
      },
  ],
  'templates': [
    for (final t in c.templates)
      {
        'id': t.id,
        'name': t.name,
        'groups': [
          for (final g in t.groups)
            {
              'id': g.id,
              'name': g.name,
              'min': g.min,
              'max': g.max,
              'options': [
                for (final o in g.options)
                  {
                    'id': o.id,
                    'name': o.name,
                    'surchargeCents': o.surchargeCents,
                    'isDefault': o.isDefault,
                    'taxPercent': o.taxRate?.percent,
                    'depositCents': o.depositCents,
                  },
              ],
            },
        ],
      },
  ],
  'staffSeeds': [
    for (final s in c.staffSeeds)
      {
        'name': s.name,
        'pin': s.pin,
        'role': s.role == StaffRole.chef ? 'chef' : 'staff',
      },
  ],
};
