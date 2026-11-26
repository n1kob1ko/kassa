// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $BusinessRowsTable extends BusinessRows
    with TableInfo<$BusinessRowsTable, BusinessRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BusinessRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressLinesMeta = const VerificationMeta(
    'addressLines',
  );
  @override
  late final GeneratedColumn<String> addressLines = GeneratedColumn<String>(
    'address_lines',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _vatIdMeta = const VerificationMeta('vatId');
  @override
  late final GeneratedColumn<String> vatId = GeneratedColumn<String>(
    'vat_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receiptFooterMeta = const VerificationMeta(
    'receiptFooter',
  );
  @override
  late final GeneratedColumn<String> receiptFooter = GeneratedColumn<String>(
    'receipt_footer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logoFileIdMeta = const VerificationMeta(
    'logoFileId',
  );
  @override
  late final GeneratedColumn<String> logoFileId = GeneratedColumn<String>(
    'logo_file_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logoPathMeta = const VerificationMeta(
    'logoPath',
  );
  @override
  late final GeneratedColumn<String> logoPath = GeneratedColumn<String>(
    'logo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logoColorMeta = const VerificationMeta(
    'logoColor',
  );
  @override
  late final GeneratedColumn<String> logoColor = GeneratedColumn<String>(
    'logo_color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    addressLines,
    vatId,
    receiptFooter,
    logoFileId,
    logoPath,
    logoColor,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'business';
  @override
  VerificationContext validateIntegrity(
    Insertable<BusinessRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('address_lines')) {
      context.handle(
        _addressLinesMeta,
        addressLines.isAcceptableOrUnknown(
          data['address_lines']!,
          _addressLinesMeta,
        ),
      );
    }
    if (data.containsKey('vat_id')) {
      context.handle(
        _vatIdMeta,
        vatId.isAcceptableOrUnknown(data['vat_id']!, _vatIdMeta),
      );
    }
    if (data.containsKey('receipt_footer')) {
      context.handle(
        _receiptFooterMeta,
        receiptFooter.isAcceptableOrUnknown(
          data['receipt_footer']!,
          _receiptFooterMeta,
        ),
      );
    }
    if (data.containsKey('logo_file_id')) {
      context.handle(
        _logoFileIdMeta,
        logoFileId.isAcceptableOrUnknown(
          data['logo_file_id']!,
          _logoFileIdMeta,
        ),
      );
    }
    if (data.containsKey('logo_path')) {
      context.handle(
        _logoPathMeta,
        logoPath.isAcceptableOrUnknown(data['logo_path']!, _logoPathMeta),
      );
    }
    if (data.containsKey('logo_color')) {
      context.handle(
        _logoColorMeta,
        logoColor.isAcceptableOrUnknown(data['logo_color']!, _logoColorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BusinessRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BusinessRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      addressLines: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address_lines'],
      )!,
      vatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vat_id'],
      ),
      receiptFooter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_footer'],
      ),
      logoFileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo_file_id'],
      ),
      logoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo_path'],
      ),
      logoColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo_color'],
      ),
    );
  }

  @override
  $BusinessRowsTable createAlias(String alias) {
    return $BusinessRowsTable(attachedDatabase, alias);
  }
}

class BusinessRow extends DataClass implements Insertable<BusinessRow> {
  final int id;
  final String name;

  /// Anschrift für den Bon, Zeilen durch `\n` getrennt.
  final String addressLines;
  final String? vatId;
  final String? receiptFooter;

  /// Das Logo vom Server: Kennung der Datei, Pfad auf dem Tablet und die
  /// Farbe als Platzhalter.
  final String? logoFileId;
  final String? logoPath;
  final String? logoColor;
  const BusinessRow({
    required this.id,
    required this.name,
    required this.addressLines,
    this.vatId,
    this.receiptFooter,
    this.logoFileId,
    this.logoPath,
    this.logoColor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['address_lines'] = Variable<String>(addressLines);
    if (!nullToAbsent || vatId != null) {
      map['vat_id'] = Variable<String>(vatId);
    }
    if (!nullToAbsent || receiptFooter != null) {
      map['receipt_footer'] = Variable<String>(receiptFooter);
    }
    if (!nullToAbsent || logoFileId != null) {
      map['logo_file_id'] = Variable<String>(logoFileId);
    }
    if (!nullToAbsent || logoPath != null) {
      map['logo_path'] = Variable<String>(logoPath);
    }
    if (!nullToAbsent || logoColor != null) {
      map['logo_color'] = Variable<String>(logoColor);
    }
    return map;
  }

  BusinessRowsCompanion toCompanion(bool nullToAbsent) {
    return BusinessRowsCompanion(
      id: Value(id),
      name: Value(name),
      addressLines: Value(addressLines),
      vatId: vatId == null && nullToAbsent
          ? const Value.absent()
          : Value(vatId),
      receiptFooter: receiptFooter == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptFooter),
      logoFileId: logoFileId == null && nullToAbsent
          ? const Value.absent()
          : Value(logoFileId),
      logoPath: logoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(logoPath),
      logoColor: logoColor == null && nullToAbsent
          ? const Value.absent()
          : Value(logoColor),
    );
  }

  factory BusinessRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BusinessRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      addressLines: serializer.fromJson<String>(json['addressLines']),
      vatId: serializer.fromJson<String?>(json['vatId']),
      receiptFooter: serializer.fromJson<String?>(json['receiptFooter']),
      logoFileId: serializer.fromJson<String?>(json['logoFileId']),
      logoPath: serializer.fromJson<String?>(json['logoPath']),
      logoColor: serializer.fromJson<String?>(json['logoColor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'addressLines': serializer.toJson<String>(addressLines),
      'vatId': serializer.toJson<String?>(vatId),
      'receiptFooter': serializer.toJson<String?>(receiptFooter),
      'logoFileId': serializer.toJson<String?>(logoFileId),
      'logoPath': serializer.toJson<String?>(logoPath),
      'logoColor': serializer.toJson<String?>(logoColor),
    };
  }

  BusinessRow copyWith({
    int? id,
    String? name,
    String? addressLines,
    Value<String?> vatId = const Value.absent(),
    Value<String?> receiptFooter = const Value.absent(),
    Value<String?> logoFileId = const Value.absent(),
    Value<String?> logoPath = const Value.absent(),
    Value<String?> logoColor = const Value.absent(),
  }) => BusinessRow(
    id: id ?? this.id,
    name: name ?? this.name,
    addressLines: addressLines ?? this.addressLines,
    vatId: vatId.present ? vatId.value : this.vatId,
    receiptFooter: receiptFooter.present
        ? receiptFooter.value
        : this.receiptFooter,
    logoFileId: logoFileId.present ? logoFileId.value : this.logoFileId,
    logoPath: logoPath.present ? logoPath.value : this.logoPath,
    logoColor: logoColor.present ? logoColor.value : this.logoColor,
  );
  BusinessRow copyWithCompanion(BusinessRowsCompanion data) {
    return BusinessRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      addressLines: data.addressLines.present
          ? data.addressLines.value
          : this.addressLines,
      vatId: data.vatId.present ? data.vatId.value : this.vatId,
      receiptFooter: data.receiptFooter.present
          ? data.receiptFooter.value
          : this.receiptFooter,
      logoFileId: data.logoFileId.present
          ? data.logoFileId.value
          : this.logoFileId,
      logoPath: data.logoPath.present ? data.logoPath.value : this.logoPath,
      logoColor: data.logoColor.present ? data.logoColor.value : this.logoColor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BusinessRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('addressLines: $addressLines, ')
          ..write('vatId: $vatId, ')
          ..write('receiptFooter: $receiptFooter, ')
          ..write('logoFileId: $logoFileId, ')
          ..write('logoPath: $logoPath, ')
          ..write('logoColor: $logoColor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    addressLines,
    vatId,
    receiptFooter,
    logoFileId,
    logoPath,
    logoColor,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BusinessRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.addressLines == this.addressLines &&
          other.vatId == this.vatId &&
          other.receiptFooter == this.receiptFooter &&
          other.logoFileId == this.logoFileId &&
          other.logoPath == this.logoPath &&
          other.logoColor == this.logoColor);
}

class BusinessRowsCompanion extends UpdateCompanion<BusinessRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> addressLines;
  final Value<String?> vatId;
  final Value<String?> receiptFooter;
  final Value<String?> logoFileId;
  final Value<String?> logoPath;
  final Value<String?> logoColor;
  const BusinessRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.addressLines = const Value.absent(),
    this.vatId = const Value.absent(),
    this.receiptFooter = const Value.absent(),
    this.logoFileId = const Value.absent(),
    this.logoPath = const Value.absent(),
    this.logoColor = const Value.absent(),
  });
  BusinessRowsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.addressLines = const Value.absent(),
    this.vatId = const Value.absent(),
    this.receiptFooter = const Value.absent(),
    this.logoFileId = const Value.absent(),
    this.logoPath = const Value.absent(),
    this.logoColor = const Value.absent(),
  }) : name = Value(name);
  static Insertable<BusinessRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? addressLines,
    Expression<String>? vatId,
    Expression<String>? receiptFooter,
    Expression<String>? logoFileId,
    Expression<String>? logoPath,
    Expression<String>? logoColor,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (addressLines != null) 'address_lines': addressLines,
      if (vatId != null) 'vat_id': vatId,
      if (receiptFooter != null) 'receipt_footer': receiptFooter,
      if (logoFileId != null) 'logo_file_id': logoFileId,
      if (logoPath != null) 'logo_path': logoPath,
      if (logoColor != null) 'logo_color': logoColor,
    });
  }

  BusinessRowsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? addressLines,
    Value<String?>? vatId,
    Value<String?>? receiptFooter,
    Value<String?>? logoFileId,
    Value<String?>? logoPath,
    Value<String?>? logoColor,
  }) {
    return BusinessRowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      addressLines: addressLines ?? this.addressLines,
      vatId: vatId ?? this.vatId,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      logoFileId: logoFileId ?? this.logoFileId,
      logoPath: logoPath ?? this.logoPath,
      logoColor: logoColor ?? this.logoColor,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (addressLines.present) {
      map['address_lines'] = Variable<String>(addressLines.value);
    }
    if (vatId.present) {
      map['vat_id'] = Variable<String>(vatId.value);
    }
    if (receiptFooter.present) {
      map['receipt_footer'] = Variable<String>(receiptFooter.value);
    }
    if (logoFileId.present) {
      map['logo_file_id'] = Variable<String>(logoFileId.value);
    }
    if (logoPath.present) {
      map['logo_path'] = Variable<String>(logoPath.value);
    }
    if (logoColor.present) {
      map['logo_color'] = Variable<String>(logoColor.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BusinessRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('addressLines: $addressLines, ')
          ..write('vatId: $vatId, ')
          ..write('receiptFooter: $receiptFooter, ')
          ..write('logoFileId: $logoFileId, ')
          ..write('logoPath: $logoPath, ')
          ..write('logoColor: $logoColor')
          ..write(')'))
        .toString();
  }
}

class $CategoryRowsTable extends CategoryRows
    with TableInfo<$CategoryRowsTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, position, archived];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
    );
  }

  @override
  $CategoryRowsTable createAlias(String alias) {
    return $CategoryRowsTable(attachedDatabase, alias);
  }
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  final String id;
  final String name;
  final int position;
  final bool archived;
  const CategoryRow({
    required this.id,
    required this.name,
    required this.position,
    required this.archived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['position'] = Variable<int>(position);
    map['archived'] = Variable<bool>(archived);
    return map;
  }

  CategoryRowsCompanion toCompanion(bool nullToAbsent) {
    return CategoryRowsCompanion(
      id: Value(id),
      name: Value(name),
      position: Value(position),
      archived: Value(archived),
    );
  }

  factory CategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      position: serializer.fromJson<int>(json['position']),
      archived: serializer.fromJson<bool>(json['archived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'position': serializer.toJson<int>(position),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  CategoryRow copyWith({
    String? id,
    String? name,
    int? position,
    bool? archived,
  }) => CategoryRow(
    id: id ?? this.id,
    name: name ?? this.name,
    position: position ?? this.position,
    archived: archived ?? this.archived,
  );
  CategoryRow copyWithCompanion(CategoryRowsCompanion data) {
    return CategoryRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      position: data.position.present ? data.position.value : this.position,
      archived: data.archived.present ? data.archived.value : this.archived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, position, archived);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.position == this.position &&
          other.archived == this.archived);
}

class CategoryRowsCompanion extends UpdateCompanion<CategoryRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> position;
  final Value<bool> archived;
  final Value<int> rowid;
  const CategoryRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.position = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoryRowsCompanion.insert({
    required String id,
    required String name,
    required int position,
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       position = Value(position);
  static Insertable<CategoryRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? position,
    Expression<bool>? archived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (position != null) 'position': position,
      if (archived != null) 'archived': archived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoryRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? position,
    Value<bool>? archived,
    Value<int>? rowid,
  }) {
    return CategoryRowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      archived: archived ?? this.archived,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('archived: $archived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemRowsTable extends ItemRows with TableInfo<$ItemRowsTable, ItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceCentsMeta = const VerificationMeta(
    'priceCents',
  );
  @override
  late final GeneratedColumn<int> priceCents = GeneratedColumn<int>(
    'price_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _taxPercentMeta = const VerificationMeta(
    'taxPercent',
  );
  @override
  late final GeneratedColumn<int> taxPercent = GeneratedColumn<int>(
    'tax_percent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _depositCentsMeta = const VerificationMeta(
    'depositCents',
  );
  @override
  late final GeneratedColumn<int> depositCents = GeneratedColumn<int>(
    'deposit_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _infoMeta = const VerificationMeta('info');
  @override
  late final GeneratedColumn<String> info = GeneratedColumn<String>(
    'info',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _favoriteMeta = const VerificationMeta(
    'favorite',
  );
  @override
  late final GeneratedColumn<bool> favorite = GeneratedColumn<bool>(
    'favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _inSaleMeta = const VerificationMeta('inSale');
  @override
  late final GeneratedColumn<bool> inSale = GeneratedColumn<bool>(
    'in_sale',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("in_sale" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoFileIdMeta = const VerificationMeta(
    'photoFileId',
  );
  @override
  late final GeneratedColumn<String> photoFileId = GeneratedColumn<String>(
    'photo_file_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoColorMeta = const VerificationMeta(
    'photoColor',
  );
  @override
  late final GeneratedColumn<String> photoColor = GeneratedColumn<String>(
    'photo_color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    priceCents,
    categoryId,
    taxPercent,
    depositCents,
    tags,
    info,
    templateId,
    favorite,
    inSale,
    photoPath,
    photoFileId,
    photoColor,
    position,
    archived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price_cents')) {
      context.handle(
        _priceCentsMeta,
        priceCents.isAcceptableOrUnknown(data['price_cents']!, _priceCentsMeta),
      );
    } else if (isInserting) {
      context.missing(_priceCentsMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('tax_percent')) {
      context.handle(
        _taxPercentMeta,
        taxPercent.isAcceptableOrUnknown(data['tax_percent']!, _taxPercentMeta),
      );
    } else if (isInserting) {
      context.missing(_taxPercentMeta);
    }
    if (data.containsKey('deposit_cents')) {
      context.handle(
        _depositCentsMeta,
        depositCents.isAcceptableOrUnknown(
          data['deposit_cents']!,
          _depositCentsMeta,
        ),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('info')) {
      context.handle(
        _infoMeta,
        info.isAcceptableOrUnknown(data['info']!, _infoMeta),
      );
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    }
    if (data.containsKey('favorite')) {
      context.handle(
        _favoriteMeta,
        favorite.isAcceptableOrUnknown(data['favorite']!, _favoriteMeta),
      );
    }
    if (data.containsKey('in_sale')) {
      context.handle(
        _inSaleMeta,
        inSale.isAcceptableOrUnknown(data['in_sale']!, _inSaleMeta),
      );
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    if (data.containsKey('photo_file_id')) {
      context.handle(
        _photoFileIdMeta,
        photoFileId.isAcceptableOrUnknown(
          data['photo_file_id']!,
          _photoFileIdMeta,
        ),
      );
    }
    if (data.containsKey('photo_color')) {
      context.handle(
        _photoColorMeta,
        photoColor.isAcceptableOrUnknown(data['photo_color']!, _photoColorMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      priceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price_cents'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      taxPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tax_percent'],
      )!,
      depositCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deposit_cents'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      info: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}info'],
      ),
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      ),
      favorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}favorite'],
      )!,
      inSale: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}in_sale'],
      )!,
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
      photoFileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_file_id'],
      ),
      photoColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_color'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
    );
  }

  @override
  $ItemRowsTable createAlias(String alias) {
    return $ItemRowsTable(attachedDatabase, alias);
  }
}

class ItemRow extends DataClass implements Insertable<ItemRow> {
  final String id;
  final String name;
  final int priceCents;
  final String categoryId;
  final int taxPercent;
  final int depositCents;

  /// Namen der Kennzeichen, durch Komma getrennt.
  final String tags;
  final String? info;

  /// Bewusst ohne Fremdschlüssel: stillgelegte Artikel dürfen auf eine
  /// Vorlage zeigen, die es in der neuen Datei nicht mehr gibt.
  final String? templateId;
  final bool favorite;
  final bool inSale;
  final String? photoPath;

  /// Das Foto vom Server: Kennung der Datei und Farbe als Platzhalter.
  final String? photoFileId;
  final String? photoColor;
  final int position;
  final bool archived;
  const ItemRow({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.categoryId,
    required this.taxPercent,
    required this.depositCents,
    required this.tags,
    this.info,
    this.templateId,
    required this.favorite,
    required this.inSale,
    this.photoPath,
    this.photoFileId,
    this.photoColor,
    required this.position,
    required this.archived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['price_cents'] = Variable<int>(priceCents);
    map['category_id'] = Variable<String>(categoryId);
    map['tax_percent'] = Variable<int>(taxPercent);
    map['deposit_cents'] = Variable<int>(depositCents);
    map['tags'] = Variable<String>(tags);
    if (!nullToAbsent || info != null) {
      map['info'] = Variable<String>(info);
    }
    if (!nullToAbsent || templateId != null) {
      map['template_id'] = Variable<String>(templateId);
    }
    map['favorite'] = Variable<bool>(favorite);
    map['in_sale'] = Variable<bool>(inSale);
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    if (!nullToAbsent || photoFileId != null) {
      map['photo_file_id'] = Variable<String>(photoFileId);
    }
    if (!nullToAbsent || photoColor != null) {
      map['photo_color'] = Variable<String>(photoColor);
    }
    map['position'] = Variable<int>(position);
    map['archived'] = Variable<bool>(archived);
    return map;
  }

  ItemRowsCompanion toCompanion(bool nullToAbsent) {
    return ItemRowsCompanion(
      id: Value(id),
      name: Value(name),
      priceCents: Value(priceCents),
      categoryId: Value(categoryId),
      taxPercent: Value(taxPercent),
      depositCents: Value(depositCents),
      tags: Value(tags),
      info: info == null && nullToAbsent ? const Value.absent() : Value(info),
      templateId: templateId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateId),
      favorite: Value(favorite),
      inSale: Value(inSale),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
      photoFileId: photoFileId == null && nullToAbsent
          ? const Value.absent()
          : Value(photoFileId),
      photoColor: photoColor == null && nullToAbsent
          ? const Value.absent()
          : Value(photoColor),
      position: Value(position),
      archived: Value(archived),
    );
  }

  factory ItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      priceCents: serializer.fromJson<int>(json['priceCents']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      taxPercent: serializer.fromJson<int>(json['taxPercent']),
      depositCents: serializer.fromJson<int>(json['depositCents']),
      tags: serializer.fromJson<String>(json['tags']),
      info: serializer.fromJson<String?>(json['info']),
      templateId: serializer.fromJson<String?>(json['templateId']),
      favorite: serializer.fromJson<bool>(json['favorite']),
      inSale: serializer.fromJson<bool>(json['inSale']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
      photoFileId: serializer.fromJson<String?>(json['photoFileId']),
      photoColor: serializer.fromJson<String?>(json['photoColor']),
      position: serializer.fromJson<int>(json['position']),
      archived: serializer.fromJson<bool>(json['archived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'priceCents': serializer.toJson<int>(priceCents),
      'categoryId': serializer.toJson<String>(categoryId),
      'taxPercent': serializer.toJson<int>(taxPercent),
      'depositCents': serializer.toJson<int>(depositCents),
      'tags': serializer.toJson<String>(tags),
      'info': serializer.toJson<String?>(info),
      'templateId': serializer.toJson<String?>(templateId),
      'favorite': serializer.toJson<bool>(favorite),
      'inSale': serializer.toJson<bool>(inSale),
      'photoPath': serializer.toJson<String?>(photoPath),
      'photoFileId': serializer.toJson<String?>(photoFileId),
      'photoColor': serializer.toJson<String?>(photoColor),
      'position': serializer.toJson<int>(position),
      'archived': serializer.toJson<bool>(archived),
    };
  }

  ItemRow copyWith({
    String? id,
    String? name,
    int? priceCents,
    String? categoryId,
    int? taxPercent,
    int? depositCents,
    String? tags,
    Value<String?> info = const Value.absent(),
    Value<String?> templateId = const Value.absent(),
    bool? favorite,
    bool? inSale,
    Value<String?> photoPath = const Value.absent(),
    Value<String?> photoFileId = const Value.absent(),
    Value<String?> photoColor = const Value.absent(),
    int? position,
    bool? archived,
  }) => ItemRow(
    id: id ?? this.id,
    name: name ?? this.name,
    priceCents: priceCents ?? this.priceCents,
    categoryId: categoryId ?? this.categoryId,
    taxPercent: taxPercent ?? this.taxPercent,
    depositCents: depositCents ?? this.depositCents,
    tags: tags ?? this.tags,
    info: info.present ? info.value : this.info,
    templateId: templateId.present ? templateId.value : this.templateId,
    favorite: favorite ?? this.favorite,
    inSale: inSale ?? this.inSale,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
    photoFileId: photoFileId.present ? photoFileId.value : this.photoFileId,
    photoColor: photoColor.present ? photoColor.value : this.photoColor,
    position: position ?? this.position,
    archived: archived ?? this.archived,
  );
  ItemRow copyWithCompanion(ItemRowsCompanion data) {
    return ItemRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      priceCents: data.priceCents.present
          ? data.priceCents.value
          : this.priceCents,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      taxPercent: data.taxPercent.present
          ? data.taxPercent.value
          : this.taxPercent,
      depositCents: data.depositCents.present
          ? data.depositCents.value
          : this.depositCents,
      tags: data.tags.present ? data.tags.value : this.tags,
      info: data.info.present ? data.info.value : this.info,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
      inSale: data.inSale.present ? data.inSale.value : this.inSale,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      photoFileId: data.photoFileId.present
          ? data.photoFileId.value
          : this.photoFileId,
      photoColor: data.photoColor.present
          ? data.photoColor.value
          : this.photoColor,
      position: data.position.present ? data.position.value : this.position,
      archived: data.archived.present ? data.archived.value : this.archived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('priceCents: $priceCents, ')
          ..write('categoryId: $categoryId, ')
          ..write('taxPercent: $taxPercent, ')
          ..write('depositCents: $depositCents, ')
          ..write('tags: $tags, ')
          ..write('info: $info, ')
          ..write('templateId: $templateId, ')
          ..write('favorite: $favorite, ')
          ..write('inSale: $inSale, ')
          ..write('photoPath: $photoPath, ')
          ..write('photoFileId: $photoFileId, ')
          ..write('photoColor: $photoColor, ')
          ..write('position: $position, ')
          ..write('archived: $archived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    priceCents,
    categoryId,
    taxPercent,
    depositCents,
    tags,
    info,
    templateId,
    favorite,
    inSale,
    photoPath,
    photoFileId,
    photoColor,
    position,
    archived,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.priceCents == this.priceCents &&
          other.categoryId == this.categoryId &&
          other.taxPercent == this.taxPercent &&
          other.depositCents == this.depositCents &&
          other.tags == this.tags &&
          other.info == this.info &&
          other.templateId == this.templateId &&
          other.favorite == this.favorite &&
          other.inSale == this.inSale &&
          other.photoPath == this.photoPath &&
          other.photoFileId == this.photoFileId &&
          other.photoColor == this.photoColor &&
          other.position == this.position &&
          other.archived == this.archived);
}

class ItemRowsCompanion extends UpdateCompanion<ItemRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> priceCents;
  final Value<String> categoryId;
  final Value<int> taxPercent;
  final Value<int> depositCents;
  final Value<String> tags;
  final Value<String?> info;
  final Value<String?> templateId;
  final Value<bool> favorite;
  final Value<bool> inSale;
  final Value<String?> photoPath;
  final Value<String?> photoFileId;
  final Value<String?> photoColor;
  final Value<int> position;
  final Value<bool> archived;
  final Value<int> rowid;
  const ItemRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.priceCents = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.taxPercent = const Value.absent(),
    this.depositCents = const Value.absent(),
    this.tags = const Value.absent(),
    this.info = const Value.absent(),
    this.templateId = const Value.absent(),
    this.favorite = const Value.absent(),
    this.inSale = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.photoFileId = const Value.absent(),
    this.photoColor = const Value.absent(),
    this.position = const Value.absent(),
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemRowsCompanion.insert({
    required String id,
    required String name,
    required int priceCents,
    required String categoryId,
    required int taxPercent,
    this.depositCents = const Value.absent(),
    this.tags = const Value.absent(),
    this.info = const Value.absent(),
    this.templateId = const Value.absent(),
    this.favorite = const Value.absent(),
    this.inSale = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.photoFileId = const Value.absent(),
    this.photoColor = const Value.absent(),
    required int position,
    this.archived = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       priceCents = Value(priceCents),
       categoryId = Value(categoryId),
       taxPercent = Value(taxPercent),
       position = Value(position);
  static Insertable<ItemRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? priceCents,
    Expression<String>? categoryId,
    Expression<int>? taxPercent,
    Expression<int>? depositCents,
    Expression<String>? tags,
    Expression<String>? info,
    Expression<String>? templateId,
    Expression<bool>? favorite,
    Expression<bool>? inSale,
    Expression<String>? photoPath,
    Expression<String>? photoFileId,
    Expression<String>? photoColor,
    Expression<int>? position,
    Expression<bool>? archived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (priceCents != null) 'price_cents': priceCents,
      if (categoryId != null) 'category_id': categoryId,
      if (taxPercent != null) 'tax_percent': taxPercent,
      if (depositCents != null) 'deposit_cents': depositCents,
      if (tags != null) 'tags': tags,
      if (info != null) 'info': info,
      if (templateId != null) 'template_id': templateId,
      if (favorite != null) 'favorite': favorite,
      if (inSale != null) 'in_sale': inSale,
      if (photoPath != null) 'photo_path': photoPath,
      if (photoFileId != null) 'photo_file_id': photoFileId,
      if (photoColor != null) 'photo_color': photoColor,
      if (position != null) 'position': position,
      if (archived != null) 'archived': archived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? priceCents,
    Value<String>? categoryId,
    Value<int>? taxPercent,
    Value<int>? depositCents,
    Value<String>? tags,
    Value<String?>? info,
    Value<String?>? templateId,
    Value<bool>? favorite,
    Value<bool>? inSale,
    Value<String?>? photoPath,
    Value<String?>? photoFileId,
    Value<String?>? photoColor,
    Value<int>? position,
    Value<bool>? archived,
    Value<int>? rowid,
  }) {
    return ItemRowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      priceCents: priceCents ?? this.priceCents,
      categoryId: categoryId ?? this.categoryId,
      taxPercent: taxPercent ?? this.taxPercent,
      depositCents: depositCents ?? this.depositCents,
      tags: tags ?? this.tags,
      info: info ?? this.info,
      templateId: templateId ?? this.templateId,
      favorite: favorite ?? this.favorite,
      inSale: inSale ?? this.inSale,
      photoPath: photoPath ?? this.photoPath,
      photoFileId: photoFileId ?? this.photoFileId,
      photoColor: photoColor ?? this.photoColor,
      position: position ?? this.position,
      archived: archived ?? this.archived,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (priceCents.present) {
      map['price_cents'] = Variable<int>(priceCents.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (taxPercent.present) {
      map['tax_percent'] = Variable<int>(taxPercent.value);
    }
    if (depositCents.present) {
      map['deposit_cents'] = Variable<int>(depositCents.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (info.present) {
      map['info'] = Variable<String>(info.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (favorite.present) {
      map['favorite'] = Variable<bool>(favorite.value);
    }
    if (inSale.present) {
      map['in_sale'] = Variable<bool>(inSale.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (photoFileId.present) {
      map['photo_file_id'] = Variable<String>(photoFileId.value);
    }
    if (photoColor.present) {
      map['photo_color'] = Variable<String>(photoColor.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('priceCents: $priceCents, ')
          ..write('categoryId: $categoryId, ')
          ..write('taxPercent: $taxPercent, ')
          ..write('depositCents: $depositCents, ')
          ..write('tags: $tags, ')
          ..write('info: $info, ')
          ..write('templateId: $templateId, ')
          ..write('favorite: $favorite, ')
          ..write('inSale: $inSale, ')
          ..write('photoPath: $photoPath, ')
          ..write('photoFileId: $photoFileId, ')
          ..write('photoColor: $photoColor, ')
          ..write('position: $position, ')
          ..write('archived: $archived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModifierTemplateRowsTable extends ModifierTemplateRows
    with TableInfo<$ModifierTemplateRowsTable, ModifierTemplateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModifierTemplateRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'modifier_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModifierTemplateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ModifierTemplateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModifierTemplateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $ModifierTemplateRowsTable createAlias(String alias) {
    return $ModifierTemplateRowsTable(attachedDatabase, alias);
  }
}

class ModifierTemplateRow extends DataClass
    implements Insertable<ModifierTemplateRow> {
  final String id;
  final String name;
  final int position;
  const ModifierTemplateRow({
    required this.id,
    required this.name,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['position'] = Variable<int>(position);
    return map;
  }

  ModifierTemplateRowsCompanion toCompanion(bool nullToAbsent) {
    return ModifierTemplateRowsCompanion(
      id: Value(id),
      name: Value(name),
      position: Value(position),
    );
  }

  factory ModifierTemplateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModifierTemplateRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'position': serializer.toJson<int>(position),
    };
  }

  ModifierTemplateRow copyWith({String? id, String? name, int? position}) =>
      ModifierTemplateRow(
        id: id ?? this.id,
        name: name ?? this.name,
        position: position ?? this.position,
      );
  ModifierTemplateRow copyWithCompanion(ModifierTemplateRowsCompanion data) {
    return ModifierTemplateRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModifierTemplateRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModifierTemplateRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.position == this.position);
}

class ModifierTemplateRowsCompanion
    extends UpdateCompanion<ModifierTemplateRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> position;
  final Value<int> rowid;
  const ModifierTemplateRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModifierTemplateRowsCompanion.insert({
    required String id,
    required String name,
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       position = Value(position);
  static Insertable<ModifierTemplateRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModifierTemplateRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return ModifierTemplateRowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModifierTemplateRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModifierGroupRowsTable extends ModifierGroupRows
    with TableInfo<$ModifierGroupRowsTable, ModifierGroupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModifierGroupRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES modifier_templates (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minCountMeta = const VerificationMeta(
    'minCount',
  );
  @override
  late final GeneratedColumn<int> minCount = GeneratedColumn<int>(
    'min_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxCountMeta = const VerificationMeta(
    'maxCount',
  );
  @override
  late final GeneratedColumn<int> maxCount = GeneratedColumn<int>(
    'max_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    templateId,
    name,
    minCount,
    maxCount,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'modifier_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModifierGroupRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    } else if (isInserting) {
      context.missing(_templateIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('min_count')) {
      context.handle(
        _minCountMeta,
        minCount.isAcceptableOrUnknown(data['min_count']!, _minCountMeta),
      );
    } else if (isInserting) {
      context.missing(_minCountMeta);
    }
    if (data.containsKey('max_count')) {
      context.handle(
        _maxCountMeta,
        maxCount.isAcceptableOrUnknown(data['max_count']!, _maxCountMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ModifierGroupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModifierGroupRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      minCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}min_count'],
      )!,
      maxCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_count'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $ModifierGroupRowsTable createAlias(String alias) {
    return $ModifierGroupRowsTable(attachedDatabase, alias);
  }
}

class ModifierGroupRow extends DataClass
    implements Insertable<ModifierGroupRow> {
  final String id;
  final String templateId;
  final String name;
  final int minCount;

  /// `null` heißt ohne Grenze.
  final int? maxCount;
  final int position;
  const ModifierGroupRow({
    required this.id,
    required this.templateId,
    required this.name,
    required this.minCount,
    this.maxCount,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['template_id'] = Variable<String>(templateId);
    map['name'] = Variable<String>(name);
    map['min_count'] = Variable<int>(minCount);
    if (!nullToAbsent || maxCount != null) {
      map['max_count'] = Variable<int>(maxCount);
    }
    map['position'] = Variable<int>(position);
    return map;
  }

  ModifierGroupRowsCompanion toCompanion(bool nullToAbsent) {
    return ModifierGroupRowsCompanion(
      id: Value(id),
      templateId: Value(templateId),
      name: Value(name),
      minCount: Value(minCount),
      maxCount: maxCount == null && nullToAbsent
          ? const Value.absent()
          : Value(maxCount),
      position: Value(position),
    );
  }

  factory ModifierGroupRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModifierGroupRow(
      id: serializer.fromJson<String>(json['id']),
      templateId: serializer.fromJson<String>(json['templateId']),
      name: serializer.fromJson<String>(json['name']),
      minCount: serializer.fromJson<int>(json['minCount']),
      maxCount: serializer.fromJson<int?>(json['maxCount']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'templateId': serializer.toJson<String>(templateId),
      'name': serializer.toJson<String>(name),
      'minCount': serializer.toJson<int>(minCount),
      'maxCount': serializer.toJson<int?>(maxCount),
      'position': serializer.toJson<int>(position),
    };
  }

  ModifierGroupRow copyWith({
    String? id,
    String? templateId,
    String? name,
    int? minCount,
    Value<int?> maxCount = const Value.absent(),
    int? position,
  }) => ModifierGroupRow(
    id: id ?? this.id,
    templateId: templateId ?? this.templateId,
    name: name ?? this.name,
    minCount: minCount ?? this.minCount,
    maxCount: maxCount.present ? maxCount.value : this.maxCount,
    position: position ?? this.position,
  );
  ModifierGroupRow copyWithCompanion(ModifierGroupRowsCompanion data) {
    return ModifierGroupRow(
      id: data.id.present ? data.id.value : this.id,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      name: data.name.present ? data.name.value : this.name,
      minCount: data.minCount.present ? data.minCount.value : this.minCount,
      maxCount: data.maxCount.present ? data.maxCount.value : this.maxCount,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModifierGroupRow(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('name: $name, ')
          ..write('minCount: $minCount, ')
          ..write('maxCount: $maxCount, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, templateId, name, minCount, maxCount, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModifierGroupRow &&
          other.id == this.id &&
          other.templateId == this.templateId &&
          other.name == this.name &&
          other.minCount == this.minCount &&
          other.maxCount == this.maxCount &&
          other.position == this.position);
}

class ModifierGroupRowsCompanion extends UpdateCompanion<ModifierGroupRow> {
  final Value<String> id;
  final Value<String> templateId;
  final Value<String> name;
  final Value<int> minCount;
  final Value<int?> maxCount;
  final Value<int> position;
  final Value<int> rowid;
  const ModifierGroupRowsCompanion({
    this.id = const Value.absent(),
    this.templateId = const Value.absent(),
    this.name = const Value.absent(),
    this.minCount = const Value.absent(),
    this.maxCount = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModifierGroupRowsCompanion.insert({
    required String id,
    required String templateId,
    required String name,
    required int minCount,
    this.maxCount = const Value.absent(),
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       templateId = Value(templateId),
       name = Value(name),
       minCount = Value(minCount),
       position = Value(position);
  static Insertable<ModifierGroupRow> custom({
    Expression<String>? id,
    Expression<String>? templateId,
    Expression<String>? name,
    Expression<int>? minCount,
    Expression<int>? maxCount,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (templateId != null) 'template_id': templateId,
      if (name != null) 'name': name,
      if (minCount != null) 'min_count': minCount,
      if (maxCount != null) 'max_count': maxCount,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModifierGroupRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? templateId,
    Value<String>? name,
    Value<int>? minCount,
    Value<int?>? maxCount,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return ModifierGroupRowsCompanion(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      name: name ?? this.name,
      minCount: minCount ?? this.minCount,
      maxCount: maxCount ?? this.maxCount,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (minCount.present) {
      map['min_count'] = Variable<int>(minCount.value);
    }
    if (maxCount.present) {
      map['max_count'] = Variable<int>(maxCount.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModifierGroupRowsCompanion(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('name: $name, ')
          ..write('minCount: $minCount, ')
          ..write('maxCount: $maxCount, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ModifierOptionRowsTable extends ModifierOptionRows
    with TableInfo<$ModifierOptionRowsTable, ModifierOptionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModifierOptionRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES modifier_groups (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _surchargeCentsMeta = const VerificationMeta(
    'surchargeCents',
  );
  @override
  late final GeneratedColumn<int> surchargeCents = GeneratedColumn<int>(
    'surcharge_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _taxPercentMeta = const VerificationMeta(
    'taxPercent',
  );
  @override
  late final GeneratedColumn<int> taxPercent = GeneratedColumn<int>(
    'tax_percent',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _depositCentsMeta = const VerificationMeta(
    'depositCents',
  );
  @override
  late final GeneratedColumn<int> depositCents = GeneratedColumn<int>(
    'deposit_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    name,
    surchargeCents,
    isDefault,
    taxPercent,
    depositCents,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'modifier_options';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModifierOptionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('surcharge_cents')) {
      context.handle(
        _surchargeCentsMeta,
        surchargeCents.isAcceptableOrUnknown(
          data['surcharge_cents']!,
          _surchargeCentsMeta,
        ),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('tax_percent')) {
      context.handle(
        _taxPercentMeta,
        taxPercent.isAcceptableOrUnknown(data['tax_percent']!, _taxPercentMeta),
      );
    }
    if (data.containsKey('deposit_cents')) {
      context.handle(
        _depositCentsMeta,
        depositCents.isAcceptableOrUnknown(
          data['deposit_cents']!,
          _depositCentsMeta,
        ),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ModifierOptionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModifierOptionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      surchargeCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}surcharge_cents'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      taxPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tax_percent'],
      ),
      depositCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deposit_cents'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $ModifierOptionRowsTable createAlias(String alias) {
    return $ModifierOptionRowsTable(attachedDatabase, alias);
  }
}

class ModifierOptionRow extends DataClass
    implements Insertable<ModifierOptionRow> {
  final String id;
  final String groupId;
  final String name;
  final int surchargeCents;
  final bool isDefault;
  final int? taxPercent;
  final int? depositCents;
  final int position;
  const ModifierOptionRow({
    required this.id,
    required this.groupId,
    required this.name,
    required this.surchargeCents,
    required this.isDefault,
    this.taxPercent,
    this.depositCents,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['name'] = Variable<String>(name);
    map['surcharge_cents'] = Variable<int>(surchargeCents);
    map['is_default'] = Variable<bool>(isDefault);
    if (!nullToAbsent || taxPercent != null) {
      map['tax_percent'] = Variable<int>(taxPercent);
    }
    if (!nullToAbsent || depositCents != null) {
      map['deposit_cents'] = Variable<int>(depositCents);
    }
    map['position'] = Variable<int>(position);
    return map;
  }

  ModifierOptionRowsCompanion toCompanion(bool nullToAbsent) {
    return ModifierOptionRowsCompanion(
      id: Value(id),
      groupId: Value(groupId),
      name: Value(name),
      surchargeCents: Value(surchargeCents),
      isDefault: Value(isDefault),
      taxPercent: taxPercent == null && nullToAbsent
          ? const Value.absent()
          : Value(taxPercent),
      depositCents: depositCents == null && nullToAbsent
          ? const Value.absent()
          : Value(depositCents),
      position: Value(position),
    );
  }

  factory ModifierOptionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModifierOptionRow(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      name: serializer.fromJson<String>(json['name']),
      surchargeCents: serializer.fromJson<int>(json['surchargeCents']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      taxPercent: serializer.fromJson<int?>(json['taxPercent']),
      depositCents: serializer.fromJson<int?>(json['depositCents']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'name': serializer.toJson<String>(name),
      'surchargeCents': serializer.toJson<int>(surchargeCents),
      'isDefault': serializer.toJson<bool>(isDefault),
      'taxPercent': serializer.toJson<int?>(taxPercent),
      'depositCents': serializer.toJson<int?>(depositCents),
      'position': serializer.toJson<int>(position),
    };
  }

  ModifierOptionRow copyWith({
    String? id,
    String? groupId,
    String? name,
    int? surchargeCents,
    bool? isDefault,
    Value<int?> taxPercent = const Value.absent(),
    Value<int?> depositCents = const Value.absent(),
    int? position,
  }) => ModifierOptionRow(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    name: name ?? this.name,
    surchargeCents: surchargeCents ?? this.surchargeCents,
    isDefault: isDefault ?? this.isDefault,
    taxPercent: taxPercent.present ? taxPercent.value : this.taxPercent,
    depositCents: depositCents.present ? depositCents.value : this.depositCents,
    position: position ?? this.position,
  );
  ModifierOptionRow copyWithCompanion(ModifierOptionRowsCompanion data) {
    return ModifierOptionRow(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      name: data.name.present ? data.name.value : this.name,
      surchargeCents: data.surchargeCents.present
          ? data.surchargeCents.value
          : this.surchargeCents,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      taxPercent: data.taxPercent.present
          ? data.taxPercent.value
          : this.taxPercent,
      depositCents: data.depositCents.present
          ? data.depositCents.value
          : this.depositCents,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModifierOptionRow(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('surchargeCents: $surchargeCents, ')
          ..write('isDefault: $isDefault, ')
          ..write('taxPercent: $taxPercent, ')
          ..write('depositCents: $depositCents, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    name,
    surchargeCents,
    isDefault,
    taxPercent,
    depositCents,
    position,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModifierOptionRow &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.name == this.name &&
          other.surchargeCents == this.surchargeCents &&
          other.isDefault == this.isDefault &&
          other.taxPercent == this.taxPercent &&
          other.depositCents == this.depositCents &&
          other.position == this.position);
}

class ModifierOptionRowsCompanion extends UpdateCompanion<ModifierOptionRow> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> name;
  final Value<int> surchargeCents;
  final Value<bool> isDefault;
  final Value<int?> taxPercent;
  final Value<int?> depositCents;
  final Value<int> position;
  final Value<int> rowid;
  const ModifierOptionRowsCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.name = const Value.absent(),
    this.surchargeCents = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.taxPercent = const Value.absent(),
    this.depositCents = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModifierOptionRowsCompanion.insert({
    required String id,
    required String groupId,
    required String name,
    this.surchargeCents = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.taxPercent = const Value.absent(),
    this.depositCents = const Value.absent(),
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       name = Value(name),
       position = Value(position);
  static Insertable<ModifierOptionRow> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? name,
    Expression<int>? surchargeCents,
    Expression<bool>? isDefault,
    Expression<int>? taxPercent,
    Expression<int>? depositCents,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (name != null) 'name': name,
      if (surchargeCents != null) 'surcharge_cents': surchargeCents,
      if (isDefault != null) 'is_default': isDefault,
      if (taxPercent != null) 'tax_percent': taxPercent,
      if (depositCents != null) 'deposit_cents': depositCents,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModifierOptionRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? name,
    Value<int>? surchargeCents,
    Value<bool>? isDefault,
    Value<int?>? taxPercent,
    Value<int?>? depositCents,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return ModifierOptionRowsCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      surchargeCents: surchargeCents ?? this.surchargeCents,
      isDefault: isDefault ?? this.isDefault,
      taxPercent: taxPercent ?? this.taxPercent,
      depositCents: depositCents ?? this.depositCents,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (surchargeCents.present) {
      map['surcharge_cents'] = Variable<int>(surchargeCents.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (taxPercent.present) {
      map['tax_percent'] = Variable<int>(taxPercent.value);
    }
    if (depositCents.present) {
      map['deposit_cents'] = Variable<int>(depositCents.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModifierOptionRowsCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('name: $name, ')
          ..write('surchargeCents: $surchargeCents, ')
          ..write('isDefault: $isDefault, ')
          ..write('taxPercent: $taxPercent, ')
          ..write('depositCents: $depositCents, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StaffRowsTable extends StaffRows
    with TableInfo<$StaffRowsTable, StaffRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StaffRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinSaltMeta = const VerificationMeta(
    'pinSalt',
  );
  @override
  late final GeneratedColumn<String> pinSalt = GeneratedColumn<String>(
    'pin_salt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinHashMeta = const VerificationMeta(
    'pinHash',
  );
  @override
  late final GeneratedColumn<String> pinHash = GeneratedColumn<String>(
    'pin_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, role, pinSalt, pinHash];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'staff';
  @override
  VerificationContext validateIntegrity(
    Insertable<StaffRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('pin_salt')) {
      context.handle(
        _pinSaltMeta,
        pinSalt.isAcceptableOrUnknown(data['pin_salt']!, _pinSaltMeta),
      );
    } else if (isInserting) {
      context.missing(_pinSaltMeta);
    }
    if (data.containsKey('pin_hash')) {
      context.handle(
        _pinHashMeta,
        pinHash.isAcceptableOrUnknown(data['pin_hash']!, _pinHashMeta),
      );
    } else if (isInserting) {
      context.missing(_pinHashMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StaffRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StaffRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      pinSalt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_salt'],
      )!,
      pinHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_hash'],
      )!,
    );
  }

  @override
  $StaffRowsTable createAlias(String alias) {
    return $StaffRowsTable(attachedDatabase, alias);
  }
}

class StaffRow extends DataClass implements Insertable<StaffRow> {
  final String id;
  final String name;
  final String role;
  final String pinSalt;
  final String pinHash;
  const StaffRow({
    required this.id,
    required this.name,
    required this.role,
    required this.pinSalt,
    required this.pinHash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['role'] = Variable<String>(role);
    map['pin_salt'] = Variable<String>(pinSalt);
    map['pin_hash'] = Variable<String>(pinHash);
    return map;
  }

  StaffRowsCompanion toCompanion(bool nullToAbsent) {
    return StaffRowsCompanion(
      id: Value(id),
      name: Value(name),
      role: Value(role),
      pinSalt: Value(pinSalt),
      pinHash: Value(pinHash),
    );
  }

  factory StaffRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StaffRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      role: serializer.fromJson<String>(json['role']),
      pinSalt: serializer.fromJson<String>(json['pinSalt']),
      pinHash: serializer.fromJson<String>(json['pinHash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'role': serializer.toJson<String>(role),
      'pinSalt': serializer.toJson<String>(pinSalt),
      'pinHash': serializer.toJson<String>(pinHash),
    };
  }

  StaffRow copyWith({
    String? id,
    String? name,
    String? role,
    String? pinSalt,
    String? pinHash,
  }) => StaffRow(
    id: id ?? this.id,
    name: name ?? this.name,
    role: role ?? this.role,
    pinSalt: pinSalt ?? this.pinSalt,
    pinHash: pinHash ?? this.pinHash,
  );
  StaffRow copyWithCompanion(StaffRowsCompanion data) {
    return StaffRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      role: data.role.present ? data.role.value : this.role,
      pinSalt: data.pinSalt.present ? data.pinSalt.value : this.pinSalt,
      pinHash: data.pinHash.present ? data.pinHash.value : this.pinHash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StaffRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('role: $role, ')
          ..write('pinSalt: $pinSalt, ')
          ..write('pinHash: $pinHash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, role, pinSalt, pinHash);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StaffRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.role == this.role &&
          other.pinSalt == this.pinSalt &&
          other.pinHash == this.pinHash);
}

class StaffRowsCompanion extends UpdateCompanion<StaffRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> role;
  final Value<String> pinSalt;
  final Value<String> pinHash;
  final Value<int> rowid;
  const StaffRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.role = const Value.absent(),
    this.pinSalt = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StaffRowsCompanion.insert({
    required String id,
    required String name,
    required String role,
    required String pinSalt,
    required String pinHash,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       role = Value(role),
       pinSalt = Value(pinSalt),
       pinHash = Value(pinHash);
  static Insertable<StaffRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? role,
    Expression<String>? pinSalt,
    Expression<String>? pinHash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (role != null) 'role': role,
      if (pinSalt != null) 'pin_salt': pinSalt,
      if (pinHash != null) 'pin_hash': pinHash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StaffRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? role,
    Value<String>? pinSalt,
    Value<String>? pinHash,
    Value<int>? rowid,
  }) {
    return StaffRowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      pinSalt: pinSalt ?? this.pinSalt,
      pinHash: pinHash ?? this.pinHash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (pinSalt.present) {
      map['pin_salt'] = Variable<String>(pinSalt.value);
    }
    if (pinHash.present) {
      map['pin_hash'] = Variable<String>(pinHash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StaffRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('role: $role, ')
          ..write('pinSalt: $pinSalt, ')
          ..write('pinHash: $pinHash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsRowsTable extends SettingsRows
    with TableInfo<$SettingsRowsTable, SettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cashDrawerEnabledMeta = const VerificationMeta(
    'cashDrawerEnabled',
  );
  @override
  late final GeneratedColumn<bool> cashDrawerEnabled = GeneratedColumn<bool>(
    'cash_drawer_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("cash_drawer_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _showImagesMeta = const VerificationMeta(
    'showImages',
  );
  @override
  late final GeneratedColumn<bool> showImages = GeneratedColumn<bool>(
    'show_images',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_images" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  static const VerificationMeta _voidRequiresChefMeta = const VerificationMeta(
    'voidRequiresChef',
  );
  @override
  late final GeneratedColumn<bool> voidRequiresChef = GeneratedColumn<bool>(
    'void_requires_chef',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("void_requires_chef" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _receiptDraftMeta = const VerificationMeta(
    'receiptDraft',
  );
  @override
  late final GeneratedColumn<String> receiptDraft = GeneratedColumn<String>(
    'receipt_draft',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _printerKindMeta = const VerificationMeta(
    'printerKind',
  );
  @override
  late final GeneratedColumn<String> printerKind = GeneratedColumn<String>(
    'printer_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _printerAddressMeta = const VerificationMeta(
    'printerAddress',
  );
  @override
  late final GeneratedColumn<String> printerAddress = GeneratedColumn<String>(
    'printer_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _printerNameMeta = const VerificationMeta(
    'printerName',
  );
  @override
  late final GeneratedColumn<String> printerName = GeneratedColumn<String>(
    'printer_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _printerColumnsMeta = const VerificationMeta(
    'printerColumns',
  );
  @override
  late final GeneratedColumn<int> printerColumns = GeneratedColumn<int>(
    'printer_columns',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(48),
  );
  static const VerificationMeta _printerQrAsImageMeta = const VerificationMeta(
    'printerQrAsImage',
  );
  @override
  late final GeneratedColumn<bool> printerQrAsImage = GeneratedColumn<bool>(
    'printer_qr_as_image',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("printer_qr_as_image" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('de'),
  );
  static const VerificationMeta _kitchenModeMeta = const VerificationMeta(
    'kitchenMode',
  );
  @override
  late final GeneratedColumn<String> kitchenMode = GeneratedColumn<String>(
    'kitchen_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('off'),
  );
  static const VerificationMeta _kitchenLanguageMeta = const VerificationMeta(
    'kitchenLanguage',
  );
  @override
  late final GeneratedColumn<String> kitchenLanguage = GeneratedColumn<String>(
    'kitchen_language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('de'),
  );
  static const VerificationMeta _kitchenPrinterKindMeta =
      const VerificationMeta('kitchenPrinterKind');
  @override
  late final GeneratedColumn<String> kitchenPrinterKind =
      GeneratedColumn<String>(
        'kitchen_printer_kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('none'),
      );
  static const VerificationMeta _kitchenPrinterAddressMeta =
      const VerificationMeta('kitchenPrinterAddress');
  @override
  late final GeneratedColumn<String> kitchenPrinterAddress =
      GeneratedColumn<String>(
        'kitchen_printer_address',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _kitchenPrinterNameMeta =
      const VerificationMeta('kitchenPrinterName');
  @override
  late final GeneratedColumn<String> kitchenPrinterName =
      GeneratedColumn<String>(
        'kitchen_printer_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _kitchenPrinterColumnsMeta =
      const VerificationMeta('kitchenPrinterColumns');
  @override
  late final GeneratedColumn<int> kitchenPrinterColumns = GeneratedColumn<int>(
    'kitchen_printer_columns',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(48),
  );
  static const VerificationMeta _kitchenSkipCategoriesMeta =
      const VerificationMeta('kitchenSkipCategories');
  @override
  late final GeneratedColumn<String> kitchenSkipCategories =
      GeneratedColumn<String>(
        'kitchen_skip_categories',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cashDrawerEnabled,
    showImages,
    themeMode,
    voidRequiresChef,
    receiptDraft,
    printerKind,
    printerAddress,
    printerName,
    printerColumns,
    printerQrAsImage,
    language,
    kitchenMode,
    kitchenLanguage,
    kitchenPrinterKind,
    kitchenPrinterAddress,
    kitchenPrinterName,
    kitchenPrinterColumns,
    kitchenSkipCategories,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cash_drawer_enabled')) {
      context.handle(
        _cashDrawerEnabledMeta,
        cashDrawerEnabled.isAcceptableOrUnknown(
          data['cash_drawer_enabled']!,
          _cashDrawerEnabledMeta,
        ),
      );
    }
    if (data.containsKey('show_images')) {
      context.handle(
        _showImagesMeta,
        showImages.isAcceptableOrUnknown(data['show_images']!, _showImagesMeta),
      );
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('void_requires_chef')) {
      context.handle(
        _voidRequiresChefMeta,
        voidRequiresChef.isAcceptableOrUnknown(
          data['void_requires_chef']!,
          _voidRequiresChefMeta,
        ),
      );
    }
    if (data.containsKey('receipt_draft')) {
      context.handle(
        _receiptDraftMeta,
        receiptDraft.isAcceptableOrUnknown(
          data['receipt_draft']!,
          _receiptDraftMeta,
        ),
      );
    }
    if (data.containsKey('printer_kind')) {
      context.handle(
        _printerKindMeta,
        printerKind.isAcceptableOrUnknown(
          data['printer_kind']!,
          _printerKindMeta,
        ),
      );
    }
    if (data.containsKey('printer_address')) {
      context.handle(
        _printerAddressMeta,
        printerAddress.isAcceptableOrUnknown(
          data['printer_address']!,
          _printerAddressMeta,
        ),
      );
    }
    if (data.containsKey('printer_name')) {
      context.handle(
        _printerNameMeta,
        printerName.isAcceptableOrUnknown(
          data['printer_name']!,
          _printerNameMeta,
        ),
      );
    }
    if (data.containsKey('printer_columns')) {
      context.handle(
        _printerColumnsMeta,
        printerColumns.isAcceptableOrUnknown(
          data['printer_columns']!,
          _printerColumnsMeta,
        ),
      );
    }
    if (data.containsKey('printer_qr_as_image')) {
      context.handle(
        _printerQrAsImageMeta,
        printerQrAsImage.isAcceptableOrUnknown(
          data['printer_qr_as_image']!,
          _printerQrAsImageMeta,
        ),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('kitchen_mode')) {
      context.handle(
        _kitchenModeMeta,
        kitchenMode.isAcceptableOrUnknown(
          data['kitchen_mode']!,
          _kitchenModeMeta,
        ),
      );
    }
    if (data.containsKey('kitchen_language')) {
      context.handle(
        _kitchenLanguageMeta,
        kitchenLanguage.isAcceptableOrUnknown(
          data['kitchen_language']!,
          _kitchenLanguageMeta,
        ),
      );
    }
    if (data.containsKey('kitchen_printer_kind')) {
      context.handle(
        _kitchenPrinterKindMeta,
        kitchenPrinterKind.isAcceptableOrUnknown(
          data['kitchen_printer_kind']!,
          _kitchenPrinterKindMeta,
        ),
      );
    }
    if (data.containsKey('kitchen_printer_address')) {
      context.handle(
        _kitchenPrinterAddressMeta,
        kitchenPrinterAddress.isAcceptableOrUnknown(
          data['kitchen_printer_address']!,
          _kitchenPrinterAddressMeta,
        ),
      );
    }
    if (data.containsKey('kitchen_printer_name')) {
      context.handle(
        _kitchenPrinterNameMeta,
        kitchenPrinterName.isAcceptableOrUnknown(
          data['kitchen_printer_name']!,
          _kitchenPrinterNameMeta,
        ),
      );
    }
    if (data.containsKey('kitchen_printer_columns')) {
      context.handle(
        _kitchenPrinterColumnsMeta,
        kitchenPrinterColumns.isAcceptableOrUnknown(
          data['kitchen_printer_columns']!,
          _kitchenPrinterColumnsMeta,
        ),
      );
    }
    if (data.containsKey('kitchen_skip_categories')) {
      context.handle(
        _kitchenSkipCategoriesMeta,
        kitchenSkipCategories.isAcceptableOrUnknown(
          data['kitchen_skip_categories']!,
          _kitchenSkipCategoriesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cashDrawerEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}cash_drawer_enabled'],
      )!,
      showImages: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_images'],
      )!,
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      voidRequiresChef: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}void_requires_chef'],
      )!,
      receiptDraft: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_draft'],
      ),
      printerKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}printer_kind'],
      )!,
      printerAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}printer_address'],
      ),
      printerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}printer_name'],
      ),
      printerColumns: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}printer_columns'],
      )!,
      printerQrAsImage: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}printer_qr_as_image'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      kitchenMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kitchen_mode'],
      )!,
      kitchenLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kitchen_language'],
      )!,
      kitchenPrinterKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kitchen_printer_kind'],
      )!,
      kitchenPrinterAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kitchen_printer_address'],
      ),
      kitchenPrinterName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kitchen_printer_name'],
      ),
      kitchenPrinterColumns: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kitchen_printer_columns'],
      )!,
      kitchenSkipCategories: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kitchen_skip_categories'],
      )!,
    );
  }

  @override
  $SettingsRowsTable createAlias(String alias) {
    return $SettingsRowsTable(attachedDatabase, alias);
  }
}

class SettingsRow extends DataClass implements Insertable<SettingsRow> {
  final int id;
  final bool cashDrawerEnabled;
  final bool showImages;
  final String themeMode;
  final bool voidRequiresChef;
  final String? receiptDraft;

  /// `none`, `network`, `usb` oder `bluetooth`.
  final String printerKind;
  final String? printerAddress;
  final String? printerName;
  final int printerColumns;

  /// Den QR-Code als Bild drucken statt mit dem QR-Befehl des Druckers.
  final bool printerQrAsImage;

  /// Kürzel der Sprache der Oberfläche (`de`, `en`, `zh`, `tr`, `ar`).
  final String language;

  /// `off`, `receiptPrinter` oder `kitchenPrinter`.
  final String kitchenMode;
  final String kitchenLanguage;

  /// `none`, `network`, `usb` oder `bluetooth`.
  final String kitchenPrinterKind;
  final String? kitchenPrinterAddress;
  final String? kitchenPrinterName;
  final int kitchenPrinterColumns;

  /// Kategorie-Kennungen, deren Artikel nicht auf den Küchenbon kommen, als
  /// JSON-Liste von Texten.
  final String kitchenSkipCategories;
  const SettingsRow({
    required this.id,
    required this.cashDrawerEnabled,
    required this.showImages,
    required this.themeMode,
    required this.voidRequiresChef,
    this.receiptDraft,
    required this.printerKind,
    this.printerAddress,
    this.printerName,
    required this.printerColumns,
    required this.printerQrAsImage,
    required this.language,
    required this.kitchenMode,
    required this.kitchenLanguage,
    required this.kitchenPrinterKind,
    this.kitchenPrinterAddress,
    this.kitchenPrinterName,
    required this.kitchenPrinterColumns,
    required this.kitchenSkipCategories,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cash_drawer_enabled'] = Variable<bool>(cashDrawerEnabled);
    map['show_images'] = Variable<bool>(showImages);
    map['theme_mode'] = Variable<String>(themeMode);
    map['void_requires_chef'] = Variable<bool>(voidRequiresChef);
    if (!nullToAbsent || receiptDraft != null) {
      map['receipt_draft'] = Variable<String>(receiptDraft);
    }
    map['printer_kind'] = Variable<String>(printerKind);
    if (!nullToAbsent || printerAddress != null) {
      map['printer_address'] = Variable<String>(printerAddress);
    }
    if (!nullToAbsent || printerName != null) {
      map['printer_name'] = Variable<String>(printerName);
    }
    map['printer_columns'] = Variable<int>(printerColumns);
    map['printer_qr_as_image'] = Variable<bool>(printerQrAsImage);
    map['language'] = Variable<String>(language);
    map['kitchen_mode'] = Variable<String>(kitchenMode);
    map['kitchen_language'] = Variable<String>(kitchenLanguage);
    map['kitchen_printer_kind'] = Variable<String>(kitchenPrinterKind);
    if (!nullToAbsent || kitchenPrinterAddress != null) {
      map['kitchen_printer_address'] = Variable<String>(kitchenPrinterAddress);
    }
    if (!nullToAbsent || kitchenPrinterName != null) {
      map['kitchen_printer_name'] = Variable<String>(kitchenPrinterName);
    }
    map['kitchen_printer_columns'] = Variable<int>(kitchenPrinterColumns);
    map['kitchen_skip_categories'] = Variable<String>(kitchenSkipCategories);
    return map;
  }

  SettingsRowsCompanion toCompanion(bool nullToAbsent) {
    return SettingsRowsCompanion(
      id: Value(id),
      cashDrawerEnabled: Value(cashDrawerEnabled),
      showImages: Value(showImages),
      themeMode: Value(themeMode),
      voidRequiresChef: Value(voidRequiresChef),
      receiptDraft: receiptDraft == null && nullToAbsent
          ? const Value.absent()
          : Value(receiptDraft),
      printerKind: Value(printerKind),
      printerAddress: printerAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(printerAddress),
      printerName: printerName == null && nullToAbsent
          ? const Value.absent()
          : Value(printerName),
      printerColumns: Value(printerColumns),
      printerQrAsImage: Value(printerQrAsImage),
      language: Value(language),
      kitchenMode: Value(kitchenMode),
      kitchenLanguage: Value(kitchenLanguage),
      kitchenPrinterKind: Value(kitchenPrinterKind),
      kitchenPrinterAddress: kitchenPrinterAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(kitchenPrinterAddress),
      kitchenPrinterName: kitchenPrinterName == null && nullToAbsent
          ? const Value.absent()
          : Value(kitchenPrinterName),
      kitchenPrinterColumns: Value(kitchenPrinterColumns),
      kitchenSkipCategories: Value(kitchenSkipCategories),
    );
  }

  factory SettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingsRow(
      id: serializer.fromJson<int>(json['id']),
      cashDrawerEnabled: serializer.fromJson<bool>(json['cashDrawerEnabled']),
      showImages: serializer.fromJson<bool>(json['showImages']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      voidRequiresChef: serializer.fromJson<bool>(json['voidRequiresChef']),
      receiptDraft: serializer.fromJson<String?>(json['receiptDraft']),
      printerKind: serializer.fromJson<String>(json['printerKind']),
      printerAddress: serializer.fromJson<String?>(json['printerAddress']),
      printerName: serializer.fromJson<String?>(json['printerName']),
      printerColumns: serializer.fromJson<int>(json['printerColumns']),
      printerQrAsImage: serializer.fromJson<bool>(json['printerQrAsImage']),
      language: serializer.fromJson<String>(json['language']),
      kitchenMode: serializer.fromJson<String>(json['kitchenMode']),
      kitchenLanguage: serializer.fromJson<String>(json['kitchenLanguage']),
      kitchenPrinterKind: serializer.fromJson<String>(
        json['kitchenPrinterKind'],
      ),
      kitchenPrinterAddress: serializer.fromJson<String?>(
        json['kitchenPrinterAddress'],
      ),
      kitchenPrinterName: serializer.fromJson<String?>(
        json['kitchenPrinterName'],
      ),
      kitchenPrinterColumns: serializer.fromJson<int>(
        json['kitchenPrinterColumns'],
      ),
      kitchenSkipCategories: serializer.fromJson<String>(
        json['kitchenSkipCategories'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cashDrawerEnabled': serializer.toJson<bool>(cashDrawerEnabled),
      'showImages': serializer.toJson<bool>(showImages),
      'themeMode': serializer.toJson<String>(themeMode),
      'voidRequiresChef': serializer.toJson<bool>(voidRequiresChef),
      'receiptDraft': serializer.toJson<String?>(receiptDraft),
      'printerKind': serializer.toJson<String>(printerKind),
      'printerAddress': serializer.toJson<String?>(printerAddress),
      'printerName': serializer.toJson<String?>(printerName),
      'printerColumns': serializer.toJson<int>(printerColumns),
      'printerQrAsImage': serializer.toJson<bool>(printerQrAsImage),
      'language': serializer.toJson<String>(language),
      'kitchenMode': serializer.toJson<String>(kitchenMode),
      'kitchenLanguage': serializer.toJson<String>(kitchenLanguage),
      'kitchenPrinterKind': serializer.toJson<String>(kitchenPrinterKind),
      'kitchenPrinterAddress': serializer.toJson<String?>(
        kitchenPrinterAddress,
      ),
      'kitchenPrinterName': serializer.toJson<String?>(kitchenPrinterName),
      'kitchenPrinterColumns': serializer.toJson<int>(kitchenPrinterColumns),
      'kitchenSkipCategories': serializer.toJson<String>(kitchenSkipCategories),
    };
  }

  SettingsRow copyWith({
    int? id,
    bool? cashDrawerEnabled,
    bool? showImages,
    String? themeMode,
    bool? voidRequiresChef,
    Value<String?> receiptDraft = const Value.absent(),
    String? printerKind,
    Value<String?> printerAddress = const Value.absent(),
    Value<String?> printerName = const Value.absent(),
    int? printerColumns,
    bool? printerQrAsImage,
    String? language,
    String? kitchenMode,
    String? kitchenLanguage,
    String? kitchenPrinterKind,
    Value<String?> kitchenPrinterAddress = const Value.absent(),
    Value<String?> kitchenPrinterName = const Value.absent(),
    int? kitchenPrinterColumns,
    String? kitchenSkipCategories,
  }) => SettingsRow(
    id: id ?? this.id,
    cashDrawerEnabled: cashDrawerEnabled ?? this.cashDrawerEnabled,
    showImages: showImages ?? this.showImages,
    themeMode: themeMode ?? this.themeMode,
    voidRequiresChef: voidRequiresChef ?? this.voidRequiresChef,
    receiptDraft: receiptDraft.present ? receiptDraft.value : this.receiptDraft,
    printerKind: printerKind ?? this.printerKind,
    printerAddress: printerAddress.present
        ? printerAddress.value
        : this.printerAddress,
    printerName: printerName.present ? printerName.value : this.printerName,
    printerColumns: printerColumns ?? this.printerColumns,
    printerQrAsImage: printerQrAsImage ?? this.printerQrAsImage,
    language: language ?? this.language,
    kitchenMode: kitchenMode ?? this.kitchenMode,
    kitchenLanguage: kitchenLanguage ?? this.kitchenLanguage,
    kitchenPrinterKind: kitchenPrinterKind ?? this.kitchenPrinterKind,
    kitchenPrinterAddress: kitchenPrinterAddress.present
        ? kitchenPrinterAddress.value
        : this.kitchenPrinterAddress,
    kitchenPrinterName: kitchenPrinterName.present
        ? kitchenPrinterName.value
        : this.kitchenPrinterName,
    kitchenPrinterColumns: kitchenPrinterColumns ?? this.kitchenPrinterColumns,
    kitchenSkipCategories: kitchenSkipCategories ?? this.kitchenSkipCategories,
  );
  SettingsRow copyWithCompanion(SettingsRowsCompanion data) {
    return SettingsRow(
      id: data.id.present ? data.id.value : this.id,
      cashDrawerEnabled: data.cashDrawerEnabled.present
          ? data.cashDrawerEnabled.value
          : this.cashDrawerEnabled,
      showImages: data.showImages.present
          ? data.showImages.value
          : this.showImages,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      voidRequiresChef: data.voidRequiresChef.present
          ? data.voidRequiresChef.value
          : this.voidRequiresChef,
      receiptDraft: data.receiptDraft.present
          ? data.receiptDraft.value
          : this.receiptDraft,
      printerKind: data.printerKind.present
          ? data.printerKind.value
          : this.printerKind,
      printerAddress: data.printerAddress.present
          ? data.printerAddress.value
          : this.printerAddress,
      printerName: data.printerName.present
          ? data.printerName.value
          : this.printerName,
      printerColumns: data.printerColumns.present
          ? data.printerColumns.value
          : this.printerColumns,
      printerQrAsImage: data.printerQrAsImage.present
          ? data.printerQrAsImage.value
          : this.printerQrAsImage,
      language: data.language.present ? data.language.value : this.language,
      kitchenMode: data.kitchenMode.present
          ? data.kitchenMode.value
          : this.kitchenMode,
      kitchenLanguage: data.kitchenLanguage.present
          ? data.kitchenLanguage.value
          : this.kitchenLanguage,
      kitchenPrinterKind: data.kitchenPrinterKind.present
          ? data.kitchenPrinterKind.value
          : this.kitchenPrinterKind,
      kitchenPrinterAddress: data.kitchenPrinterAddress.present
          ? data.kitchenPrinterAddress.value
          : this.kitchenPrinterAddress,
      kitchenPrinterName: data.kitchenPrinterName.present
          ? data.kitchenPrinterName.value
          : this.kitchenPrinterName,
      kitchenPrinterColumns: data.kitchenPrinterColumns.present
          ? data.kitchenPrinterColumns.value
          : this.kitchenPrinterColumns,
      kitchenSkipCategories: data.kitchenSkipCategories.present
          ? data.kitchenSkipCategories.value
          : this.kitchenSkipCategories,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRow(')
          ..write('id: $id, ')
          ..write('cashDrawerEnabled: $cashDrawerEnabled, ')
          ..write('showImages: $showImages, ')
          ..write('themeMode: $themeMode, ')
          ..write('voidRequiresChef: $voidRequiresChef, ')
          ..write('receiptDraft: $receiptDraft, ')
          ..write('printerKind: $printerKind, ')
          ..write('printerAddress: $printerAddress, ')
          ..write('printerName: $printerName, ')
          ..write('printerColumns: $printerColumns, ')
          ..write('printerQrAsImage: $printerQrAsImage, ')
          ..write('language: $language, ')
          ..write('kitchenMode: $kitchenMode, ')
          ..write('kitchenLanguage: $kitchenLanguage, ')
          ..write('kitchenPrinterKind: $kitchenPrinterKind, ')
          ..write('kitchenPrinterAddress: $kitchenPrinterAddress, ')
          ..write('kitchenPrinterName: $kitchenPrinterName, ')
          ..write('kitchenPrinterColumns: $kitchenPrinterColumns, ')
          ..write('kitchenSkipCategories: $kitchenSkipCategories')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cashDrawerEnabled,
    showImages,
    themeMode,
    voidRequiresChef,
    receiptDraft,
    printerKind,
    printerAddress,
    printerName,
    printerColumns,
    printerQrAsImage,
    language,
    kitchenMode,
    kitchenLanguage,
    kitchenPrinterKind,
    kitchenPrinterAddress,
    kitchenPrinterName,
    kitchenPrinterColumns,
    kitchenSkipCategories,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingsRow &&
          other.id == this.id &&
          other.cashDrawerEnabled == this.cashDrawerEnabled &&
          other.showImages == this.showImages &&
          other.themeMode == this.themeMode &&
          other.voidRequiresChef == this.voidRequiresChef &&
          other.receiptDraft == this.receiptDraft &&
          other.printerKind == this.printerKind &&
          other.printerAddress == this.printerAddress &&
          other.printerName == this.printerName &&
          other.printerColumns == this.printerColumns &&
          other.printerQrAsImage == this.printerQrAsImage &&
          other.language == this.language &&
          other.kitchenMode == this.kitchenMode &&
          other.kitchenLanguage == this.kitchenLanguage &&
          other.kitchenPrinterKind == this.kitchenPrinterKind &&
          other.kitchenPrinterAddress == this.kitchenPrinterAddress &&
          other.kitchenPrinterName == this.kitchenPrinterName &&
          other.kitchenPrinterColumns == this.kitchenPrinterColumns &&
          other.kitchenSkipCategories == this.kitchenSkipCategories);
}

class SettingsRowsCompanion extends UpdateCompanion<SettingsRow> {
  final Value<int> id;
  final Value<bool> cashDrawerEnabled;
  final Value<bool> showImages;
  final Value<String> themeMode;
  final Value<bool> voidRequiresChef;
  final Value<String?> receiptDraft;
  final Value<String> printerKind;
  final Value<String?> printerAddress;
  final Value<String?> printerName;
  final Value<int> printerColumns;
  final Value<bool> printerQrAsImage;
  final Value<String> language;
  final Value<String> kitchenMode;
  final Value<String> kitchenLanguage;
  final Value<String> kitchenPrinterKind;
  final Value<String?> kitchenPrinterAddress;
  final Value<String?> kitchenPrinterName;
  final Value<int> kitchenPrinterColumns;
  final Value<String> kitchenSkipCategories;
  const SettingsRowsCompanion({
    this.id = const Value.absent(),
    this.cashDrawerEnabled = const Value.absent(),
    this.showImages = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.voidRequiresChef = const Value.absent(),
    this.receiptDraft = const Value.absent(),
    this.printerKind = const Value.absent(),
    this.printerAddress = const Value.absent(),
    this.printerName = const Value.absent(),
    this.printerColumns = const Value.absent(),
    this.printerQrAsImage = const Value.absent(),
    this.language = const Value.absent(),
    this.kitchenMode = const Value.absent(),
    this.kitchenLanguage = const Value.absent(),
    this.kitchenPrinterKind = const Value.absent(),
    this.kitchenPrinterAddress = const Value.absent(),
    this.kitchenPrinterName = const Value.absent(),
    this.kitchenPrinterColumns = const Value.absent(),
    this.kitchenSkipCategories = const Value.absent(),
  });
  SettingsRowsCompanion.insert({
    this.id = const Value.absent(),
    this.cashDrawerEnabled = const Value.absent(),
    this.showImages = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.voidRequiresChef = const Value.absent(),
    this.receiptDraft = const Value.absent(),
    this.printerKind = const Value.absent(),
    this.printerAddress = const Value.absent(),
    this.printerName = const Value.absent(),
    this.printerColumns = const Value.absent(),
    this.printerQrAsImage = const Value.absent(),
    this.language = const Value.absent(),
    this.kitchenMode = const Value.absent(),
    this.kitchenLanguage = const Value.absent(),
    this.kitchenPrinterKind = const Value.absent(),
    this.kitchenPrinterAddress = const Value.absent(),
    this.kitchenPrinterName = const Value.absent(),
    this.kitchenPrinterColumns = const Value.absent(),
    this.kitchenSkipCategories = const Value.absent(),
  });
  static Insertable<SettingsRow> custom({
    Expression<int>? id,
    Expression<bool>? cashDrawerEnabled,
    Expression<bool>? showImages,
    Expression<String>? themeMode,
    Expression<bool>? voidRequiresChef,
    Expression<String>? receiptDraft,
    Expression<String>? printerKind,
    Expression<String>? printerAddress,
    Expression<String>? printerName,
    Expression<int>? printerColumns,
    Expression<bool>? printerQrAsImage,
    Expression<String>? language,
    Expression<String>? kitchenMode,
    Expression<String>? kitchenLanguage,
    Expression<String>? kitchenPrinterKind,
    Expression<String>? kitchenPrinterAddress,
    Expression<String>? kitchenPrinterName,
    Expression<int>? kitchenPrinterColumns,
    Expression<String>? kitchenSkipCategories,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cashDrawerEnabled != null) 'cash_drawer_enabled': cashDrawerEnabled,
      if (showImages != null) 'show_images': showImages,
      if (themeMode != null) 'theme_mode': themeMode,
      if (voidRequiresChef != null) 'void_requires_chef': voidRequiresChef,
      if (receiptDraft != null) 'receipt_draft': receiptDraft,
      if (printerKind != null) 'printer_kind': printerKind,
      if (printerAddress != null) 'printer_address': printerAddress,
      if (printerName != null) 'printer_name': printerName,
      if (printerColumns != null) 'printer_columns': printerColumns,
      if (printerQrAsImage != null) 'printer_qr_as_image': printerQrAsImage,
      if (language != null) 'language': language,
      if (kitchenMode != null) 'kitchen_mode': kitchenMode,
      if (kitchenLanguage != null) 'kitchen_language': kitchenLanguage,
      if (kitchenPrinterKind != null)
        'kitchen_printer_kind': kitchenPrinterKind,
      if (kitchenPrinterAddress != null)
        'kitchen_printer_address': kitchenPrinterAddress,
      if (kitchenPrinterName != null)
        'kitchen_printer_name': kitchenPrinterName,
      if (kitchenPrinterColumns != null)
        'kitchen_printer_columns': kitchenPrinterColumns,
      if (kitchenSkipCategories != null)
        'kitchen_skip_categories': kitchenSkipCategories,
    });
  }

  SettingsRowsCompanion copyWith({
    Value<int>? id,
    Value<bool>? cashDrawerEnabled,
    Value<bool>? showImages,
    Value<String>? themeMode,
    Value<bool>? voidRequiresChef,
    Value<String?>? receiptDraft,
    Value<String>? printerKind,
    Value<String?>? printerAddress,
    Value<String?>? printerName,
    Value<int>? printerColumns,
    Value<bool>? printerQrAsImage,
    Value<String>? language,
    Value<String>? kitchenMode,
    Value<String>? kitchenLanguage,
    Value<String>? kitchenPrinterKind,
    Value<String?>? kitchenPrinterAddress,
    Value<String?>? kitchenPrinterName,
    Value<int>? kitchenPrinterColumns,
    Value<String>? kitchenSkipCategories,
  }) {
    return SettingsRowsCompanion(
      id: id ?? this.id,
      cashDrawerEnabled: cashDrawerEnabled ?? this.cashDrawerEnabled,
      showImages: showImages ?? this.showImages,
      themeMode: themeMode ?? this.themeMode,
      voidRequiresChef: voidRequiresChef ?? this.voidRequiresChef,
      receiptDraft: receiptDraft ?? this.receiptDraft,
      printerKind: printerKind ?? this.printerKind,
      printerAddress: printerAddress ?? this.printerAddress,
      printerName: printerName ?? this.printerName,
      printerColumns: printerColumns ?? this.printerColumns,
      printerQrAsImage: printerQrAsImage ?? this.printerQrAsImage,
      language: language ?? this.language,
      kitchenMode: kitchenMode ?? this.kitchenMode,
      kitchenLanguage: kitchenLanguage ?? this.kitchenLanguage,
      kitchenPrinterKind: kitchenPrinterKind ?? this.kitchenPrinterKind,
      kitchenPrinterAddress:
          kitchenPrinterAddress ?? this.kitchenPrinterAddress,
      kitchenPrinterName: kitchenPrinterName ?? this.kitchenPrinterName,
      kitchenPrinterColumns:
          kitchenPrinterColumns ?? this.kitchenPrinterColumns,
      kitchenSkipCategories:
          kitchenSkipCategories ?? this.kitchenSkipCategories,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cashDrawerEnabled.present) {
      map['cash_drawer_enabled'] = Variable<bool>(cashDrawerEnabled.value);
    }
    if (showImages.present) {
      map['show_images'] = Variable<bool>(showImages.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (voidRequiresChef.present) {
      map['void_requires_chef'] = Variable<bool>(voidRequiresChef.value);
    }
    if (receiptDraft.present) {
      map['receipt_draft'] = Variable<String>(receiptDraft.value);
    }
    if (printerKind.present) {
      map['printer_kind'] = Variable<String>(printerKind.value);
    }
    if (printerAddress.present) {
      map['printer_address'] = Variable<String>(printerAddress.value);
    }
    if (printerName.present) {
      map['printer_name'] = Variable<String>(printerName.value);
    }
    if (printerColumns.present) {
      map['printer_columns'] = Variable<int>(printerColumns.value);
    }
    if (printerQrAsImage.present) {
      map['printer_qr_as_image'] = Variable<bool>(printerQrAsImage.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (kitchenMode.present) {
      map['kitchen_mode'] = Variable<String>(kitchenMode.value);
    }
    if (kitchenLanguage.present) {
      map['kitchen_language'] = Variable<String>(kitchenLanguage.value);
    }
    if (kitchenPrinterKind.present) {
      map['kitchen_printer_kind'] = Variable<String>(kitchenPrinterKind.value);
    }
    if (kitchenPrinterAddress.present) {
      map['kitchen_printer_address'] = Variable<String>(
        kitchenPrinterAddress.value,
      );
    }
    if (kitchenPrinterName.present) {
      map['kitchen_printer_name'] = Variable<String>(kitchenPrinterName.value);
    }
    if (kitchenPrinterColumns.present) {
      map['kitchen_printer_columns'] = Variable<int>(
        kitchenPrinterColumns.value,
      );
    }
    if (kitchenSkipCategories.present) {
      map['kitchen_skip_categories'] = Variable<String>(
        kitchenSkipCategories.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsRowsCompanion(')
          ..write('id: $id, ')
          ..write('cashDrawerEnabled: $cashDrawerEnabled, ')
          ..write('showImages: $showImages, ')
          ..write('themeMode: $themeMode, ')
          ..write('voidRequiresChef: $voidRequiresChef, ')
          ..write('receiptDraft: $receiptDraft, ')
          ..write('printerKind: $printerKind, ')
          ..write('printerAddress: $printerAddress, ')
          ..write('printerName: $printerName, ')
          ..write('printerColumns: $printerColumns, ')
          ..write('printerQrAsImage: $printerQrAsImage, ')
          ..write('language: $language, ')
          ..write('kitchenMode: $kitchenMode, ')
          ..write('kitchenLanguage: $kitchenLanguage, ')
          ..write('kitchenPrinterKind: $kitchenPrinterKind, ')
          ..write('kitchenPrinterAddress: $kitchenPrinterAddress, ')
          ..write('kitchenPrinterName: $kitchenPrinterName, ')
          ..write('kitchenPrinterColumns: $kitchenPrinterColumns, ')
          ..write('kitchenSkipCategories: $kitchenSkipCategories')
          ..write(')'))
        .toString();
  }
}

class $TranslationRowsTable extends TranslationRows
    with TableInfo<$TranslationRowsTable, TranslationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranslationRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valuesJsonMeta = const VerificationMeta(
    'valuesJson',
  );
  @override
  late final GeneratedColumn<String> valuesJson = GeneratedColumn<String>(
    'values_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [source, valuesJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'translations';
  @override
  VerificationContext validateIntegrity(
    Insertable<TranslationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('values_json')) {
      context.handle(
        _valuesJsonMeta,
        valuesJson.isAcceptableOrUnknown(data['values_json']!, _valuesJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valuesJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {source};
  @override
  TranslationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranslationRow(
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      valuesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}values_json'],
      )!,
    );
  }

  @override
  $TranslationRowsTable createAlias(String alias) {
    return $TranslationRowsTable(attachedDatabase, alias);
  }
}

class TranslationRow extends DataClass implements Insertable<TranslationRow> {
  final String source;
  final String valuesJson;
  const TranslationRow({required this.source, required this.valuesJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source'] = Variable<String>(source);
    map['values_json'] = Variable<String>(valuesJson);
    return map;
  }

  TranslationRowsCompanion toCompanion(bool nullToAbsent) {
    return TranslationRowsCompanion(
      source: Value(source),
      valuesJson: Value(valuesJson),
    );
  }

  factory TranslationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranslationRow(
      source: serializer.fromJson<String>(json['source']),
      valuesJson: serializer.fromJson<String>(json['valuesJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'source': serializer.toJson<String>(source),
      'valuesJson': serializer.toJson<String>(valuesJson),
    };
  }

  TranslationRow copyWith({String? source, String? valuesJson}) =>
      TranslationRow(
        source: source ?? this.source,
        valuesJson: valuesJson ?? this.valuesJson,
      );
  TranslationRow copyWithCompanion(TranslationRowsCompanion data) {
    return TranslationRow(
      source: data.source.present ? data.source.value : this.source,
      valuesJson: data.valuesJson.present
          ? data.valuesJson.value
          : this.valuesJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranslationRow(')
          ..write('source: $source, ')
          ..write('valuesJson: $valuesJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(source, valuesJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranslationRow &&
          other.source == this.source &&
          other.valuesJson == this.valuesJson);
}

class TranslationRowsCompanion extends UpdateCompanion<TranslationRow> {
  final Value<String> source;
  final Value<String> valuesJson;
  final Value<int> rowid;
  const TranslationRowsCompanion({
    this.source = const Value.absent(),
    this.valuesJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranslationRowsCompanion.insert({
    required String source,
    required String valuesJson,
    this.rowid = const Value.absent(),
  }) : source = Value(source),
       valuesJson = Value(valuesJson);
  static Insertable<TranslationRow> custom({
    Expression<String>? source,
    Expression<String>? valuesJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (source != null) 'source': source,
      if (valuesJson != null) 'values_json': valuesJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranslationRowsCompanion copyWith({
    Value<String>? source,
    Value<String>? valuesJson,
    Value<int>? rowid,
  }) {
    return TranslationRowsCompanion(
      source: source ?? this.source,
      valuesJson: valuesJson ?? this.valuesJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (valuesJson.present) {
      map['values_json'] = Variable<String>(valuesJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranslationRowsCompanion(')
          ..write('source: $source, ')
          ..write('valuesJson: $valuesJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BusinessDayRowsTable extends BusinessDayRows
    with TableInfo<$BusinessDayRowsTable, BusinessDayRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BusinessDayRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openedAtMeta = const VerificationMeta(
    'openedAt',
  );
  @override
  late final GeneratedColumn<DateTime> openedAt = GeneratedColumn<DateTime>(
    'opened_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _closedAtMeta = const VerificationMeta(
    'closedAt',
  );
  @override
  late final GeneratedColumn<DateTime> closedAt = GeneratedColumn<DateTime>(
    'closed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _openingFloatCentsMeta = const VerificationMeta(
    'openingFloatCents',
  );
  @override
  late final GeneratedColumn<int> openingFloatCents = GeneratedColumn<int>(
    'opening_float_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countedCentsMeta = const VerificationMeta(
    'countedCents',
  );
  @override
  late final GeneratedColumn<int> countedCents = GeneratedColumn<int>(
    'counted_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leftInDrawerCentsMeta = const VerificationMeta(
    'leftInDrawerCents',
  );
  @override
  late final GeneratedColumn<int> leftInDrawerCents = GeneratedColumn<int>(
    'left_in_drawer_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expectedCentsMeta = const VerificationMeta(
    'expectedCents',
  );
  @override
  late final GeneratedColumn<int> expectedCents = GeneratedColumn<int>(
    'expected_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _differenceCentsMeta = const VerificationMeta(
    'differenceCents',
  );
  @override
  late final GeneratedColumn<int> differenceCents = GeneratedColumn<int>(
    'difference_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _closedByNameMeta = const VerificationMeta(
    'closedByName',
  );
  @override
  late final GeneratedColumn<String> closedByName = GeneratedColumn<String>(
    'closed_by_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    openedAt,
    closedAt,
    openingFloatCents,
    countedCents,
    leftInDrawerCents,
    expectedCents,
    differenceCents,
    closedByName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'business_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<BusinessDayRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('opened_at')) {
      context.handle(
        _openedAtMeta,
        openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_openedAtMeta);
    }
    if (data.containsKey('closed_at')) {
      context.handle(
        _closedAtMeta,
        closedAt.isAcceptableOrUnknown(data['closed_at']!, _closedAtMeta),
      );
    }
    if (data.containsKey('opening_float_cents')) {
      context.handle(
        _openingFloatCentsMeta,
        openingFloatCents.isAcceptableOrUnknown(
          data['opening_float_cents']!,
          _openingFloatCentsMeta,
        ),
      );
    }
    if (data.containsKey('counted_cents')) {
      context.handle(
        _countedCentsMeta,
        countedCents.isAcceptableOrUnknown(
          data['counted_cents']!,
          _countedCentsMeta,
        ),
      );
    }
    if (data.containsKey('left_in_drawer_cents')) {
      context.handle(
        _leftInDrawerCentsMeta,
        leftInDrawerCents.isAcceptableOrUnknown(
          data['left_in_drawer_cents']!,
          _leftInDrawerCentsMeta,
        ),
      );
    }
    if (data.containsKey('expected_cents')) {
      context.handle(
        _expectedCentsMeta,
        expectedCents.isAcceptableOrUnknown(
          data['expected_cents']!,
          _expectedCentsMeta,
        ),
      );
    }
    if (data.containsKey('difference_cents')) {
      context.handle(
        _differenceCentsMeta,
        differenceCents.isAcceptableOrUnknown(
          data['difference_cents']!,
          _differenceCentsMeta,
        ),
      );
    }
    if (data.containsKey('closed_by_name')) {
      context.handle(
        _closedByNameMeta,
        closedByName.isAcceptableOrUnknown(
          data['closed_by_name']!,
          _closedByNameMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BusinessDayRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BusinessDayRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      openedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}opened_at'],
      )!,
      closedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}closed_at'],
      ),
      openingFloatCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opening_float_cents'],
      ),
      countedCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}counted_cents'],
      ),
      leftInDrawerCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}left_in_drawer_cents'],
      ),
      expectedCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_cents'],
      ),
      differenceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}difference_cents'],
      ),
      closedByName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}closed_by_name'],
      ),
    );
  }

  @override
  $BusinessDayRowsTable createAlias(String alias) {
    return $BusinessDayRowsTable(attachedDatabase, alias);
  }
}

class BusinessDayRow extends DataClass implements Insertable<BusinessDayRow> {
  final String id;
  final DateTime openedAt;
  final DateTime? closedAt;

  /// `null`, solange das Wechselgeld des Tages nicht bekannt ist.
  final int? openingFloatCents;
  final int? countedCents;
  final int? leftInDrawerCents;
  final int? expectedCents;
  final int? differenceCents;
  final String? closedByName;
  const BusinessDayRow({
    required this.id,
    required this.openedAt,
    this.closedAt,
    this.openingFloatCents,
    this.countedCents,
    this.leftInDrawerCents,
    this.expectedCents,
    this.differenceCents,
    this.closedByName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['opened_at'] = Variable<DateTime>(openedAt);
    if (!nullToAbsent || closedAt != null) {
      map['closed_at'] = Variable<DateTime>(closedAt);
    }
    if (!nullToAbsent || openingFloatCents != null) {
      map['opening_float_cents'] = Variable<int>(openingFloatCents);
    }
    if (!nullToAbsent || countedCents != null) {
      map['counted_cents'] = Variable<int>(countedCents);
    }
    if (!nullToAbsent || leftInDrawerCents != null) {
      map['left_in_drawer_cents'] = Variable<int>(leftInDrawerCents);
    }
    if (!nullToAbsent || expectedCents != null) {
      map['expected_cents'] = Variable<int>(expectedCents);
    }
    if (!nullToAbsent || differenceCents != null) {
      map['difference_cents'] = Variable<int>(differenceCents);
    }
    if (!nullToAbsent || closedByName != null) {
      map['closed_by_name'] = Variable<String>(closedByName);
    }
    return map;
  }

  BusinessDayRowsCompanion toCompanion(bool nullToAbsent) {
    return BusinessDayRowsCompanion(
      id: Value(id),
      openedAt: Value(openedAt),
      closedAt: closedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAt),
      openingFloatCents: openingFloatCents == null && nullToAbsent
          ? const Value.absent()
          : Value(openingFloatCents),
      countedCents: countedCents == null && nullToAbsent
          ? const Value.absent()
          : Value(countedCents),
      leftInDrawerCents: leftInDrawerCents == null && nullToAbsent
          ? const Value.absent()
          : Value(leftInDrawerCents),
      expectedCents: expectedCents == null && nullToAbsent
          ? const Value.absent()
          : Value(expectedCents),
      differenceCents: differenceCents == null && nullToAbsent
          ? const Value.absent()
          : Value(differenceCents),
      closedByName: closedByName == null && nullToAbsent
          ? const Value.absent()
          : Value(closedByName),
    );
  }

  factory BusinessDayRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BusinessDayRow(
      id: serializer.fromJson<String>(json['id']),
      openedAt: serializer.fromJson<DateTime>(json['openedAt']),
      closedAt: serializer.fromJson<DateTime?>(json['closedAt']),
      openingFloatCents: serializer.fromJson<int?>(json['openingFloatCents']),
      countedCents: serializer.fromJson<int?>(json['countedCents']),
      leftInDrawerCents: serializer.fromJson<int?>(json['leftInDrawerCents']),
      expectedCents: serializer.fromJson<int?>(json['expectedCents']),
      differenceCents: serializer.fromJson<int?>(json['differenceCents']),
      closedByName: serializer.fromJson<String?>(json['closedByName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'openedAt': serializer.toJson<DateTime>(openedAt),
      'closedAt': serializer.toJson<DateTime?>(closedAt),
      'openingFloatCents': serializer.toJson<int?>(openingFloatCents),
      'countedCents': serializer.toJson<int?>(countedCents),
      'leftInDrawerCents': serializer.toJson<int?>(leftInDrawerCents),
      'expectedCents': serializer.toJson<int?>(expectedCents),
      'differenceCents': serializer.toJson<int?>(differenceCents),
      'closedByName': serializer.toJson<String?>(closedByName),
    };
  }

  BusinessDayRow copyWith({
    String? id,
    DateTime? openedAt,
    Value<DateTime?> closedAt = const Value.absent(),
    Value<int?> openingFloatCents = const Value.absent(),
    Value<int?> countedCents = const Value.absent(),
    Value<int?> leftInDrawerCents = const Value.absent(),
    Value<int?> expectedCents = const Value.absent(),
    Value<int?> differenceCents = const Value.absent(),
    Value<String?> closedByName = const Value.absent(),
  }) => BusinessDayRow(
    id: id ?? this.id,
    openedAt: openedAt ?? this.openedAt,
    closedAt: closedAt.present ? closedAt.value : this.closedAt,
    openingFloatCents: openingFloatCents.present
        ? openingFloatCents.value
        : this.openingFloatCents,
    countedCents: countedCents.present ? countedCents.value : this.countedCents,
    leftInDrawerCents: leftInDrawerCents.present
        ? leftInDrawerCents.value
        : this.leftInDrawerCents,
    expectedCents: expectedCents.present
        ? expectedCents.value
        : this.expectedCents,
    differenceCents: differenceCents.present
        ? differenceCents.value
        : this.differenceCents,
    closedByName: closedByName.present ? closedByName.value : this.closedByName,
  );
  BusinessDayRow copyWithCompanion(BusinessDayRowsCompanion data) {
    return BusinessDayRow(
      id: data.id.present ? data.id.value : this.id,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
      openingFloatCents: data.openingFloatCents.present
          ? data.openingFloatCents.value
          : this.openingFloatCents,
      countedCents: data.countedCents.present
          ? data.countedCents.value
          : this.countedCents,
      leftInDrawerCents: data.leftInDrawerCents.present
          ? data.leftInDrawerCents.value
          : this.leftInDrawerCents,
      expectedCents: data.expectedCents.present
          ? data.expectedCents.value
          : this.expectedCents,
      differenceCents: data.differenceCents.present
          ? data.differenceCents.value
          : this.differenceCents,
      closedByName: data.closedByName.present
          ? data.closedByName.value
          : this.closedByName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BusinessDayRow(')
          ..write('id: $id, ')
          ..write('openedAt: $openedAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('openingFloatCents: $openingFloatCents, ')
          ..write('countedCents: $countedCents, ')
          ..write('leftInDrawerCents: $leftInDrawerCents, ')
          ..write('expectedCents: $expectedCents, ')
          ..write('differenceCents: $differenceCents, ')
          ..write('closedByName: $closedByName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    openedAt,
    closedAt,
    openingFloatCents,
    countedCents,
    leftInDrawerCents,
    expectedCents,
    differenceCents,
    closedByName,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BusinessDayRow &&
          other.id == this.id &&
          other.openedAt == this.openedAt &&
          other.closedAt == this.closedAt &&
          other.openingFloatCents == this.openingFloatCents &&
          other.countedCents == this.countedCents &&
          other.leftInDrawerCents == this.leftInDrawerCents &&
          other.expectedCents == this.expectedCents &&
          other.differenceCents == this.differenceCents &&
          other.closedByName == this.closedByName);
}

class BusinessDayRowsCompanion extends UpdateCompanion<BusinessDayRow> {
  final Value<String> id;
  final Value<DateTime> openedAt;
  final Value<DateTime?> closedAt;
  final Value<int?> openingFloatCents;
  final Value<int?> countedCents;
  final Value<int?> leftInDrawerCents;
  final Value<int?> expectedCents;
  final Value<int?> differenceCents;
  final Value<String?> closedByName;
  final Value<int> rowid;
  const BusinessDayRowsCompanion({
    this.id = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.openingFloatCents = const Value.absent(),
    this.countedCents = const Value.absent(),
    this.leftInDrawerCents = const Value.absent(),
    this.expectedCents = const Value.absent(),
    this.differenceCents = const Value.absent(),
    this.closedByName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BusinessDayRowsCompanion.insert({
    required String id,
    required DateTime openedAt,
    this.closedAt = const Value.absent(),
    this.openingFloatCents = const Value.absent(),
    this.countedCents = const Value.absent(),
    this.leftInDrawerCents = const Value.absent(),
    this.expectedCents = const Value.absent(),
    this.differenceCents = const Value.absent(),
    this.closedByName = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       openedAt = Value(openedAt);
  static Insertable<BusinessDayRow> custom({
    Expression<String>? id,
    Expression<DateTime>? openedAt,
    Expression<DateTime>? closedAt,
    Expression<int>? openingFloatCents,
    Expression<int>? countedCents,
    Expression<int>? leftInDrawerCents,
    Expression<int>? expectedCents,
    Expression<int>? differenceCents,
    Expression<String>? closedByName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (openedAt != null) 'opened_at': openedAt,
      if (closedAt != null) 'closed_at': closedAt,
      if (openingFloatCents != null) 'opening_float_cents': openingFloatCents,
      if (countedCents != null) 'counted_cents': countedCents,
      if (leftInDrawerCents != null) 'left_in_drawer_cents': leftInDrawerCents,
      if (expectedCents != null) 'expected_cents': expectedCents,
      if (differenceCents != null) 'difference_cents': differenceCents,
      if (closedByName != null) 'closed_by_name': closedByName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BusinessDayRowsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? openedAt,
    Value<DateTime?>? closedAt,
    Value<int?>? openingFloatCents,
    Value<int?>? countedCents,
    Value<int?>? leftInDrawerCents,
    Value<int?>? expectedCents,
    Value<int?>? differenceCents,
    Value<String?>? closedByName,
    Value<int>? rowid,
  }) {
    return BusinessDayRowsCompanion(
      id: id ?? this.id,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      openingFloatCents: openingFloatCents ?? this.openingFloatCents,
      countedCents: countedCents ?? this.countedCents,
      leftInDrawerCents: leftInDrawerCents ?? this.leftInDrawerCents,
      expectedCents: expectedCents ?? this.expectedCents,
      differenceCents: differenceCents ?? this.differenceCents,
      closedByName: closedByName ?? this.closedByName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<DateTime>(openedAt.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<DateTime>(closedAt.value);
    }
    if (openingFloatCents.present) {
      map['opening_float_cents'] = Variable<int>(openingFloatCents.value);
    }
    if (countedCents.present) {
      map['counted_cents'] = Variable<int>(countedCents.value);
    }
    if (leftInDrawerCents.present) {
      map['left_in_drawer_cents'] = Variable<int>(leftInDrawerCents.value);
    }
    if (expectedCents.present) {
      map['expected_cents'] = Variable<int>(expectedCents.value);
    }
    if (differenceCents.present) {
      map['difference_cents'] = Variable<int>(differenceCents.value);
    }
    if (closedByName.present) {
      map['closed_by_name'] = Variable<String>(closedByName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BusinessDayRowsCompanion(')
          ..write('id: $id, ')
          ..write('openedAt: $openedAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('openingFloatCents: $openingFloatCents, ')
          ..write('countedCents: $countedCents, ')
          ..write('leftInDrawerCents: $leftInDrawerCents, ')
          ..write('expectedCents: $expectedCents, ')
          ..write('differenceCents: $differenceCents, ')
          ..write('closedByName: $closedByName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CashMovementRowsTable extends CashMovementRows
    with TableInfo<$CashMovementRowsTable, CashMovementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CashMovementRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessDayIdMeta = const VerificationMeta(
    'businessDayId',
  );
  @override
  late final GeneratedColumn<String> businessDayId = GeneratedColumn<String>(
    'business_day_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES business_days (id)',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _staffIdMeta = const VerificationMeta(
    'staffId',
  );
  @override
  late final GeneratedColumn<String> staffId = GeneratedColumn<String>(
    'staff_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _staffNameMeta = const VerificationMeta(
    'staffName',
  );
  @override
  late final GeneratedColumn<String> staffName = GeneratedColumn<String>(
    'staff_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    businessDayId,
    kind,
    amountCents,
    reason,
    createdAt,
    staffId,
    staffName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cash_movements';
  @override
  VerificationContext validateIntegrity(
    Insertable<CashMovementRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('business_day_id')) {
      context.handle(
        _businessDayIdMeta,
        businessDayId.isAcceptableOrUnknown(
          data['business_day_id']!,
          _businessDayIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_businessDayIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('staff_id')) {
      context.handle(
        _staffIdMeta,
        staffId.isAcceptableOrUnknown(data['staff_id']!, _staffIdMeta),
      );
    } else if (isInserting) {
      context.missing(_staffIdMeta);
    }
    if (data.containsKey('staff_name')) {
      context.handle(
        _staffNameMeta,
        staffName.isAcceptableOrUnknown(data['staff_name']!, _staffNameMeta),
      );
    } else if (isInserting) {
      context.missing(_staffNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CashMovementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CashMovementRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      businessDayId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_day_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      staffId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}staff_id'],
      )!,
      staffName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}staff_name'],
      )!,
    );
  }

  @override
  $CashMovementRowsTable createAlias(String alias) {
    return $CashMovementRowsTable(attachedDatabase, alias);
  }
}

class CashMovementRow extends DataClass implements Insertable<CashMovementRow> {
  final String id;
  final String businessDayId;

  /// `deposit` oder `withdrawal`.
  final String kind;
  final int amountCents;

  /// `bank`, `purchase`, `change` oder `other`.
  final String reason;
  final DateTime createdAt;
  final String staffId;
  final String staffName;
  const CashMovementRow({
    required this.id,
    required this.businessDayId,
    required this.kind,
    required this.amountCents,
    required this.reason,
    required this.createdAt,
    required this.staffId,
    required this.staffName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['business_day_id'] = Variable<String>(businessDayId);
    map['kind'] = Variable<String>(kind);
    map['amount_cents'] = Variable<int>(amountCents);
    map['reason'] = Variable<String>(reason);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['staff_id'] = Variable<String>(staffId);
    map['staff_name'] = Variable<String>(staffName);
    return map;
  }

  CashMovementRowsCompanion toCompanion(bool nullToAbsent) {
    return CashMovementRowsCompanion(
      id: Value(id),
      businessDayId: Value(businessDayId),
      kind: Value(kind),
      amountCents: Value(amountCents),
      reason: Value(reason),
      createdAt: Value(createdAt),
      staffId: Value(staffId),
      staffName: Value(staffName),
    );
  }

  factory CashMovementRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CashMovementRow(
      id: serializer.fromJson<String>(json['id']),
      businessDayId: serializer.fromJson<String>(json['businessDayId']),
      kind: serializer.fromJson<String>(json['kind']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      reason: serializer.fromJson<String>(json['reason']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      staffId: serializer.fromJson<String>(json['staffId']),
      staffName: serializer.fromJson<String>(json['staffName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'businessDayId': serializer.toJson<String>(businessDayId),
      'kind': serializer.toJson<String>(kind),
      'amountCents': serializer.toJson<int>(amountCents),
      'reason': serializer.toJson<String>(reason),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'staffId': serializer.toJson<String>(staffId),
      'staffName': serializer.toJson<String>(staffName),
    };
  }

  CashMovementRow copyWith({
    String? id,
    String? businessDayId,
    String? kind,
    int? amountCents,
    String? reason,
    DateTime? createdAt,
    String? staffId,
    String? staffName,
  }) => CashMovementRow(
    id: id ?? this.id,
    businessDayId: businessDayId ?? this.businessDayId,
    kind: kind ?? this.kind,
    amountCents: amountCents ?? this.amountCents,
    reason: reason ?? this.reason,
    createdAt: createdAt ?? this.createdAt,
    staffId: staffId ?? this.staffId,
    staffName: staffName ?? this.staffName,
  );
  CashMovementRow copyWithCompanion(CashMovementRowsCompanion data) {
    return CashMovementRow(
      id: data.id.present ? data.id.value : this.id,
      businessDayId: data.businessDayId.present
          ? data.businessDayId.value
          : this.businessDayId,
      kind: data.kind.present ? data.kind.value : this.kind,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      reason: data.reason.present ? data.reason.value : this.reason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      staffId: data.staffId.present ? data.staffId.value : this.staffId,
      staffName: data.staffName.present ? data.staffName.value : this.staffName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CashMovementRow(')
          ..write('id: $id, ')
          ..write('businessDayId: $businessDayId, ')
          ..write('kind: $kind, ')
          ..write('amountCents: $amountCents, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt, ')
          ..write('staffId: $staffId, ')
          ..write('staffName: $staffName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    businessDayId,
    kind,
    amountCents,
    reason,
    createdAt,
    staffId,
    staffName,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CashMovementRow &&
          other.id == this.id &&
          other.businessDayId == this.businessDayId &&
          other.kind == this.kind &&
          other.amountCents == this.amountCents &&
          other.reason == this.reason &&
          other.createdAt == this.createdAt &&
          other.staffId == this.staffId &&
          other.staffName == this.staffName);
}

class CashMovementRowsCompanion extends UpdateCompanion<CashMovementRow> {
  final Value<String> id;
  final Value<String> businessDayId;
  final Value<String> kind;
  final Value<int> amountCents;
  final Value<String> reason;
  final Value<DateTime> createdAt;
  final Value<String> staffId;
  final Value<String> staffName;
  final Value<int> rowid;
  const CashMovementRowsCompanion({
    this.id = const Value.absent(),
    this.businessDayId = const Value.absent(),
    this.kind = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.reason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.staffId = const Value.absent(),
    this.staffName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CashMovementRowsCompanion.insert({
    required String id,
    required String businessDayId,
    required String kind,
    required int amountCents,
    required String reason,
    required DateTime createdAt,
    required String staffId,
    required String staffName,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       businessDayId = Value(businessDayId),
       kind = Value(kind),
       amountCents = Value(amountCents),
       reason = Value(reason),
       createdAt = Value(createdAt),
       staffId = Value(staffId),
       staffName = Value(staffName);
  static Insertable<CashMovementRow> custom({
    Expression<String>? id,
    Expression<String>? businessDayId,
    Expression<String>? kind,
    Expression<int>? amountCents,
    Expression<String>? reason,
    Expression<DateTime>? createdAt,
    Expression<String>? staffId,
    Expression<String>? staffName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (businessDayId != null) 'business_day_id': businessDayId,
      if (kind != null) 'kind': kind,
      if (amountCents != null) 'amount_cents': amountCents,
      if (reason != null) 'reason': reason,
      if (createdAt != null) 'created_at': createdAt,
      if (staffId != null) 'staff_id': staffId,
      if (staffName != null) 'staff_name': staffName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CashMovementRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? businessDayId,
    Value<String>? kind,
    Value<int>? amountCents,
    Value<String>? reason,
    Value<DateTime>? createdAt,
    Value<String>? staffId,
    Value<String>? staffName,
    Value<int>? rowid,
  }) {
    return CashMovementRowsCompanion(
      id: id ?? this.id,
      businessDayId: businessDayId ?? this.businessDayId,
      kind: kind ?? this.kind,
      amountCents: amountCents ?? this.amountCents,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (businessDayId.present) {
      map['business_day_id'] = Variable<String>(businessDayId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (staffId.present) {
      map['staff_id'] = Variable<String>(staffId.value);
    }
    if (staffName.present) {
      map['staff_name'] = Variable<String>(staffName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CashMovementRowsCompanion(')
          ..write('id: $id, ')
          ..write('businessDayId: $businessDayId, ')
          ..write('kind: $kind, ')
          ..write('amountCents: $amountCents, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt, ')
          ..write('staffId: $staffId, ')
          ..write('staffName: $staffName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReceiptRowsTable extends ReceiptRows
    with TableInfo<$ReceiptRowsTable, ReceiptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReceiptRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _staffIdMeta = const VerificationMeta(
    'staffId',
  );
  @override
  late final GeneratedColumn<String> staffId = GeneratedColumn<String>(
    'staff_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _staffNameMeta = const VerificationMeta(
    'staffName',
  );
  @override
  late final GeneratedColumn<String> staffName = GeneratedColumn<String>(
    'staff_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _businessDayIdMeta = const VerificationMeta(
    'businessDayId',
  );
  @override
  late final GeneratedColumn<String> businessDayId = GeneratedColumn<String>(
    'business_day_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES business_days (id)',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _voidsReceiptIdMeta = const VerificationMeta(
    'voidsReceiptId',
  );
  @override
  late final GeneratedColumn<String> voidsReceiptId = GeneratedColumn<String>(
    'voids_receipt_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES receipts (id)',
    ),
  );
  static const VerificationMeta _goodsCentsMeta = const VerificationMeta(
    'goodsCents',
  );
  @override
  late final GeneratedColumn<int> goodsCents = GeneratedColumn<int>(
    'goods_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _depositCentsMeta = const VerificationMeta(
    'depositCents',
  );
  @override
  late final GeneratedColumn<int> depositCents = GeneratedColumn<int>(
    'deposit_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalCentsMeta = const VerificationMeta(
    'totalCents',
  );
  @override
  late final GeneratedColumn<int> totalCents = GeneratedColumn<int>(
    'total_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    number,
    createdAt,
    staffId,
    staffName,
    businessDayId,
    kind,
    voidsReceiptId,
    goodsCents,
    depositCents,
    totalCents,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReceiptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('staff_id')) {
      context.handle(
        _staffIdMeta,
        staffId.isAcceptableOrUnknown(data['staff_id']!, _staffIdMeta),
      );
    } else if (isInserting) {
      context.missing(_staffIdMeta);
    }
    if (data.containsKey('staff_name')) {
      context.handle(
        _staffNameMeta,
        staffName.isAcceptableOrUnknown(data['staff_name']!, _staffNameMeta),
      );
    } else if (isInserting) {
      context.missing(_staffNameMeta);
    }
    if (data.containsKey('business_day_id')) {
      context.handle(
        _businessDayIdMeta,
        businessDayId.isAcceptableOrUnknown(
          data['business_day_id']!,
          _businessDayIdMeta,
        ),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('voids_receipt_id')) {
      context.handle(
        _voidsReceiptIdMeta,
        voidsReceiptId.isAcceptableOrUnknown(
          data['voids_receipt_id']!,
          _voidsReceiptIdMeta,
        ),
      );
    }
    if (data.containsKey('goods_cents')) {
      context.handle(
        _goodsCentsMeta,
        goodsCents.isAcceptableOrUnknown(data['goods_cents']!, _goodsCentsMeta),
      );
    } else if (isInserting) {
      context.missing(_goodsCentsMeta);
    }
    if (data.containsKey('deposit_cents')) {
      context.handle(
        _depositCentsMeta,
        depositCents.isAcceptableOrUnknown(
          data['deposit_cents']!,
          _depositCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_depositCentsMeta);
    }
    if (data.containsKey('total_cents')) {
      context.handle(
        _totalCentsMeta,
        totalCents.isAcceptableOrUnknown(data['total_cents']!, _totalCentsMeta),
      );
    } else if (isInserting) {
      context.missing(_totalCentsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReceiptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReceiptRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      staffId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}staff_id'],
      )!,
      staffName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}staff_name'],
      )!,
      businessDayId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_day_id'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      voidsReceiptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voids_receipt_id'],
      ),
      goodsCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}goods_cents'],
      )!,
      depositCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deposit_cents'],
      )!,
      totalCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_cents'],
      )!,
    );
  }

  @override
  $ReceiptRowsTable createAlias(String alias) {
    return $ReceiptRowsTable(attachedDatabase, alias);
  }
}

class ReceiptRow extends DataClass implements Insertable<ReceiptRow> {
  final String id;
  final int number;
  final DateTime createdAt;
  final String staffId;
  final String staffName;

  /// Leer bei Sonderbelegen: sie gehören zu keinem Tag.
  final String? businessDayId;

  /// `sale` oder `voided`, bei Sonderbelegen `start`, `month`, `year`,
  /// `zero`, `collective` oder `closing`.
  final String kind;

  /// Beim Storno-Bon der Bon, den er storniert. Ein eindeutiger Index sorgt
  /// dafür, dass es höchstens einen Storno je Bon gibt.
  final String? voidsReceiptId;
  final int goodsCents;
  final int depositCents;
  final int totalCents;
  const ReceiptRow({
    required this.id,
    required this.number,
    required this.createdAt,
    required this.staffId,
    required this.staffName,
    this.businessDayId,
    required this.kind,
    this.voidsReceiptId,
    required this.goodsCents,
    required this.depositCents,
    required this.totalCents,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['number'] = Variable<int>(number);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['staff_id'] = Variable<String>(staffId);
    map['staff_name'] = Variable<String>(staffName);
    if (!nullToAbsent || businessDayId != null) {
      map['business_day_id'] = Variable<String>(businessDayId);
    }
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || voidsReceiptId != null) {
      map['voids_receipt_id'] = Variable<String>(voidsReceiptId);
    }
    map['goods_cents'] = Variable<int>(goodsCents);
    map['deposit_cents'] = Variable<int>(depositCents);
    map['total_cents'] = Variable<int>(totalCents);
    return map;
  }

  ReceiptRowsCompanion toCompanion(bool nullToAbsent) {
    return ReceiptRowsCompanion(
      id: Value(id),
      number: Value(number),
      createdAt: Value(createdAt),
      staffId: Value(staffId),
      staffName: Value(staffName),
      businessDayId: businessDayId == null && nullToAbsent
          ? const Value.absent()
          : Value(businessDayId),
      kind: Value(kind),
      voidsReceiptId: voidsReceiptId == null && nullToAbsent
          ? const Value.absent()
          : Value(voidsReceiptId),
      goodsCents: Value(goodsCents),
      depositCents: Value(depositCents),
      totalCents: Value(totalCents),
    );
  }

  factory ReceiptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReceiptRow(
      id: serializer.fromJson<String>(json['id']),
      number: serializer.fromJson<int>(json['number']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      staffId: serializer.fromJson<String>(json['staffId']),
      staffName: serializer.fromJson<String>(json['staffName']),
      businessDayId: serializer.fromJson<String?>(json['businessDayId']),
      kind: serializer.fromJson<String>(json['kind']),
      voidsReceiptId: serializer.fromJson<String?>(json['voidsReceiptId']),
      goodsCents: serializer.fromJson<int>(json['goodsCents']),
      depositCents: serializer.fromJson<int>(json['depositCents']),
      totalCents: serializer.fromJson<int>(json['totalCents']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'number': serializer.toJson<int>(number),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'staffId': serializer.toJson<String>(staffId),
      'staffName': serializer.toJson<String>(staffName),
      'businessDayId': serializer.toJson<String?>(businessDayId),
      'kind': serializer.toJson<String>(kind),
      'voidsReceiptId': serializer.toJson<String?>(voidsReceiptId),
      'goodsCents': serializer.toJson<int>(goodsCents),
      'depositCents': serializer.toJson<int>(depositCents),
      'totalCents': serializer.toJson<int>(totalCents),
    };
  }

  ReceiptRow copyWith({
    String? id,
    int? number,
    DateTime? createdAt,
    String? staffId,
    String? staffName,
    Value<String?> businessDayId = const Value.absent(),
    String? kind,
    Value<String?> voidsReceiptId = const Value.absent(),
    int? goodsCents,
    int? depositCents,
    int? totalCents,
  }) => ReceiptRow(
    id: id ?? this.id,
    number: number ?? this.number,
    createdAt: createdAt ?? this.createdAt,
    staffId: staffId ?? this.staffId,
    staffName: staffName ?? this.staffName,
    businessDayId: businessDayId.present
        ? businessDayId.value
        : this.businessDayId,
    kind: kind ?? this.kind,
    voidsReceiptId: voidsReceiptId.present
        ? voidsReceiptId.value
        : this.voidsReceiptId,
    goodsCents: goodsCents ?? this.goodsCents,
    depositCents: depositCents ?? this.depositCents,
    totalCents: totalCents ?? this.totalCents,
  );
  ReceiptRow copyWithCompanion(ReceiptRowsCompanion data) {
    return ReceiptRow(
      id: data.id.present ? data.id.value : this.id,
      number: data.number.present ? data.number.value : this.number,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      staffId: data.staffId.present ? data.staffId.value : this.staffId,
      staffName: data.staffName.present ? data.staffName.value : this.staffName,
      businessDayId: data.businessDayId.present
          ? data.businessDayId.value
          : this.businessDayId,
      kind: data.kind.present ? data.kind.value : this.kind,
      voidsReceiptId: data.voidsReceiptId.present
          ? data.voidsReceiptId.value
          : this.voidsReceiptId,
      goodsCents: data.goodsCents.present
          ? data.goodsCents.value
          : this.goodsCents,
      depositCents: data.depositCents.present
          ? data.depositCents.value
          : this.depositCents,
      totalCents: data.totalCents.present
          ? data.totalCents.value
          : this.totalCents,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptRow(')
          ..write('id: $id, ')
          ..write('number: $number, ')
          ..write('createdAt: $createdAt, ')
          ..write('staffId: $staffId, ')
          ..write('staffName: $staffName, ')
          ..write('businessDayId: $businessDayId, ')
          ..write('kind: $kind, ')
          ..write('voidsReceiptId: $voidsReceiptId, ')
          ..write('goodsCents: $goodsCents, ')
          ..write('depositCents: $depositCents, ')
          ..write('totalCents: $totalCents')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    number,
    createdAt,
    staffId,
    staffName,
    businessDayId,
    kind,
    voidsReceiptId,
    goodsCents,
    depositCents,
    totalCents,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReceiptRow &&
          other.id == this.id &&
          other.number == this.number &&
          other.createdAt == this.createdAt &&
          other.staffId == this.staffId &&
          other.staffName == this.staffName &&
          other.businessDayId == this.businessDayId &&
          other.kind == this.kind &&
          other.voidsReceiptId == this.voidsReceiptId &&
          other.goodsCents == this.goodsCents &&
          other.depositCents == this.depositCents &&
          other.totalCents == this.totalCents);
}

class ReceiptRowsCompanion extends UpdateCompanion<ReceiptRow> {
  final Value<String> id;
  final Value<int> number;
  final Value<DateTime> createdAt;
  final Value<String> staffId;
  final Value<String> staffName;
  final Value<String?> businessDayId;
  final Value<String> kind;
  final Value<String?> voidsReceiptId;
  final Value<int> goodsCents;
  final Value<int> depositCents;
  final Value<int> totalCents;
  final Value<int> rowid;
  const ReceiptRowsCompanion({
    this.id = const Value.absent(),
    this.number = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.staffId = const Value.absent(),
    this.staffName = const Value.absent(),
    this.businessDayId = const Value.absent(),
    this.kind = const Value.absent(),
    this.voidsReceiptId = const Value.absent(),
    this.goodsCents = const Value.absent(),
    this.depositCents = const Value.absent(),
    this.totalCents = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReceiptRowsCompanion.insert({
    required String id,
    required int number,
    required DateTime createdAt,
    required String staffId,
    required String staffName,
    this.businessDayId = const Value.absent(),
    required String kind,
    this.voidsReceiptId = const Value.absent(),
    required int goodsCents,
    required int depositCents,
    required int totalCents,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       number = Value(number),
       createdAt = Value(createdAt),
       staffId = Value(staffId),
       staffName = Value(staffName),
       kind = Value(kind),
       goodsCents = Value(goodsCents),
       depositCents = Value(depositCents),
       totalCents = Value(totalCents);
  static Insertable<ReceiptRow> custom({
    Expression<String>? id,
    Expression<int>? number,
    Expression<DateTime>? createdAt,
    Expression<String>? staffId,
    Expression<String>? staffName,
    Expression<String>? businessDayId,
    Expression<String>? kind,
    Expression<String>? voidsReceiptId,
    Expression<int>? goodsCents,
    Expression<int>? depositCents,
    Expression<int>? totalCents,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (number != null) 'number': number,
      if (createdAt != null) 'created_at': createdAt,
      if (staffId != null) 'staff_id': staffId,
      if (staffName != null) 'staff_name': staffName,
      if (businessDayId != null) 'business_day_id': businessDayId,
      if (kind != null) 'kind': kind,
      if (voidsReceiptId != null) 'voids_receipt_id': voidsReceiptId,
      if (goodsCents != null) 'goods_cents': goodsCents,
      if (depositCents != null) 'deposit_cents': depositCents,
      if (totalCents != null) 'total_cents': totalCents,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReceiptRowsCompanion copyWith({
    Value<String>? id,
    Value<int>? number,
    Value<DateTime>? createdAt,
    Value<String>? staffId,
    Value<String>? staffName,
    Value<String?>? businessDayId,
    Value<String>? kind,
    Value<String?>? voidsReceiptId,
    Value<int>? goodsCents,
    Value<int>? depositCents,
    Value<int>? totalCents,
    Value<int>? rowid,
  }) {
    return ReceiptRowsCompanion(
      id: id ?? this.id,
      number: number ?? this.number,
      createdAt: createdAt ?? this.createdAt,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      businessDayId: businessDayId ?? this.businessDayId,
      kind: kind ?? this.kind,
      voidsReceiptId: voidsReceiptId ?? this.voidsReceiptId,
      goodsCents: goodsCents ?? this.goodsCents,
      depositCents: depositCents ?? this.depositCents,
      totalCents: totalCents ?? this.totalCents,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (staffId.present) {
      map['staff_id'] = Variable<String>(staffId.value);
    }
    if (staffName.present) {
      map['staff_name'] = Variable<String>(staffName.value);
    }
    if (businessDayId.present) {
      map['business_day_id'] = Variable<String>(businessDayId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (voidsReceiptId.present) {
      map['voids_receipt_id'] = Variable<String>(voidsReceiptId.value);
    }
    if (goodsCents.present) {
      map['goods_cents'] = Variable<int>(goodsCents.value);
    }
    if (depositCents.present) {
      map['deposit_cents'] = Variable<int>(depositCents.value);
    }
    if (totalCents.present) {
      map['total_cents'] = Variable<int>(totalCents.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptRowsCompanion(')
          ..write('id: $id, ')
          ..write('number: $number, ')
          ..write('createdAt: $createdAt, ')
          ..write('staffId: $staffId, ')
          ..write('staffName: $staffName, ')
          ..write('businessDayId: $businessDayId, ')
          ..write('kind: $kind, ')
          ..write('voidsReceiptId: $voidsReceiptId, ')
          ..write('goodsCents: $goodsCents, ')
          ..write('depositCents: $depositCents, ')
          ..write('totalCents: $totalCents, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReceiptLineRowsTable extends ReceiptLineRows
    with TableInfo<$ReceiptLineRowsTable, ReceiptLineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReceiptLineRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _receiptIdMeta = const VerificationMeta(
    'receiptId',
  );
  @override
  late final GeneratedColumn<String> receiptId = GeneratedColumn<String>(
    'receipt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES receipts (id)',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _infoMeta = const VerificationMeta('info');
  @override
  late final GeneratedColumn<String> info = GeneratedColumn<String>(
    'info',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitPriceCentsMeta = const VerificationMeta(
    'unitPriceCents',
  );
  @override
  late final GeneratedColumn<int> unitPriceCents = GeneratedColumn<int>(
    'unit_price_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitDepositCentsMeta = const VerificationMeta(
    'unitDepositCents',
  );
  @override
  late final GeneratedColumn<int> unitDepositCents = GeneratedColumn<int>(
    'unit_deposit_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gross20CentsMeta = const VerificationMeta(
    'gross20Cents',
  );
  @override
  late final GeneratedColumn<int> gross20Cents = GeneratedColumn<int>(
    'gross20_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _gross10CentsMeta = const VerificationMeta(
    'gross10Cents',
  );
  @override
  late final GeneratedColumn<int> gross10Cents = GeneratedColumn<int>(
    'gross10_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _gross13CentsMeta = const VerificationMeta(
    'gross13Cents',
  );
  @override
  late final GeneratedColumn<int> gross13Cents = GeneratedColumn<int>(
    'gross13_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _gross0CentsMeta = const VerificationMeta(
    'gross0Cents',
  );
  @override
  late final GeneratedColumn<int> gross0Cents = GeneratedColumn<int>(
    'gross0_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _gross19CentsMeta = const VerificationMeta(
    'gross19Cents',
  );
  @override
  late final GeneratedColumn<int> gross19Cents = GeneratedColumn<int>(
    'gross19_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    receiptId,
    position,
    itemId,
    name,
    info,
    unitPriceCents,
    quantity,
    unitDepositCents,
    gross20Cents,
    gross10Cents,
    gross13Cents,
    gross0Cents,
    gross19Cents,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'receipt_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReceiptLineRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('receipt_id')) {
      context.handle(
        _receiptIdMeta,
        receiptId.isAcceptableOrUnknown(data['receipt_id']!, _receiptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_receiptIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('info')) {
      context.handle(
        _infoMeta,
        info.isAcceptableOrUnknown(data['info']!, _infoMeta),
      );
    }
    if (data.containsKey('unit_price_cents')) {
      context.handle(
        _unitPriceCentsMeta,
        unitPriceCents.isAcceptableOrUnknown(
          data['unit_price_cents']!,
          _unitPriceCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unitPriceCentsMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit_deposit_cents')) {
      context.handle(
        _unitDepositCentsMeta,
        unitDepositCents.isAcceptableOrUnknown(
          data['unit_deposit_cents']!,
          _unitDepositCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unitDepositCentsMeta);
    }
    if (data.containsKey('gross20_cents')) {
      context.handle(
        _gross20CentsMeta,
        gross20Cents.isAcceptableOrUnknown(
          data['gross20_cents']!,
          _gross20CentsMeta,
        ),
      );
    }
    if (data.containsKey('gross10_cents')) {
      context.handle(
        _gross10CentsMeta,
        gross10Cents.isAcceptableOrUnknown(
          data['gross10_cents']!,
          _gross10CentsMeta,
        ),
      );
    }
    if (data.containsKey('gross13_cents')) {
      context.handle(
        _gross13CentsMeta,
        gross13Cents.isAcceptableOrUnknown(
          data['gross13_cents']!,
          _gross13CentsMeta,
        ),
      );
    }
    if (data.containsKey('gross0_cents')) {
      context.handle(
        _gross0CentsMeta,
        gross0Cents.isAcceptableOrUnknown(
          data['gross0_cents']!,
          _gross0CentsMeta,
        ),
      );
    }
    if (data.containsKey('gross19_cents')) {
      context.handle(
        _gross19CentsMeta,
        gross19Cents.isAcceptableOrUnknown(
          data['gross19_cents']!,
          _gross19CentsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {receiptId, position};
  @override
  ReceiptLineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReceiptLineRow(
      receiptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      info: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}info'],
      ),
      unitPriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_price_cents'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      unitDepositCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_deposit_cents'],
      )!,
      gross20Cents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gross20_cents'],
      )!,
      gross10Cents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gross10_cents'],
      )!,
      gross13Cents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gross13_cents'],
      )!,
      gross0Cents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gross0_cents'],
      )!,
      gross19Cents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gross19_cents'],
      )!,
    );
  }

  @override
  $ReceiptLineRowsTable createAlias(String alias) {
    return $ReceiptLineRowsTable(attachedDatabase, alias);
  }
}

class ReceiptLineRow extends DataClass implements Insertable<ReceiptLineRow> {
  final String receiptId;
  final int position;
  final String itemId;
  final String name;
  final String? info;

  /// Einzelpreis inklusive Aufpreisen der Optionen.
  final int unitPriceCents;
  final int quantity;
  final int unitDepositCents;

  /// Brutto-Warenwert der Zeile je Steuersatz (ohne Pfand).
  final int gross20Cents;
  final int gross10Cents;
  final int gross13Cents;
  final int gross0Cents;
  final int gross19Cents;
  const ReceiptLineRow({
    required this.receiptId,
    required this.position,
    required this.itemId,
    required this.name,
    this.info,
    required this.unitPriceCents,
    required this.quantity,
    required this.unitDepositCents,
    required this.gross20Cents,
    required this.gross10Cents,
    required this.gross13Cents,
    required this.gross0Cents,
    required this.gross19Cents,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['receipt_id'] = Variable<String>(receiptId);
    map['position'] = Variable<int>(position);
    map['item_id'] = Variable<String>(itemId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || info != null) {
      map['info'] = Variable<String>(info);
    }
    map['unit_price_cents'] = Variable<int>(unitPriceCents);
    map['quantity'] = Variable<int>(quantity);
    map['unit_deposit_cents'] = Variable<int>(unitDepositCents);
    map['gross20_cents'] = Variable<int>(gross20Cents);
    map['gross10_cents'] = Variable<int>(gross10Cents);
    map['gross13_cents'] = Variable<int>(gross13Cents);
    map['gross0_cents'] = Variable<int>(gross0Cents);
    map['gross19_cents'] = Variable<int>(gross19Cents);
    return map;
  }

  ReceiptLineRowsCompanion toCompanion(bool nullToAbsent) {
    return ReceiptLineRowsCompanion(
      receiptId: Value(receiptId),
      position: Value(position),
      itemId: Value(itemId),
      name: Value(name),
      info: info == null && nullToAbsent ? const Value.absent() : Value(info),
      unitPriceCents: Value(unitPriceCents),
      quantity: Value(quantity),
      unitDepositCents: Value(unitDepositCents),
      gross20Cents: Value(gross20Cents),
      gross10Cents: Value(gross10Cents),
      gross13Cents: Value(gross13Cents),
      gross0Cents: Value(gross0Cents),
      gross19Cents: Value(gross19Cents),
    );
  }

  factory ReceiptLineRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReceiptLineRow(
      receiptId: serializer.fromJson<String>(json['receiptId']),
      position: serializer.fromJson<int>(json['position']),
      itemId: serializer.fromJson<String>(json['itemId']),
      name: serializer.fromJson<String>(json['name']),
      info: serializer.fromJson<String?>(json['info']),
      unitPriceCents: serializer.fromJson<int>(json['unitPriceCents']),
      quantity: serializer.fromJson<int>(json['quantity']),
      unitDepositCents: serializer.fromJson<int>(json['unitDepositCents']),
      gross20Cents: serializer.fromJson<int>(json['gross20Cents']),
      gross10Cents: serializer.fromJson<int>(json['gross10Cents']),
      gross13Cents: serializer.fromJson<int>(json['gross13Cents']),
      gross0Cents: serializer.fromJson<int>(json['gross0Cents']),
      gross19Cents: serializer.fromJson<int>(json['gross19Cents']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'receiptId': serializer.toJson<String>(receiptId),
      'position': serializer.toJson<int>(position),
      'itemId': serializer.toJson<String>(itemId),
      'name': serializer.toJson<String>(name),
      'info': serializer.toJson<String?>(info),
      'unitPriceCents': serializer.toJson<int>(unitPriceCents),
      'quantity': serializer.toJson<int>(quantity),
      'unitDepositCents': serializer.toJson<int>(unitDepositCents),
      'gross20Cents': serializer.toJson<int>(gross20Cents),
      'gross10Cents': serializer.toJson<int>(gross10Cents),
      'gross13Cents': serializer.toJson<int>(gross13Cents),
      'gross0Cents': serializer.toJson<int>(gross0Cents),
      'gross19Cents': serializer.toJson<int>(gross19Cents),
    };
  }

  ReceiptLineRow copyWith({
    String? receiptId,
    int? position,
    String? itemId,
    String? name,
    Value<String?> info = const Value.absent(),
    int? unitPriceCents,
    int? quantity,
    int? unitDepositCents,
    int? gross20Cents,
    int? gross10Cents,
    int? gross13Cents,
    int? gross0Cents,
    int? gross19Cents,
  }) => ReceiptLineRow(
    receiptId: receiptId ?? this.receiptId,
    position: position ?? this.position,
    itemId: itemId ?? this.itemId,
    name: name ?? this.name,
    info: info.present ? info.value : this.info,
    unitPriceCents: unitPriceCents ?? this.unitPriceCents,
    quantity: quantity ?? this.quantity,
    unitDepositCents: unitDepositCents ?? this.unitDepositCents,
    gross20Cents: gross20Cents ?? this.gross20Cents,
    gross10Cents: gross10Cents ?? this.gross10Cents,
    gross13Cents: gross13Cents ?? this.gross13Cents,
    gross0Cents: gross0Cents ?? this.gross0Cents,
    gross19Cents: gross19Cents ?? this.gross19Cents,
  );
  ReceiptLineRow copyWithCompanion(ReceiptLineRowsCompanion data) {
    return ReceiptLineRow(
      receiptId: data.receiptId.present ? data.receiptId.value : this.receiptId,
      position: data.position.present ? data.position.value : this.position,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      name: data.name.present ? data.name.value : this.name,
      info: data.info.present ? data.info.value : this.info,
      unitPriceCents: data.unitPriceCents.present
          ? data.unitPriceCents.value
          : this.unitPriceCents,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitDepositCents: data.unitDepositCents.present
          ? data.unitDepositCents.value
          : this.unitDepositCents,
      gross20Cents: data.gross20Cents.present
          ? data.gross20Cents.value
          : this.gross20Cents,
      gross10Cents: data.gross10Cents.present
          ? data.gross10Cents.value
          : this.gross10Cents,
      gross13Cents: data.gross13Cents.present
          ? data.gross13Cents.value
          : this.gross13Cents,
      gross0Cents: data.gross0Cents.present
          ? data.gross0Cents.value
          : this.gross0Cents,
      gross19Cents: data.gross19Cents.present
          ? data.gross19Cents.value
          : this.gross19Cents,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptLineRow(')
          ..write('receiptId: $receiptId, ')
          ..write('position: $position, ')
          ..write('itemId: $itemId, ')
          ..write('name: $name, ')
          ..write('info: $info, ')
          ..write('unitPriceCents: $unitPriceCents, ')
          ..write('quantity: $quantity, ')
          ..write('unitDepositCents: $unitDepositCents, ')
          ..write('gross20Cents: $gross20Cents, ')
          ..write('gross10Cents: $gross10Cents, ')
          ..write('gross13Cents: $gross13Cents, ')
          ..write('gross0Cents: $gross0Cents, ')
          ..write('gross19Cents: $gross19Cents')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    receiptId,
    position,
    itemId,
    name,
    info,
    unitPriceCents,
    quantity,
    unitDepositCents,
    gross20Cents,
    gross10Cents,
    gross13Cents,
    gross0Cents,
    gross19Cents,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReceiptLineRow &&
          other.receiptId == this.receiptId &&
          other.position == this.position &&
          other.itemId == this.itemId &&
          other.name == this.name &&
          other.info == this.info &&
          other.unitPriceCents == this.unitPriceCents &&
          other.quantity == this.quantity &&
          other.unitDepositCents == this.unitDepositCents &&
          other.gross20Cents == this.gross20Cents &&
          other.gross10Cents == this.gross10Cents &&
          other.gross13Cents == this.gross13Cents &&
          other.gross0Cents == this.gross0Cents &&
          other.gross19Cents == this.gross19Cents);
}

class ReceiptLineRowsCompanion extends UpdateCompanion<ReceiptLineRow> {
  final Value<String> receiptId;
  final Value<int> position;
  final Value<String> itemId;
  final Value<String> name;
  final Value<String?> info;
  final Value<int> unitPriceCents;
  final Value<int> quantity;
  final Value<int> unitDepositCents;
  final Value<int> gross20Cents;
  final Value<int> gross10Cents;
  final Value<int> gross13Cents;
  final Value<int> gross0Cents;
  final Value<int> gross19Cents;
  final Value<int> rowid;
  const ReceiptLineRowsCompanion({
    this.receiptId = const Value.absent(),
    this.position = const Value.absent(),
    this.itemId = const Value.absent(),
    this.name = const Value.absent(),
    this.info = const Value.absent(),
    this.unitPriceCents = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitDepositCents = const Value.absent(),
    this.gross20Cents = const Value.absent(),
    this.gross10Cents = const Value.absent(),
    this.gross13Cents = const Value.absent(),
    this.gross0Cents = const Value.absent(),
    this.gross19Cents = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReceiptLineRowsCompanion.insert({
    required String receiptId,
    required int position,
    required String itemId,
    required String name,
    this.info = const Value.absent(),
    required int unitPriceCents,
    required int quantity,
    required int unitDepositCents,
    this.gross20Cents = const Value.absent(),
    this.gross10Cents = const Value.absent(),
    this.gross13Cents = const Value.absent(),
    this.gross0Cents = const Value.absent(),
    this.gross19Cents = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : receiptId = Value(receiptId),
       position = Value(position),
       itemId = Value(itemId),
       name = Value(name),
       unitPriceCents = Value(unitPriceCents),
       quantity = Value(quantity),
       unitDepositCents = Value(unitDepositCents);
  static Insertable<ReceiptLineRow> custom({
    Expression<String>? receiptId,
    Expression<int>? position,
    Expression<String>? itemId,
    Expression<String>? name,
    Expression<String>? info,
    Expression<int>? unitPriceCents,
    Expression<int>? quantity,
    Expression<int>? unitDepositCents,
    Expression<int>? gross20Cents,
    Expression<int>? gross10Cents,
    Expression<int>? gross13Cents,
    Expression<int>? gross0Cents,
    Expression<int>? gross19Cents,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (receiptId != null) 'receipt_id': receiptId,
      if (position != null) 'position': position,
      if (itemId != null) 'item_id': itemId,
      if (name != null) 'name': name,
      if (info != null) 'info': info,
      if (unitPriceCents != null) 'unit_price_cents': unitPriceCents,
      if (quantity != null) 'quantity': quantity,
      if (unitDepositCents != null) 'unit_deposit_cents': unitDepositCents,
      if (gross20Cents != null) 'gross20_cents': gross20Cents,
      if (gross10Cents != null) 'gross10_cents': gross10Cents,
      if (gross13Cents != null) 'gross13_cents': gross13Cents,
      if (gross0Cents != null) 'gross0_cents': gross0Cents,
      if (gross19Cents != null) 'gross19_cents': gross19Cents,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReceiptLineRowsCompanion copyWith({
    Value<String>? receiptId,
    Value<int>? position,
    Value<String>? itemId,
    Value<String>? name,
    Value<String?>? info,
    Value<int>? unitPriceCents,
    Value<int>? quantity,
    Value<int>? unitDepositCents,
    Value<int>? gross20Cents,
    Value<int>? gross10Cents,
    Value<int>? gross13Cents,
    Value<int>? gross0Cents,
    Value<int>? gross19Cents,
    Value<int>? rowid,
  }) {
    return ReceiptLineRowsCompanion(
      receiptId: receiptId ?? this.receiptId,
      position: position ?? this.position,
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      info: info ?? this.info,
      unitPriceCents: unitPriceCents ?? this.unitPriceCents,
      quantity: quantity ?? this.quantity,
      unitDepositCents: unitDepositCents ?? this.unitDepositCents,
      gross20Cents: gross20Cents ?? this.gross20Cents,
      gross10Cents: gross10Cents ?? this.gross10Cents,
      gross13Cents: gross13Cents ?? this.gross13Cents,
      gross0Cents: gross0Cents ?? this.gross0Cents,
      gross19Cents: gross19Cents ?? this.gross19Cents,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (receiptId.present) {
      map['receipt_id'] = Variable<String>(receiptId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (info.present) {
      map['info'] = Variable<String>(info.value);
    }
    if (unitPriceCents.present) {
      map['unit_price_cents'] = Variable<int>(unitPriceCents.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (unitDepositCents.present) {
      map['unit_deposit_cents'] = Variable<int>(unitDepositCents.value);
    }
    if (gross20Cents.present) {
      map['gross20_cents'] = Variable<int>(gross20Cents.value);
    }
    if (gross10Cents.present) {
      map['gross10_cents'] = Variable<int>(gross10Cents.value);
    }
    if (gross13Cents.present) {
      map['gross13_cents'] = Variable<int>(gross13Cents.value);
    }
    if (gross0Cents.present) {
      map['gross0_cents'] = Variable<int>(gross0Cents.value);
    }
    if (gross19Cents.present) {
      map['gross19_cents'] = Variable<int>(gross19Cents.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptLineRowsCompanion(')
          ..write('receiptId: $receiptId, ')
          ..write('position: $position, ')
          ..write('itemId: $itemId, ')
          ..write('name: $name, ')
          ..write('info: $info, ')
          ..write('unitPriceCents: $unitPriceCents, ')
          ..write('quantity: $quantity, ')
          ..write('unitDepositCents: $unitDepositCents, ')
          ..write('gross20Cents: $gross20Cents, ')
          ..write('gross10Cents: $gross10Cents, ')
          ..write('gross13Cents: $gross13Cents, ')
          ..write('gross0Cents: $gross0Cents, ')
          ..write('gross19Cents: $gross19Cents, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReceiptLineOptionRowsTable extends ReceiptLineOptionRows
    with TableInfo<$ReceiptLineOptionRowsTable, ReceiptLineOptionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReceiptLineOptionRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _receiptIdMeta = const VerificationMeta(
    'receiptId',
  );
  @override
  late final GeneratedColumn<String> receiptId = GeneratedColumn<String>(
    'receipt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _linePositionMeta = const VerificationMeta(
    'linePosition',
  );
  @override
  late final GeneratedColumn<int> linePosition = GeneratedColumn<int>(
    'line_position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _optionNameMeta = const VerificationMeta(
    'optionName',
  );
  @override
  late final GeneratedColumn<String> optionName = GeneratedColumn<String>(
    'option_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _surchargeCentsMeta = const VerificationMeta(
    'surchargeCents',
  );
  @override
  late final GeneratedColumn<int> surchargeCents = GeneratedColumn<int>(
    'surcharge_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    receiptId,
    linePosition,
    position,
    groupName,
    optionName,
    surchargeCents,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'receipt_line_options';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReceiptLineOptionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('receipt_id')) {
      context.handle(
        _receiptIdMeta,
        receiptId.isAcceptableOrUnknown(data['receipt_id']!, _receiptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_receiptIdMeta);
    }
    if (data.containsKey('line_position')) {
      context.handle(
        _linePositionMeta,
        linePosition.isAcceptableOrUnknown(
          data['line_position']!,
          _linePositionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_linePositionMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    } else if (isInserting) {
      context.missing(_groupNameMeta);
    }
    if (data.containsKey('option_name')) {
      context.handle(
        _optionNameMeta,
        optionName.isAcceptableOrUnknown(data['option_name']!, _optionNameMeta),
      );
    } else if (isInserting) {
      context.missing(_optionNameMeta);
    }
    if (data.containsKey('surcharge_cents')) {
      context.handle(
        _surchargeCentsMeta,
        surchargeCents.isAcceptableOrUnknown(
          data['surcharge_cents']!,
          _surchargeCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_surchargeCentsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {receiptId, linePosition, position};
  @override
  ReceiptLineOptionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReceiptLineOptionRow(
      receiptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_id'],
      )!,
      linePosition: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_position'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      )!,
      optionName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}option_name'],
      )!,
      surchargeCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}surcharge_cents'],
      )!,
    );
  }

  @override
  $ReceiptLineOptionRowsTable createAlias(String alias) {
    return $ReceiptLineOptionRowsTable(attachedDatabase, alias);
  }
}

class ReceiptLineOptionRow extends DataClass
    implements Insertable<ReceiptLineOptionRow> {
  final String receiptId;
  final int linePosition;
  final int position;
  final String groupName;
  final String optionName;
  final int surchargeCents;
  const ReceiptLineOptionRow({
    required this.receiptId,
    required this.linePosition,
    required this.position,
    required this.groupName,
    required this.optionName,
    required this.surchargeCents,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['receipt_id'] = Variable<String>(receiptId);
    map['line_position'] = Variable<int>(linePosition);
    map['position'] = Variable<int>(position);
    map['group_name'] = Variable<String>(groupName);
    map['option_name'] = Variable<String>(optionName);
    map['surcharge_cents'] = Variable<int>(surchargeCents);
    return map;
  }

  ReceiptLineOptionRowsCompanion toCompanion(bool nullToAbsent) {
    return ReceiptLineOptionRowsCompanion(
      receiptId: Value(receiptId),
      linePosition: Value(linePosition),
      position: Value(position),
      groupName: Value(groupName),
      optionName: Value(optionName),
      surchargeCents: Value(surchargeCents),
    );
  }

  factory ReceiptLineOptionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReceiptLineOptionRow(
      receiptId: serializer.fromJson<String>(json['receiptId']),
      linePosition: serializer.fromJson<int>(json['linePosition']),
      position: serializer.fromJson<int>(json['position']),
      groupName: serializer.fromJson<String>(json['groupName']),
      optionName: serializer.fromJson<String>(json['optionName']),
      surchargeCents: serializer.fromJson<int>(json['surchargeCents']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'receiptId': serializer.toJson<String>(receiptId),
      'linePosition': serializer.toJson<int>(linePosition),
      'position': serializer.toJson<int>(position),
      'groupName': serializer.toJson<String>(groupName),
      'optionName': serializer.toJson<String>(optionName),
      'surchargeCents': serializer.toJson<int>(surchargeCents),
    };
  }

  ReceiptLineOptionRow copyWith({
    String? receiptId,
    int? linePosition,
    int? position,
    String? groupName,
    String? optionName,
    int? surchargeCents,
  }) => ReceiptLineOptionRow(
    receiptId: receiptId ?? this.receiptId,
    linePosition: linePosition ?? this.linePosition,
    position: position ?? this.position,
    groupName: groupName ?? this.groupName,
    optionName: optionName ?? this.optionName,
    surchargeCents: surchargeCents ?? this.surchargeCents,
  );
  ReceiptLineOptionRow copyWithCompanion(ReceiptLineOptionRowsCompanion data) {
    return ReceiptLineOptionRow(
      receiptId: data.receiptId.present ? data.receiptId.value : this.receiptId,
      linePosition: data.linePosition.present
          ? data.linePosition.value
          : this.linePosition,
      position: data.position.present ? data.position.value : this.position,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      optionName: data.optionName.present
          ? data.optionName.value
          : this.optionName,
      surchargeCents: data.surchargeCents.present
          ? data.surchargeCents.value
          : this.surchargeCents,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptLineOptionRow(')
          ..write('receiptId: $receiptId, ')
          ..write('linePosition: $linePosition, ')
          ..write('position: $position, ')
          ..write('groupName: $groupName, ')
          ..write('optionName: $optionName, ')
          ..write('surchargeCents: $surchargeCents')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    receiptId,
    linePosition,
    position,
    groupName,
    optionName,
    surchargeCents,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReceiptLineOptionRow &&
          other.receiptId == this.receiptId &&
          other.linePosition == this.linePosition &&
          other.position == this.position &&
          other.groupName == this.groupName &&
          other.optionName == this.optionName &&
          other.surchargeCents == this.surchargeCents);
}

class ReceiptLineOptionRowsCompanion
    extends UpdateCompanion<ReceiptLineOptionRow> {
  final Value<String> receiptId;
  final Value<int> linePosition;
  final Value<int> position;
  final Value<String> groupName;
  final Value<String> optionName;
  final Value<int> surchargeCents;
  final Value<int> rowid;
  const ReceiptLineOptionRowsCompanion({
    this.receiptId = const Value.absent(),
    this.linePosition = const Value.absent(),
    this.position = const Value.absent(),
    this.groupName = const Value.absent(),
    this.optionName = const Value.absent(),
    this.surchargeCents = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReceiptLineOptionRowsCompanion.insert({
    required String receiptId,
    required int linePosition,
    required int position,
    required String groupName,
    required String optionName,
    required int surchargeCents,
    this.rowid = const Value.absent(),
  }) : receiptId = Value(receiptId),
       linePosition = Value(linePosition),
       position = Value(position),
       groupName = Value(groupName),
       optionName = Value(optionName),
       surchargeCents = Value(surchargeCents);
  static Insertable<ReceiptLineOptionRow> custom({
    Expression<String>? receiptId,
    Expression<int>? linePosition,
    Expression<int>? position,
    Expression<String>? groupName,
    Expression<String>? optionName,
    Expression<int>? surchargeCents,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (receiptId != null) 'receipt_id': receiptId,
      if (linePosition != null) 'line_position': linePosition,
      if (position != null) 'position': position,
      if (groupName != null) 'group_name': groupName,
      if (optionName != null) 'option_name': optionName,
      if (surchargeCents != null) 'surcharge_cents': surchargeCents,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReceiptLineOptionRowsCompanion copyWith({
    Value<String>? receiptId,
    Value<int>? linePosition,
    Value<int>? position,
    Value<String>? groupName,
    Value<String>? optionName,
    Value<int>? surchargeCents,
    Value<int>? rowid,
  }) {
    return ReceiptLineOptionRowsCompanion(
      receiptId: receiptId ?? this.receiptId,
      linePosition: linePosition ?? this.linePosition,
      position: position ?? this.position,
      groupName: groupName ?? this.groupName,
      optionName: optionName ?? this.optionName,
      surchargeCents: surchargeCents ?? this.surchargeCents,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (receiptId.present) {
      map['receipt_id'] = Variable<String>(receiptId.value);
    }
    if (linePosition.present) {
      map['line_position'] = Variable<int>(linePosition.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (optionName.present) {
      map['option_name'] = Variable<String>(optionName.value);
    }
    if (surchargeCents.present) {
      map['surcharge_cents'] = Variable<int>(surchargeCents.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptLineOptionRowsCompanion(')
          ..write('receiptId: $receiptId, ')
          ..write('linePosition: $linePosition, ')
          ..write('position: $position, ')
          ..write('groupName: $groupName, ')
          ..write('optionName: $optionName, ')
          ..write('surchargeCents: $surchargeCents, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PaymentRowsTable extends PaymentRows
    with TableInfo<$PaymentRowsTable, PaymentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PaymentRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _receiptIdMeta = const VerificationMeta(
    'receiptId',
  );
  @override
  late final GeneratedColumn<String> receiptId = GeneratedColumn<String>(
    'receipt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES receipts (id)',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _givenCentsMeta = const VerificationMeta(
    'givenCents',
  );
  @override
  late final GeneratedColumn<int> givenCents = GeneratedColumn<int>(
    'given_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changeCentsMeta = const VerificationMeta(
    'changeCents',
  );
  @override
  late final GeneratedColumn<int> changeCents = GeneratedColumn<int>(
    'change_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerTxCodeMeta = const VerificationMeta(
    'providerTxCode',
  );
  @override
  late final GeneratedColumn<String> providerTxCode = GeneratedColumn<String>(
    'provider_tx_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cardSchemeMeta = const VerificationMeta(
    'cardScheme',
  );
  @override
  late final GeneratedColumn<String> cardScheme = GeneratedColumn<String>(
    'card_scheme',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cardLast4Meta = const VerificationMeta(
    'cardLast4',
  );
  @override
  late final GeneratedColumn<String> cardLast4 = GeneratedColumn<String>(
    'card_last4',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    receiptId,
    kind,
    amountCents,
    givenCents,
    changeCents,
    provider,
    providerTxCode,
    cardScheme,
    cardLast4,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<PaymentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('receipt_id')) {
      context.handle(
        _receiptIdMeta,
        receiptId.isAcceptableOrUnknown(data['receipt_id']!, _receiptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_receiptIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('given_cents')) {
      context.handle(
        _givenCentsMeta,
        givenCents.isAcceptableOrUnknown(data['given_cents']!, _givenCentsMeta),
      );
    } else if (isInserting) {
      context.missing(_givenCentsMeta);
    }
    if (data.containsKey('change_cents')) {
      context.handle(
        _changeCentsMeta,
        changeCents.isAcceptableOrUnknown(
          data['change_cents']!,
          _changeCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_changeCentsMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    }
    if (data.containsKey('provider_tx_code')) {
      context.handle(
        _providerTxCodeMeta,
        providerTxCode.isAcceptableOrUnknown(
          data['provider_tx_code']!,
          _providerTxCodeMeta,
        ),
      );
    }
    if (data.containsKey('card_scheme')) {
      context.handle(
        _cardSchemeMeta,
        cardScheme.isAcceptableOrUnknown(data['card_scheme']!, _cardSchemeMeta),
      );
    }
    if (data.containsKey('card_last4')) {
      context.handle(
        _cardLast4Meta,
        cardLast4.isAcceptableOrUnknown(data['card_last4']!, _cardLast4Meta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {receiptId};
  @override
  PaymentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PaymentRow(
      receiptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      givenCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}given_cents'],
      )!,
      changeCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change_cents'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      ),
      providerTxCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_tx_code'],
      ),
      cardScheme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_scheme'],
      ),
      cardLast4: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_last4'],
      ),
    );
  }

  @override
  $PaymentRowsTable createAlias(String alias) {
    return $PaymentRowsTable(attachedDatabase, alias);
  }
}

class PaymentRow extends DataClass implements Insertable<PaymentRow> {
  final String receiptId;

  /// `cash` oder `card`.
  final String kind;
  final int amountCents;
  final int givenCents;
  final int changeCents;

  /// Nur bei Kartenzahlung gefüllt.
  final String? provider;
  final String? providerTxCode;
  final String? cardScheme;
  final String? cardLast4;
  const PaymentRow({
    required this.receiptId,
    required this.kind,
    required this.amountCents,
    required this.givenCents,
    required this.changeCents,
    this.provider,
    this.providerTxCode,
    this.cardScheme,
    this.cardLast4,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['receipt_id'] = Variable<String>(receiptId);
    map['kind'] = Variable<String>(kind);
    map['amount_cents'] = Variable<int>(amountCents);
    map['given_cents'] = Variable<int>(givenCents);
    map['change_cents'] = Variable<int>(changeCents);
    if (!nullToAbsent || provider != null) {
      map['provider'] = Variable<String>(provider);
    }
    if (!nullToAbsent || providerTxCode != null) {
      map['provider_tx_code'] = Variable<String>(providerTxCode);
    }
    if (!nullToAbsent || cardScheme != null) {
      map['card_scheme'] = Variable<String>(cardScheme);
    }
    if (!nullToAbsent || cardLast4 != null) {
      map['card_last4'] = Variable<String>(cardLast4);
    }
    return map;
  }

  PaymentRowsCompanion toCompanion(bool nullToAbsent) {
    return PaymentRowsCompanion(
      receiptId: Value(receiptId),
      kind: Value(kind),
      amountCents: Value(amountCents),
      givenCents: Value(givenCents),
      changeCents: Value(changeCents),
      provider: provider == null && nullToAbsent
          ? const Value.absent()
          : Value(provider),
      providerTxCode: providerTxCode == null && nullToAbsent
          ? const Value.absent()
          : Value(providerTxCode),
      cardScheme: cardScheme == null && nullToAbsent
          ? const Value.absent()
          : Value(cardScheme),
      cardLast4: cardLast4 == null && nullToAbsent
          ? const Value.absent()
          : Value(cardLast4),
    );
  }

  factory PaymentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PaymentRow(
      receiptId: serializer.fromJson<String>(json['receiptId']),
      kind: serializer.fromJson<String>(json['kind']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      givenCents: serializer.fromJson<int>(json['givenCents']),
      changeCents: serializer.fromJson<int>(json['changeCents']),
      provider: serializer.fromJson<String?>(json['provider']),
      providerTxCode: serializer.fromJson<String?>(json['providerTxCode']),
      cardScheme: serializer.fromJson<String?>(json['cardScheme']),
      cardLast4: serializer.fromJson<String?>(json['cardLast4']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'receiptId': serializer.toJson<String>(receiptId),
      'kind': serializer.toJson<String>(kind),
      'amountCents': serializer.toJson<int>(amountCents),
      'givenCents': serializer.toJson<int>(givenCents),
      'changeCents': serializer.toJson<int>(changeCents),
      'provider': serializer.toJson<String?>(provider),
      'providerTxCode': serializer.toJson<String?>(providerTxCode),
      'cardScheme': serializer.toJson<String?>(cardScheme),
      'cardLast4': serializer.toJson<String?>(cardLast4),
    };
  }

  PaymentRow copyWith({
    String? receiptId,
    String? kind,
    int? amountCents,
    int? givenCents,
    int? changeCents,
    Value<String?> provider = const Value.absent(),
    Value<String?> providerTxCode = const Value.absent(),
    Value<String?> cardScheme = const Value.absent(),
    Value<String?> cardLast4 = const Value.absent(),
  }) => PaymentRow(
    receiptId: receiptId ?? this.receiptId,
    kind: kind ?? this.kind,
    amountCents: amountCents ?? this.amountCents,
    givenCents: givenCents ?? this.givenCents,
    changeCents: changeCents ?? this.changeCents,
    provider: provider.present ? provider.value : this.provider,
    providerTxCode: providerTxCode.present
        ? providerTxCode.value
        : this.providerTxCode,
    cardScheme: cardScheme.present ? cardScheme.value : this.cardScheme,
    cardLast4: cardLast4.present ? cardLast4.value : this.cardLast4,
  );
  PaymentRow copyWithCompanion(PaymentRowsCompanion data) {
    return PaymentRow(
      receiptId: data.receiptId.present ? data.receiptId.value : this.receiptId,
      kind: data.kind.present ? data.kind.value : this.kind,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      givenCents: data.givenCents.present
          ? data.givenCents.value
          : this.givenCents,
      changeCents: data.changeCents.present
          ? data.changeCents.value
          : this.changeCents,
      provider: data.provider.present ? data.provider.value : this.provider,
      providerTxCode: data.providerTxCode.present
          ? data.providerTxCode.value
          : this.providerTxCode,
      cardScheme: data.cardScheme.present
          ? data.cardScheme.value
          : this.cardScheme,
      cardLast4: data.cardLast4.present ? data.cardLast4.value : this.cardLast4,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PaymentRow(')
          ..write('receiptId: $receiptId, ')
          ..write('kind: $kind, ')
          ..write('amountCents: $amountCents, ')
          ..write('givenCents: $givenCents, ')
          ..write('changeCents: $changeCents, ')
          ..write('provider: $provider, ')
          ..write('providerTxCode: $providerTxCode, ')
          ..write('cardScheme: $cardScheme, ')
          ..write('cardLast4: $cardLast4')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    receiptId,
    kind,
    amountCents,
    givenCents,
    changeCents,
    provider,
    providerTxCode,
    cardScheme,
    cardLast4,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PaymentRow &&
          other.receiptId == this.receiptId &&
          other.kind == this.kind &&
          other.amountCents == this.amountCents &&
          other.givenCents == this.givenCents &&
          other.changeCents == this.changeCents &&
          other.provider == this.provider &&
          other.providerTxCode == this.providerTxCode &&
          other.cardScheme == this.cardScheme &&
          other.cardLast4 == this.cardLast4);
}

class PaymentRowsCompanion extends UpdateCompanion<PaymentRow> {
  final Value<String> receiptId;
  final Value<String> kind;
  final Value<int> amountCents;
  final Value<int> givenCents;
  final Value<int> changeCents;
  final Value<String?> provider;
  final Value<String?> providerTxCode;
  final Value<String?> cardScheme;
  final Value<String?> cardLast4;
  final Value<int> rowid;
  const PaymentRowsCompanion({
    this.receiptId = const Value.absent(),
    this.kind = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.givenCents = const Value.absent(),
    this.changeCents = const Value.absent(),
    this.provider = const Value.absent(),
    this.providerTxCode = const Value.absent(),
    this.cardScheme = const Value.absent(),
    this.cardLast4 = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PaymentRowsCompanion.insert({
    required String receiptId,
    required String kind,
    required int amountCents,
    required int givenCents,
    required int changeCents,
    this.provider = const Value.absent(),
    this.providerTxCode = const Value.absent(),
    this.cardScheme = const Value.absent(),
    this.cardLast4 = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : receiptId = Value(receiptId),
       kind = Value(kind),
       amountCents = Value(amountCents),
       givenCents = Value(givenCents),
       changeCents = Value(changeCents);
  static Insertable<PaymentRow> custom({
    Expression<String>? receiptId,
    Expression<String>? kind,
    Expression<int>? amountCents,
    Expression<int>? givenCents,
    Expression<int>? changeCents,
    Expression<String>? provider,
    Expression<String>? providerTxCode,
    Expression<String>? cardScheme,
    Expression<String>? cardLast4,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (receiptId != null) 'receipt_id': receiptId,
      if (kind != null) 'kind': kind,
      if (amountCents != null) 'amount_cents': amountCents,
      if (givenCents != null) 'given_cents': givenCents,
      if (changeCents != null) 'change_cents': changeCents,
      if (provider != null) 'provider': provider,
      if (providerTxCode != null) 'provider_tx_code': providerTxCode,
      if (cardScheme != null) 'card_scheme': cardScheme,
      if (cardLast4 != null) 'card_last4': cardLast4,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PaymentRowsCompanion copyWith({
    Value<String>? receiptId,
    Value<String>? kind,
    Value<int>? amountCents,
    Value<int>? givenCents,
    Value<int>? changeCents,
    Value<String?>? provider,
    Value<String?>? providerTxCode,
    Value<String?>? cardScheme,
    Value<String?>? cardLast4,
    Value<int>? rowid,
  }) {
    return PaymentRowsCompanion(
      receiptId: receiptId ?? this.receiptId,
      kind: kind ?? this.kind,
      amountCents: amountCents ?? this.amountCents,
      givenCents: givenCents ?? this.givenCents,
      changeCents: changeCents ?? this.changeCents,
      provider: provider ?? this.provider,
      providerTxCode: providerTxCode ?? this.providerTxCode,
      cardScheme: cardScheme ?? this.cardScheme,
      cardLast4: cardLast4 ?? this.cardLast4,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (receiptId.present) {
      map['receipt_id'] = Variable<String>(receiptId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (givenCents.present) {
      map['given_cents'] = Variable<int>(givenCents.value);
    }
    if (changeCents.present) {
      map['change_cents'] = Variable<int>(changeCents.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (providerTxCode.present) {
      map['provider_tx_code'] = Variable<String>(providerTxCode.value);
    }
    if (cardScheme.present) {
      map['card_scheme'] = Variable<String>(cardScheme.value);
    }
    if (cardLast4.present) {
      map['card_last4'] = Variable<String>(cardLast4.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaymentRowsCompanion(')
          ..write('receiptId: $receiptId, ')
          ..write('kind: $kind, ')
          ..write('amountCents: $amountCents, ')
          ..write('givenCents: $givenCents, ')
          ..write('changeCents: $changeCents, ')
          ..write('provider: $provider, ')
          ..write('providerTxCode: $providerTxCode, ')
          ..write('cardScheme: $cardScheme, ')
          ..write('cardLast4: $cardLast4, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingCardPaymentRowsTable extends PendingCardPaymentRows
    with TableInfo<$PendingCardPaymentRowsTable, PendingCardPaymentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingCardPaymentRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cartJsonMeta = const VerificationMeta(
    'cartJson',
  );
  @override
  late final GeneratedColumn<String> cartJson = GeneratedColumn<String>(
    'cart_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _staffIdMeta = const VerificationMeta(
    'staffId',
  );
  @override
  late final GeneratedColumn<String> staffId = GeneratedColumn<String>(
    'staff_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _staffNameMeta = const VerificationMeta(
    'staffName',
  );
  @override
  late final GeneratedColumn<String> staffName = GeneratedColumn<String>(
    'staff_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cartJson,
    amountCents,
    staffId,
    staffName,
    startedAt,
    state,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_card_payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingCardPaymentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('cart_json')) {
      context.handle(
        _cartJsonMeta,
        cartJson.isAcceptableOrUnknown(data['cart_json']!, _cartJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_cartJsonMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('staff_id')) {
      context.handle(
        _staffIdMeta,
        staffId.isAcceptableOrUnknown(data['staff_id']!, _staffIdMeta),
      );
    } else if (isInserting) {
      context.missing(_staffIdMeta);
    }
    if (data.containsKey('staff_name')) {
      context.handle(
        _staffNameMeta,
        staffName.isAcceptableOrUnknown(data['staff_name']!, _staffNameMeta),
      );
    } else if (isInserting) {
      context.missing(_staffNameMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingCardPaymentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingCardPaymentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      cartJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cart_json'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      staffId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}staff_id'],
      )!,
      staffName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}staff_name'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
    );
  }

  @override
  $PendingCardPaymentRowsTable createAlias(String alias) {
    return $PendingCardPaymentRowsTable(attachedDatabase, alias);
  }
}

class PendingCardPaymentRow extends DataClass
    implements Insertable<PendingCardPaymentRow> {
  final String id;
  final String cartJson;
  final int amountCents;
  final String staffId;
  final String staffName;
  final DateTime startedAt;

  /// `started` oder `unknown`.
  final String state;
  const PendingCardPaymentRow({
    required this.id,
    required this.cartJson,
    required this.amountCents,
    required this.staffId,
    required this.staffName,
    required this.startedAt,
    required this.state,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['cart_json'] = Variable<String>(cartJson);
    map['amount_cents'] = Variable<int>(amountCents);
    map['staff_id'] = Variable<String>(staffId);
    map['staff_name'] = Variable<String>(staffName);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['state'] = Variable<String>(state);
    return map;
  }

  PendingCardPaymentRowsCompanion toCompanion(bool nullToAbsent) {
    return PendingCardPaymentRowsCompanion(
      id: Value(id),
      cartJson: Value(cartJson),
      amountCents: Value(amountCents),
      staffId: Value(staffId),
      staffName: Value(staffName),
      startedAt: Value(startedAt),
      state: Value(state),
    );
  }

  factory PendingCardPaymentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingCardPaymentRow(
      id: serializer.fromJson<String>(json['id']),
      cartJson: serializer.fromJson<String>(json['cartJson']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      staffId: serializer.fromJson<String>(json['staffId']),
      staffName: serializer.fromJson<String>(json['staffName']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      state: serializer.fromJson<String>(json['state']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'cartJson': serializer.toJson<String>(cartJson),
      'amountCents': serializer.toJson<int>(amountCents),
      'staffId': serializer.toJson<String>(staffId),
      'staffName': serializer.toJson<String>(staffName),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'state': serializer.toJson<String>(state),
    };
  }

  PendingCardPaymentRow copyWith({
    String? id,
    String? cartJson,
    int? amountCents,
    String? staffId,
    String? staffName,
    DateTime? startedAt,
    String? state,
  }) => PendingCardPaymentRow(
    id: id ?? this.id,
    cartJson: cartJson ?? this.cartJson,
    amountCents: amountCents ?? this.amountCents,
    staffId: staffId ?? this.staffId,
    staffName: staffName ?? this.staffName,
    startedAt: startedAt ?? this.startedAt,
    state: state ?? this.state,
  );
  PendingCardPaymentRow copyWithCompanion(
    PendingCardPaymentRowsCompanion data,
  ) {
    return PendingCardPaymentRow(
      id: data.id.present ? data.id.value : this.id,
      cartJson: data.cartJson.present ? data.cartJson.value : this.cartJson,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      staffId: data.staffId.present ? data.staffId.value : this.staffId,
      staffName: data.staffName.present ? data.staffName.value : this.staffName,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      state: data.state.present ? data.state.value : this.state,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingCardPaymentRow(')
          ..write('id: $id, ')
          ..write('cartJson: $cartJson, ')
          ..write('amountCents: $amountCents, ')
          ..write('staffId: $staffId, ')
          ..write('staffName: $staffName, ')
          ..write('startedAt: $startedAt, ')
          ..write('state: $state')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cartJson,
    amountCents,
    staffId,
    staffName,
    startedAt,
    state,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingCardPaymentRow &&
          other.id == this.id &&
          other.cartJson == this.cartJson &&
          other.amountCents == this.amountCents &&
          other.staffId == this.staffId &&
          other.staffName == this.staffName &&
          other.startedAt == this.startedAt &&
          other.state == this.state);
}

class PendingCardPaymentRowsCompanion
    extends UpdateCompanion<PendingCardPaymentRow> {
  final Value<String> id;
  final Value<String> cartJson;
  final Value<int> amountCents;
  final Value<String> staffId;
  final Value<String> staffName;
  final Value<DateTime> startedAt;
  final Value<String> state;
  final Value<int> rowid;
  const PendingCardPaymentRowsCompanion({
    this.id = const Value.absent(),
    this.cartJson = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.staffId = const Value.absent(),
    this.staffName = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.state = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingCardPaymentRowsCompanion.insert({
    required String id,
    required String cartJson,
    required int amountCents,
    required String staffId,
    required String staffName,
    required DateTime startedAt,
    required String state,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       cartJson = Value(cartJson),
       amountCents = Value(amountCents),
       staffId = Value(staffId),
       staffName = Value(staffName),
       startedAt = Value(startedAt),
       state = Value(state);
  static Insertable<PendingCardPaymentRow> custom({
    Expression<String>? id,
    Expression<String>? cartJson,
    Expression<int>? amountCents,
    Expression<String>? staffId,
    Expression<String>? staffName,
    Expression<DateTime>? startedAt,
    Expression<String>? state,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cartJson != null) 'cart_json': cartJson,
      if (amountCents != null) 'amount_cents': amountCents,
      if (staffId != null) 'staff_id': staffId,
      if (staffName != null) 'staff_name': staffName,
      if (startedAt != null) 'started_at': startedAt,
      if (state != null) 'state': state,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingCardPaymentRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? cartJson,
    Value<int>? amountCents,
    Value<String>? staffId,
    Value<String>? staffName,
    Value<DateTime>? startedAt,
    Value<String>? state,
    Value<int>? rowid,
  }) {
    return PendingCardPaymentRowsCompanion(
      id: id ?? this.id,
      cartJson: cartJson ?? this.cartJson,
      amountCents: amountCents ?? this.amountCents,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      startedAt: startedAt ?? this.startedAt,
      state: state ?? this.state,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cartJson.present) {
      map['cart_json'] = Variable<String>(cartJson.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (staffId.present) {
      map['staff_id'] = Variable<String>(staffId.value);
    }
    if (staffName.present) {
      map['staff_name'] = Variable<String>(staffName.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingCardPaymentRowsCompanion(')
          ..write('id: $id, ')
          ..write('cartJson: $cartJson, ')
          ..write('amountCents: $amountCents, ')
          ..write('staffId: $staffId, ')
          ..write('staffName: $staffName, ')
          ..write('startedAt: $startedAt, ')
          ..write('state: $state, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateRowsTable extends SyncStateRows
    with TableInfo<$SyncStateRowsTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _registerIdMeta = const VerificationMeta(
    'registerId',
  );
  @override
  late final GeneratedColumn<String> registerId = GeneratedColumn<String>(
    'register_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _registerNameMeta = const VerificationMeta(
    'registerName',
  );
  @override
  late final GeneratedColumn<String> registerName = GeneratedColumn<String>(
    'register_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _businessIdMeta = const VerificationMeta(
    'businessId',
  );
  @override
  late final GeneratedColumn<String> businessId = GeneratedColumn<String>(
    'business_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pullCursorMeta = const VerificationMeta(
    'pullCursor',
  );
  @override
  late final GeneratedColumn<int> pullCursor = GeneratedColumn<int>(
    'pull_cursor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _initialPullDoneMeta = const VerificationMeta(
    'initialPullDone',
  );
  @override
  late final GeneratedColumn<bool> initialPullDone = GeneratedColumn<bool>(
    'initial_pull_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("initial_pull_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastPullAtMeta = const VerificationMeta(
    'lastPullAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPullAt = GeneratedColumn<DateTime>(
    'last_pull_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blockedMeta = const VerificationMeta(
    'blocked',
  );
  @override
  late final GeneratedColumn<bool> blocked = GeneratedColumn<bool>(
    'blocked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("blocked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPushAtMeta = const VerificationMeta(
    'lastPushAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPushAt = GeneratedColumn<DateTime>(
    'last_push_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photosAutoEnabledMeta = const VerificationMeta(
    'photosAutoEnabled',
  );
  @override
  late final GeneratedColumn<bool> photosAutoEnabled = GeneratedColumn<bool>(
    'photos_auto_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("photos_auto_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    registerId,
    registerName,
    businessId,
    pullCursor,
    initialPullDone,
    lastPullAt,
    lastError,
    blocked,
    deviceId,
    lastPushAt,
    photosAutoEnabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('register_id')) {
      context.handle(
        _registerIdMeta,
        registerId.isAcceptableOrUnknown(data['register_id']!, _registerIdMeta),
      );
    }
    if (data.containsKey('register_name')) {
      context.handle(
        _registerNameMeta,
        registerName.isAcceptableOrUnknown(
          data['register_name']!,
          _registerNameMeta,
        ),
      );
    }
    if (data.containsKey('business_id')) {
      context.handle(
        _businessIdMeta,
        businessId.isAcceptableOrUnknown(data['business_id']!, _businessIdMeta),
      );
    }
    if (data.containsKey('pull_cursor')) {
      context.handle(
        _pullCursorMeta,
        pullCursor.isAcceptableOrUnknown(data['pull_cursor']!, _pullCursorMeta),
      );
    }
    if (data.containsKey('initial_pull_done')) {
      context.handle(
        _initialPullDoneMeta,
        initialPullDone.isAcceptableOrUnknown(
          data['initial_pull_done']!,
          _initialPullDoneMeta,
        ),
      );
    }
    if (data.containsKey('last_pull_at')) {
      context.handle(
        _lastPullAtMeta,
        lastPullAt.isAcceptableOrUnknown(
          data['last_pull_at']!,
          _lastPullAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('blocked')) {
      context.handle(
        _blockedMeta,
        blocked.isAcceptableOrUnknown(data['blocked']!, _blockedMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('last_push_at')) {
      context.handle(
        _lastPushAtMeta,
        lastPushAt.isAcceptableOrUnknown(
          data['last_push_at']!,
          _lastPushAtMeta,
        ),
      );
    }
    if (data.containsKey('photos_auto_enabled')) {
      context.handle(
        _photosAutoEnabledMeta,
        photosAutoEnabled.isAcceptableOrUnknown(
          data['photos_auto_enabled']!,
          _photosAutoEnabledMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      registerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}register_id'],
      ),
      registerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}register_name'],
      ),
      businessId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}business_id'],
      ),
      pullCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pull_cursor'],
      )!,
      initialPullDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}initial_pull_done'],
      )!,
      lastPullAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_pull_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      blocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}blocked'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
      lastPushAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_push_at'],
      ),
      photosAutoEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}photos_auto_enabled'],
      )!,
    );
  }

  @override
  $SyncStateRowsTable createAlias(String alias) {
    return $SyncStateRowsTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  final int id;

  /// `null`, solange die Kassa nicht gekoppelt ist.
  final String? registerId;
  final String? registerName;
  final String? businessId;

  /// Die höchste Änderungs-Nummer, die schon eingespielt ist.
  final int pullCursor;

  /// Erst wahr, wenn der erste vollständige Abgleich eingespielt ist.
  final bool initialPullDone;
  final DateTime? lastPullAt;
  final String? lastError;
  final bool blocked;

  /// Zufällige Kennung dieser Installation, entsteht beim ersten Gebrauch.
  final String? deviceId;

  /// Wann zuletzt etwas an den Server gesendet wurde.
  final DateTime? lastPushAt;

  /// Ob "Bilder anzeigen" schon einmal von selbst eingeschaltet wurde (beim
  /// ersten Foto vom Server, siehe `FileSync`). Das geschieht nur ein Mal;
  /// danach gilt, was am Tablet eingestellt wird.
  final bool photosAutoEnabled;
  const SyncStateRow({
    required this.id,
    this.registerId,
    this.registerName,
    this.businessId,
    required this.pullCursor,
    required this.initialPullDone,
    this.lastPullAt,
    this.lastError,
    required this.blocked,
    this.deviceId,
    this.lastPushAt,
    required this.photosAutoEnabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || registerId != null) {
      map['register_id'] = Variable<String>(registerId);
    }
    if (!nullToAbsent || registerName != null) {
      map['register_name'] = Variable<String>(registerName);
    }
    if (!nullToAbsent || businessId != null) {
      map['business_id'] = Variable<String>(businessId);
    }
    map['pull_cursor'] = Variable<int>(pullCursor);
    map['initial_pull_done'] = Variable<bool>(initialPullDone);
    if (!nullToAbsent || lastPullAt != null) {
      map['last_pull_at'] = Variable<DateTime>(lastPullAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['blocked'] = Variable<bool>(blocked);
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    if (!nullToAbsent || lastPushAt != null) {
      map['last_push_at'] = Variable<DateTime>(lastPushAt);
    }
    map['photos_auto_enabled'] = Variable<bool>(photosAutoEnabled);
    return map;
  }

  SyncStateRowsCompanion toCompanion(bool nullToAbsent) {
    return SyncStateRowsCompanion(
      id: Value(id),
      registerId: registerId == null && nullToAbsent
          ? const Value.absent()
          : Value(registerId),
      registerName: registerName == null && nullToAbsent
          ? const Value.absent()
          : Value(registerName),
      businessId: businessId == null && nullToAbsent
          ? const Value.absent()
          : Value(businessId),
      pullCursor: Value(pullCursor),
      initialPullDone: Value(initialPullDone),
      lastPullAt: lastPullAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPullAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      blocked: Value(blocked),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      lastPushAt: lastPushAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPushAt),
      photosAutoEnabled: Value(photosAutoEnabled),
    );
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      id: serializer.fromJson<int>(json['id']),
      registerId: serializer.fromJson<String?>(json['registerId']),
      registerName: serializer.fromJson<String?>(json['registerName']),
      businessId: serializer.fromJson<String?>(json['businessId']),
      pullCursor: serializer.fromJson<int>(json['pullCursor']),
      initialPullDone: serializer.fromJson<bool>(json['initialPullDone']),
      lastPullAt: serializer.fromJson<DateTime?>(json['lastPullAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      blocked: serializer.fromJson<bool>(json['blocked']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      lastPushAt: serializer.fromJson<DateTime?>(json['lastPushAt']),
      photosAutoEnabled: serializer.fromJson<bool>(json['photosAutoEnabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'registerId': serializer.toJson<String?>(registerId),
      'registerName': serializer.toJson<String?>(registerName),
      'businessId': serializer.toJson<String?>(businessId),
      'pullCursor': serializer.toJson<int>(pullCursor),
      'initialPullDone': serializer.toJson<bool>(initialPullDone),
      'lastPullAt': serializer.toJson<DateTime?>(lastPullAt),
      'lastError': serializer.toJson<String?>(lastError),
      'blocked': serializer.toJson<bool>(blocked),
      'deviceId': serializer.toJson<String?>(deviceId),
      'lastPushAt': serializer.toJson<DateTime?>(lastPushAt),
      'photosAutoEnabled': serializer.toJson<bool>(photosAutoEnabled),
    };
  }

  SyncStateRow copyWith({
    int? id,
    Value<String?> registerId = const Value.absent(),
    Value<String?> registerName = const Value.absent(),
    Value<String?> businessId = const Value.absent(),
    int? pullCursor,
    bool? initialPullDone,
    Value<DateTime?> lastPullAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    bool? blocked,
    Value<String?> deviceId = const Value.absent(),
    Value<DateTime?> lastPushAt = const Value.absent(),
    bool? photosAutoEnabled,
  }) => SyncStateRow(
    id: id ?? this.id,
    registerId: registerId.present ? registerId.value : this.registerId,
    registerName: registerName.present ? registerName.value : this.registerName,
    businessId: businessId.present ? businessId.value : this.businessId,
    pullCursor: pullCursor ?? this.pullCursor,
    initialPullDone: initialPullDone ?? this.initialPullDone,
    lastPullAt: lastPullAt.present ? lastPullAt.value : this.lastPullAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    blocked: blocked ?? this.blocked,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    lastPushAt: lastPushAt.present ? lastPushAt.value : this.lastPushAt,
    photosAutoEnabled: photosAutoEnabled ?? this.photosAutoEnabled,
  );
  SyncStateRow copyWithCompanion(SyncStateRowsCompanion data) {
    return SyncStateRow(
      id: data.id.present ? data.id.value : this.id,
      registerId: data.registerId.present
          ? data.registerId.value
          : this.registerId,
      registerName: data.registerName.present
          ? data.registerName.value
          : this.registerName,
      businessId: data.businessId.present
          ? data.businessId.value
          : this.businessId,
      pullCursor: data.pullCursor.present
          ? data.pullCursor.value
          : this.pullCursor,
      initialPullDone: data.initialPullDone.present
          ? data.initialPullDone.value
          : this.initialPullDone,
      lastPullAt: data.lastPullAt.present
          ? data.lastPullAt.value
          : this.lastPullAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      blocked: data.blocked.present ? data.blocked.value : this.blocked,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      lastPushAt: data.lastPushAt.present
          ? data.lastPushAt.value
          : this.lastPushAt,
      photosAutoEnabled: data.photosAutoEnabled.present
          ? data.photosAutoEnabled.value
          : this.photosAutoEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('id: $id, ')
          ..write('registerId: $registerId, ')
          ..write('registerName: $registerName, ')
          ..write('businessId: $businessId, ')
          ..write('pullCursor: $pullCursor, ')
          ..write('initialPullDone: $initialPullDone, ')
          ..write('lastPullAt: $lastPullAt, ')
          ..write('lastError: $lastError, ')
          ..write('blocked: $blocked, ')
          ..write('deviceId: $deviceId, ')
          ..write('lastPushAt: $lastPushAt, ')
          ..write('photosAutoEnabled: $photosAutoEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    registerId,
    registerName,
    businessId,
    pullCursor,
    initialPullDone,
    lastPullAt,
    lastError,
    blocked,
    deviceId,
    lastPushAt,
    photosAutoEnabled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.id == this.id &&
          other.registerId == this.registerId &&
          other.registerName == this.registerName &&
          other.businessId == this.businessId &&
          other.pullCursor == this.pullCursor &&
          other.initialPullDone == this.initialPullDone &&
          other.lastPullAt == this.lastPullAt &&
          other.lastError == this.lastError &&
          other.blocked == this.blocked &&
          other.deviceId == this.deviceId &&
          other.lastPushAt == this.lastPushAt &&
          other.photosAutoEnabled == this.photosAutoEnabled);
}

class SyncStateRowsCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<int> id;
  final Value<String?> registerId;
  final Value<String?> registerName;
  final Value<String?> businessId;
  final Value<int> pullCursor;
  final Value<bool> initialPullDone;
  final Value<DateTime?> lastPullAt;
  final Value<String?> lastError;
  final Value<bool> blocked;
  final Value<String?> deviceId;
  final Value<DateTime?> lastPushAt;
  final Value<bool> photosAutoEnabled;
  const SyncStateRowsCompanion({
    this.id = const Value.absent(),
    this.registerId = const Value.absent(),
    this.registerName = const Value.absent(),
    this.businessId = const Value.absent(),
    this.pullCursor = const Value.absent(),
    this.initialPullDone = const Value.absent(),
    this.lastPullAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.blocked = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.lastPushAt = const Value.absent(),
    this.photosAutoEnabled = const Value.absent(),
  });
  SyncStateRowsCompanion.insert({
    this.id = const Value.absent(),
    this.registerId = const Value.absent(),
    this.registerName = const Value.absent(),
    this.businessId = const Value.absent(),
    this.pullCursor = const Value.absent(),
    this.initialPullDone = const Value.absent(),
    this.lastPullAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.blocked = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.lastPushAt = const Value.absent(),
    this.photosAutoEnabled = const Value.absent(),
  });
  static Insertable<SyncStateRow> custom({
    Expression<int>? id,
    Expression<String>? registerId,
    Expression<String>? registerName,
    Expression<String>? businessId,
    Expression<int>? pullCursor,
    Expression<bool>? initialPullDone,
    Expression<DateTime>? lastPullAt,
    Expression<String>? lastError,
    Expression<bool>? blocked,
    Expression<String>? deviceId,
    Expression<DateTime>? lastPushAt,
    Expression<bool>? photosAutoEnabled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (registerId != null) 'register_id': registerId,
      if (registerName != null) 'register_name': registerName,
      if (businessId != null) 'business_id': businessId,
      if (pullCursor != null) 'pull_cursor': pullCursor,
      if (initialPullDone != null) 'initial_pull_done': initialPullDone,
      if (lastPullAt != null) 'last_pull_at': lastPullAt,
      if (lastError != null) 'last_error': lastError,
      if (blocked != null) 'blocked': blocked,
      if (deviceId != null) 'device_id': deviceId,
      if (lastPushAt != null) 'last_push_at': lastPushAt,
      if (photosAutoEnabled != null) 'photos_auto_enabled': photosAutoEnabled,
    });
  }

  SyncStateRowsCompanion copyWith({
    Value<int>? id,
    Value<String?>? registerId,
    Value<String?>? registerName,
    Value<String?>? businessId,
    Value<int>? pullCursor,
    Value<bool>? initialPullDone,
    Value<DateTime?>? lastPullAt,
    Value<String?>? lastError,
    Value<bool>? blocked,
    Value<String?>? deviceId,
    Value<DateTime?>? lastPushAt,
    Value<bool>? photosAutoEnabled,
  }) {
    return SyncStateRowsCompanion(
      id: id ?? this.id,
      registerId: registerId ?? this.registerId,
      registerName: registerName ?? this.registerName,
      businessId: businessId ?? this.businessId,
      pullCursor: pullCursor ?? this.pullCursor,
      initialPullDone: initialPullDone ?? this.initialPullDone,
      lastPullAt: lastPullAt ?? this.lastPullAt,
      lastError: lastError ?? this.lastError,
      blocked: blocked ?? this.blocked,
      deviceId: deviceId ?? this.deviceId,
      lastPushAt: lastPushAt ?? this.lastPushAt,
      photosAutoEnabled: photosAutoEnabled ?? this.photosAutoEnabled,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (registerId.present) {
      map['register_id'] = Variable<String>(registerId.value);
    }
    if (registerName.present) {
      map['register_name'] = Variable<String>(registerName.value);
    }
    if (businessId.present) {
      map['business_id'] = Variable<String>(businessId.value);
    }
    if (pullCursor.present) {
      map['pull_cursor'] = Variable<int>(pullCursor.value);
    }
    if (initialPullDone.present) {
      map['initial_pull_done'] = Variable<bool>(initialPullDone.value);
    }
    if (lastPullAt.present) {
      map['last_pull_at'] = Variable<DateTime>(lastPullAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (blocked.present) {
      map['blocked'] = Variable<bool>(blocked.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (lastPushAt.present) {
      map['last_push_at'] = Variable<DateTime>(lastPushAt.value);
    }
    if (photosAutoEnabled.present) {
      map['photos_auto_enabled'] = Variable<bool>(photosAutoEnabled.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRowsCompanion(')
          ..write('id: $id, ')
          ..write('registerId: $registerId, ')
          ..write('registerName: $registerName, ')
          ..write('businessId: $businessId, ')
          ..write('pullCursor: $pullCursor, ')
          ..write('initialPullDone: $initialPullDone, ')
          ..write('lastPullAt: $lastPullAt, ')
          ..write('lastError: $lastError, ')
          ..write('blocked: $blocked, ')
          ..write('deviceId: $deviceId, ')
          ..write('lastPushAt: $lastPushAt, ')
          ..write('photosAutoEnabled: $photosAutoEnabled')
          ..write(')'))
        .toString();
  }
}

class $RksvCertificateRowsTable extends RksvCertificateRows
    with TableInfo<$RksvCertificateRowsTable, RksvCertificateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RksvCertificateRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serialHexMeta = const VerificationMeta(
    'serialHex',
  );
  @override
  late final GeneratedColumn<String> serialHex = GeneratedColumn<String>(
    'serial_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _certificateMeta = const VerificationMeta(
    'certificate',
  );
  @override
  late final GeneratedColumn<Uint8List> certificate =
      GeneratedColumn<Uint8List>(
        'certificate',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _issuersMeta = const VerificationMeta(
    'issuers',
  );
  @override
  late final GeneratedColumn<String> issuers = GeneratedColumn<String>(
    'issuers',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [serialHex, certificate, issuers];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rksv_certificates';
  @override
  VerificationContext validateIntegrity(
    Insertable<RksvCertificateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('serial_hex')) {
      context.handle(
        _serialHexMeta,
        serialHex.isAcceptableOrUnknown(data['serial_hex']!, _serialHexMeta),
      );
    } else if (isInserting) {
      context.missing(_serialHexMeta);
    }
    if (data.containsKey('certificate')) {
      context.handle(
        _certificateMeta,
        certificate.isAcceptableOrUnknown(
          data['certificate']!,
          _certificateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_certificateMeta);
    }
    if (data.containsKey('issuers')) {
      context.handle(
        _issuersMeta,
        issuers.isAcceptableOrUnknown(data['issuers']!, _issuersMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serialHex};
  @override
  RksvCertificateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RksvCertificateRow(
      serialHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serial_hex'],
      )!,
      certificate: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}certificate'],
      )!,
      issuers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}issuers'],
      )!,
    );
  }

  @override
  $RksvCertificateRowsTable createAlias(String alias) {
    return $RksvCertificateRowsTable(attachedDatabase, alias);
  }
}

class RksvCertificateRow extends DataClass
    implements Insertable<RksvCertificateRow> {
  final String serialHex;
  final Uint8List certificate;

  /// Zertifikate der Aussteller: JSON-Liste aus base64.
  final String issuers;
  const RksvCertificateRow({
    required this.serialHex,
    required this.certificate,
    required this.issuers,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['serial_hex'] = Variable<String>(serialHex);
    map['certificate'] = Variable<Uint8List>(certificate);
    map['issuers'] = Variable<String>(issuers);
    return map;
  }

  RksvCertificateRowsCompanion toCompanion(bool nullToAbsent) {
    return RksvCertificateRowsCompanion(
      serialHex: Value(serialHex),
      certificate: Value(certificate),
      issuers: Value(issuers),
    );
  }

  factory RksvCertificateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RksvCertificateRow(
      serialHex: serializer.fromJson<String>(json['serialHex']),
      certificate: serializer.fromJson<Uint8List>(json['certificate']),
      issuers: serializer.fromJson<String>(json['issuers']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serialHex': serializer.toJson<String>(serialHex),
      'certificate': serializer.toJson<Uint8List>(certificate),
      'issuers': serializer.toJson<String>(issuers),
    };
  }

  RksvCertificateRow copyWith({
    String? serialHex,
    Uint8List? certificate,
    String? issuers,
  }) => RksvCertificateRow(
    serialHex: serialHex ?? this.serialHex,
    certificate: certificate ?? this.certificate,
    issuers: issuers ?? this.issuers,
  );
  RksvCertificateRow copyWithCompanion(RksvCertificateRowsCompanion data) {
    return RksvCertificateRow(
      serialHex: data.serialHex.present ? data.serialHex.value : this.serialHex,
      certificate: data.certificate.present
          ? data.certificate.value
          : this.certificate,
      issuers: data.issuers.present ? data.issuers.value : this.issuers,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RksvCertificateRow(')
          ..write('serialHex: $serialHex, ')
          ..write('certificate: $certificate, ')
          ..write('issuers: $issuers')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(serialHex, $driftBlobEquality.hash(certificate), issuers);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RksvCertificateRow &&
          other.serialHex == this.serialHex &&
          $driftBlobEquality.equals(other.certificate, this.certificate) &&
          other.issuers == this.issuers);
}

class RksvCertificateRowsCompanion extends UpdateCompanion<RksvCertificateRow> {
  final Value<String> serialHex;
  final Value<Uint8List> certificate;
  final Value<String> issuers;
  final Value<int> rowid;
  const RksvCertificateRowsCompanion({
    this.serialHex = const Value.absent(),
    this.certificate = const Value.absent(),
    this.issuers = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RksvCertificateRowsCompanion.insert({
    required String serialHex,
    required Uint8List certificate,
    this.issuers = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : serialHex = Value(serialHex),
       certificate = Value(certificate);
  static Insertable<RksvCertificateRow> custom({
    Expression<String>? serialHex,
    Expression<Uint8List>? certificate,
    Expression<String>? issuers,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serialHex != null) 'serial_hex': serialHex,
      if (certificate != null) 'certificate': certificate,
      if (issuers != null) 'issuers': issuers,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RksvCertificateRowsCompanion copyWith({
    Value<String>? serialHex,
    Value<Uint8List>? certificate,
    Value<String>? issuers,
    Value<int>? rowid,
  }) {
    return RksvCertificateRowsCompanion(
      serialHex: serialHex ?? this.serialHex,
      certificate: certificate ?? this.certificate,
      issuers: issuers ?? this.issuers,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serialHex.present) {
      map['serial_hex'] = Variable<String>(serialHex.value);
    }
    if (certificate.present) {
      map['certificate'] = Variable<Uint8List>(certificate.value);
    }
    if (issuers.present) {
      map['issuers'] = Variable<String>(issuers.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RksvCertificateRowsCompanion(')
          ..write('serialHex: $serialHex, ')
          ..write('certificate: $certificate, ')
          ..write('issuers: $issuers, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RksvChainRowsTable extends RksvChainRows
    with TableInfo<$RksvChainRowsTable, RksvChainRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RksvChainRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chainMeta = const VerificationMeta('chain');
  @override
  late final GeneratedColumn<int> chain = GeneratedColumn<int>(
    'chain',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('probe'),
  );
  static const VerificationMeta _cashBoxIdMeta = const VerificationMeta(
    'cashBoxId',
  );
  @override
  late final GeneratedColumn<String> cashBoxId = GeneratedColumn<String>(
    'cash_box_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _zdaIdMeta = const VerificationMeta('zdaId');
  @override
  late final GeneratedColumn<String> zdaId = GeneratedColumn<String>(
    'zda_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _certSerialMeta = const VerificationMeta(
    'certSerial',
  );
  @override
  late final GeneratedColumn<String> certSerial = GeneratedColumn<String>(
    'cert_serial',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES rksv_certificates (serial_hex)',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    chain,
    mode,
    unit,
    cashBoxId,
    zdaId,
    certSerial,
    startedAt,
    endedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rksv_chains';
  @override
  VerificationContext validateIntegrity(
    Insertable<RksvChainRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chain')) {
      context.handle(
        _chainMeta,
        chain.isAcceptableOrUnknown(data['chain']!, _chainMeta),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('cash_box_id')) {
      context.handle(
        _cashBoxIdMeta,
        cashBoxId.isAcceptableOrUnknown(data['cash_box_id']!, _cashBoxIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cashBoxIdMeta);
    }
    if (data.containsKey('zda_id')) {
      context.handle(
        _zdaIdMeta,
        zdaId.isAcceptableOrUnknown(data['zda_id']!, _zdaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_zdaIdMeta);
    }
    if (data.containsKey('cert_serial')) {
      context.handle(
        _certSerialMeta,
        certSerial.isAcceptableOrUnknown(data['cert_serial']!, _certSerialMeta),
      );
    } else if (isInserting) {
      context.missing(_certSerialMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chain};
  @override
  RksvChainRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RksvChainRow(
      chain: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chain'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      cashBoxId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cash_box_id'],
      )!,
      zdaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zda_id'],
      )!,
      certSerial: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cert_serial'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
    );
  }

  @override
  $RksvChainRowsTable createAlias(String alias) {
    return $RksvChainRowsTable(attachedDatabase, alias);
  }
}

class RksvChainRow extends DataClass implements Insertable<RksvChainRow> {
  final int chain;

  /// `probe` oder `live`.
  final String mode;

  /// Wer die Kette signiert: `probe` (Probe-Signatur auf dem Tablet),
  /// `atrustTest` (Testsystem von A-Trust) oder `atrust`. Siehe `RksvUnit`.
  final String unit;
  final String cashBoxId;
  final String zdaId;

  /// Das Zertifikat, mit dem die Kette gerade signiert.
  final String certSerial;
  final DateTime startedAt;
  final DateTime? endedAt;
  const RksvChainRow({
    required this.chain,
    required this.mode,
    required this.unit,
    required this.cashBoxId,
    required this.zdaId,
    required this.certSerial,
    required this.startedAt,
    this.endedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chain'] = Variable<int>(chain);
    map['mode'] = Variable<String>(mode);
    map['unit'] = Variable<String>(unit);
    map['cash_box_id'] = Variable<String>(cashBoxId);
    map['zda_id'] = Variable<String>(zdaId);
    map['cert_serial'] = Variable<String>(certSerial);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    return map;
  }

  RksvChainRowsCompanion toCompanion(bool nullToAbsent) {
    return RksvChainRowsCompanion(
      chain: Value(chain),
      mode: Value(mode),
      unit: Value(unit),
      cashBoxId: Value(cashBoxId),
      zdaId: Value(zdaId),
      certSerial: Value(certSerial),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
    );
  }

  factory RksvChainRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RksvChainRow(
      chain: serializer.fromJson<int>(json['chain']),
      mode: serializer.fromJson<String>(json['mode']),
      unit: serializer.fromJson<String>(json['unit']),
      cashBoxId: serializer.fromJson<String>(json['cashBoxId']),
      zdaId: serializer.fromJson<String>(json['zdaId']),
      certSerial: serializer.fromJson<String>(json['certSerial']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chain': serializer.toJson<int>(chain),
      'mode': serializer.toJson<String>(mode),
      'unit': serializer.toJson<String>(unit),
      'cashBoxId': serializer.toJson<String>(cashBoxId),
      'zdaId': serializer.toJson<String>(zdaId),
      'certSerial': serializer.toJson<String>(certSerial),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
    };
  }

  RksvChainRow copyWith({
    int? chain,
    String? mode,
    String? unit,
    String? cashBoxId,
    String? zdaId,
    String? certSerial,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
  }) => RksvChainRow(
    chain: chain ?? this.chain,
    mode: mode ?? this.mode,
    unit: unit ?? this.unit,
    cashBoxId: cashBoxId ?? this.cashBoxId,
    zdaId: zdaId ?? this.zdaId,
    certSerial: certSerial ?? this.certSerial,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
  );
  RksvChainRow copyWithCompanion(RksvChainRowsCompanion data) {
    return RksvChainRow(
      chain: data.chain.present ? data.chain.value : this.chain,
      mode: data.mode.present ? data.mode.value : this.mode,
      unit: data.unit.present ? data.unit.value : this.unit,
      cashBoxId: data.cashBoxId.present ? data.cashBoxId.value : this.cashBoxId,
      zdaId: data.zdaId.present ? data.zdaId.value : this.zdaId,
      certSerial: data.certSerial.present
          ? data.certSerial.value
          : this.certSerial,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RksvChainRow(')
          ..write('chain: $chain, ')
          ..write('mode: $mode, ')
          ..write('unit: $unit, ')
          ..write('cashBoxId: $cashBoxId, ')
          ..write('zdaId: $zdaId, ')
          ..write('certSerial: $certSerial, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    chain,
    mode,
    unit,
    cashBoxId,
    zdaId,
    certSerial,
    startedAt,
    endedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RksvChainRow &&
          other.chain == this.chain &&
          other.mode == this.mode &&
          other.unit == this.unit &&
          other.cashBoxId == this.cashBoxId &&
          other.zdaId == this.zdaId &&
          other.certSerial == this.certSerial &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt);
}

class RksvChainRowsCompanion extends UpdateCompanion<RksvChainRow> {
  final Value<int> chain;
  final Value<String> mode;
  final Value<String> unit;
  final Value<String> cashBoxId;
  final Value<String> zdaId;
  final Value<String> certSerial;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  const RksvChainRowsCompanion({
    this.chain = const Value.absent(),
    this.mode = const Value.absent(),
    this.unit = const Value.absent(),
    this.cashBoxId = const Value.absent(),
    this.zdaId = const Value.absent(),
    this.certSerial = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
  });
  RksvChainRowsCompanion.insert({
    this.chain = const Value.absent(),
    required String mode,
    this.unit = const Value.absent(),
    required String cashBoxId,
    required String zdaId,
    required String certSerial,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
  }) : mode = Value(mode),
       cashBoxId = Value(cashBoxId),
       zdaId = Value(zdaId),
       certSerial = Value(certSerial),
       startedAt = Value(startedAt);
  static Insertable<RksvChainRow> custom({
    Expression<int>? chain,
    Expression<String>? mode,
    Expression<String>? unit,
    Expression<String>? cashBoxId,
    Expression<String>? zdaId,
    Expression<String>? certSerial,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
  }) {
    return RawValuesInsertable({
      if (chain != null) 'chain': chain,
      if (mode != null) 'mode': mode,
      if (unit != null) 'unit': unit,
      if (cashBoxId != null) 'cash_box_id': cashBoxId,
      if (zdaId != null) 'zda_id': zdaId,
      if (certSerial != null) 'cert_serial': certSerial,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
    });
  }

  RksvChainRowsCompanion copyWith({
    Value<int>? chain,
    Value<String>? mode,
    Value<String>? unit,
    Value<String>? cashBoxId,
    Value<String>? zdaId,
    Value<String>? certSerial,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
  }) {
    return RksvChainRowsCompanion(
      chain: chain ?? this.chain,
      mode: mode ?? this.mode,
      unit: unit ?? this.unit,
      cashBoxId: cashBoxId ?? this.cashBoxId,
      zdaId: zdaId ?? this.zdaId,
      certSerial: certSerial ?? this.certSerial,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chain.present) {
      map['chain'] = Variable<int>(chain.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (cashBoxId.present) {
      map['cash_box_id'] = Variable<String>(cashBoxId.value);
    }
    if (zdaId.present) {
      map['zda_id'] = Variable<String>(zdaId.value);
    }
    if (certSerial.present) {
      map['cert_serial'] = Variable<String>(certSerial.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RksvChainRowsCompanion(')
          ..write('chain: $chain, ')
          ..write('mode: $mode, ')
          ..write('unit: $unit, ')
          ..write('cashBoxId: $cashBoxId, ')
          ..write('zdaId: $zdaId, ')
          ..write('certSerial: $certSerial, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt')
          ..write(')'))
        .toString();
  }
}

class $RksvEntryRowsTable extends RksvEntryRows
    with TableInfo<$RksvEntryRowsTable, RksvEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RksvEntryRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chainMeta = const VerificationMeta('chain');
  @override
  late final GeneratedColumn<int> chain = GeneratedColumn<int>(
    'chain',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES rksv_chains (chain)',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receiptIdMeta = const VerificationMeta(
    'receiptId',
  );
  @override
  late final GeneratedColumn<String> receiptId = GeneratedColumn<String>(
    'receipt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES receipts (id)',
    ),
  );
  static const VerificationMeta _jwsMeta = const VerificationMeta('jws');
  @override
  late final GeneratedColumn<String> jws = GeneratedColumn<String>(
    'jws',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _damagedMeta = const VerificationMeta(
    'damaged',
  );
  @override
  late final GeneratedColumn<bool> damaged = GeneratedColumn<bool>(
    'damaged',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("damaged" IN (0, 1))',
    ),
  );
  static const VerificationMeta _certSerialMeta = const VerificationMeta(
    'certSerial',
  );
  @override
  late final GeneratedColumn<String> certSerial = GeneratedColumn<String>(
    'cert_serial',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    chain,
    position,
    receiptId,
    jws,
    damaged,
    certSerial,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rksv_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<RksvEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chain')) {
      context.handle(
        _chainMeta,
        chain.isAcceptableOrUnknown(data['chain']!, _chainMeta),
      );
    } else if (isInserting) {
      context.missing(_chainMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('receipt_id')) {
      context.handle(
        _receiptIdMeta,
        receiptId.isAcceptableOrUnknown(data['receipt_id']!, _receiptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_receiptIdMeta);
    }
    if (data.containsKey('jws')) {
      context.handle(
        _jwsMeta,
        jws.isAcceptableOrUnknown(data['jws']!, _jwsMeta),
      );
    } else if (isInserting) {
      context.missing(_jwsMeta);
    }
    if (data.containsKey('damaged')) {
      context.handle(
        _damagedMeta,
        damaged.isAcceptableOrUnknown(data['damaged']!, _damagedMeta),
      );
    } else if (isInserting) {
      context.missing(_damagedMeta);
    }
    if (data.containsKey('cert_serial')) {
      context.handle(
        _certSerialMeta,
        certSerial.isAcceptableOrUnknown(data['cert_serial']!, _certSerialMeta),
      );
    } else if (isInserting) {
      context.missing(_certSerialMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chain, position};
  @override
  RksvEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RksvEntryRow(
      chain: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chain'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      receiptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_id'],
      )!,
      jws: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jws'],
      )!,
      damaged: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}damaged'],
      )!,
      certSerial: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cert_serial'],
      )!,
    );
  }

  @override
  $RksvEntryRowsTable createAlias(String alias) {
    return $RksvEntryRowsTable(attachedDatabase, alias);
  }
}

class RksvEntryRow extends DataClass implements Insertable<RksvEntryRow> {
  final int chain;

  /// Stelle in der Kette, lückenlos ab 1.
  final int position;
  final String receiptId;

  /// Kompakte JWS-Form.
  final String jws;

  /// Wahr, wenn die Signatur ausgefallen war.
  final bool damaged;
  final String certSerial;
  const RksvEntryRow({
    required this.chain,
    required this.position,
    required this.receiptId,
    required this.jws,
    required this.damaged,
    required this.certSerial,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chain'] = Variable<int>(chain);
    map['position'] = Variable<int>(position);
    map['receipt_id'] = Variable<String>(receiptId);
    map['jws'] = Variable<String>(jws);
    map['damaged'] = Variable<bool>(damaged);
    map['cert_serial'] = Variable<String>(certSerial);
    return map;
  }

  RksvEntryRowsCompanion toCompanion(bool nullToAbsent) {
    return RksvEntryRowsCompanion(
      chain: Value(chain),
      position: Value(position),
      receiptId: Value(receiptId),
      jws: Value(jws),
      damaged: Value(damaged),
      certSerial: Value(certSerial),
    );
  }

  factory RksvEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RksvEntryRow(
      chain: serializer.fromJson<int>(json['chain']),
      position: serializer.fromJson<int>(json['position']),
      receiptId: serializer.fromJson<String>(json['receiptId']),
      jws: serializer.fromJson<String>(json['jws']),
      damaged: serializer.fromJson<bool>(json['damaged']),
      certSerial: serializer.fromJson<String>(json['certSerial']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chain': serializer.toJson<int>(chain),
      'position': serializer.toJson<int>(position),
      'receiptId': serializer.toJson<String>(receiptId),
      'jws': serializer.toJson<String>(jws),
      'damaged': serializer.toJson<bool>(damaged),
      'certSerial': serializer.toJson<String>(certSerial),
    };
  }

  RksvEntryRow copyWith({
    int? chain,
    int? position,
    String? receiptId,
    String? jws,
    bool? damaged,
    String? certSerial,
  }) => RksvEntryRow(
    chain: chain ?? this.chain,
    position: position ?? this.position,
    receiptId: receiptId ?? this.receiptId,
    jws: jws ?? this.jws,
    damaged: damaged ?? this.damaged,
    certSerial: certSerial ?? this.certSerial,
  );
  RksvEntryRow copyWithCompanion(RksvEntryRowsCompanion data) {
    return RksvEntryRow(
      chain: data.chain.present ? data.chain.value : this.chain,
      position: data.position.present ? data.position.value : this.position,
      receiptId: data.receiptId.present ? data.receiptId.value : this.receiptId,
      jws: data.jws.present ? data.jws.value : this.jws,
      damaged: data.damaged.present ? data.damaged.value : this.damaged,
      certSerial: data.certSerial.present
          ? data.certSerial.value
          : this.certSerial,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RksvEntryRow(')
          ..write('chain: $chain, ')
          ..write('position: $position, ')
          ..write('receiptId: $receiptId, ')
          ..write('jws: $jws, ')
          ..write('damaged: $damaged, ')
          ..write('certSerial: $certSerial')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(chain, position, receiptId, jws, damaged, certSerial);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RksvEntryRow &&
          other.chain == this.chain &&
          other.position == this.position &&
          other.receiptId == this.receiptId &&
          other.jws == this.jws &&
          other.damaged == this.damaged &&
          other.certSerial == this.certSerial);
}

class RksvEntryRowsCompanion extends UpdateCompanion<RksvEntryRow> {
  final Value<int> chain;
  final Value<int> position;
  final Value<String> receiptId;
  final Value<String> jws;
  final Value<bool> damaged;
  final Value<String> certSerial;
  final Value<int> rowid;
  const RksvEntryRowsCompanion({
    this.chain = const Value.absent(),
    this.position = const Value.absent(),
    this.receiptId = const Value.absent(),
    this.jws = const Value.absent(),
    this.damaged = const Value.absent(),
    this.certSerial = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RksvEntryRowsCompanion.insert({
    required int chain,
    required int position,
    required String receiptId,
    required String jws,
    required bool damaged,
    required String certSerial,
    this.rowid = const Value.absent(),
  }) : chain = Value(chain),
       position = Value(position),
       receiptId = Value(receiptId),
       jws = Value(jws),
       damaged = Value(damaged),
       certSerial = Value(certSerial);
  static Insertable<RksvEntryRow> custom({
    Expression<int>? chain,
    Expression<int>? position,
    Expression<String>? receiptId,
    Expression<String>? jws,
    Expression<bool>? damaged,
    Expression<String>? certSerial,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chain != null) 'chain': chain,
      if (position != null) 'position': position,
      if (receiptId != null) 'receipt_id': receiptId,
      if (jws != null) 'jws': jws,
      if (damaged != null) 'damaged': damaged,
      if (certSerial != null) 'cert_serial': certSerial,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RksvEntryRowsCompanion copyWith({
    Value<int>? chain,
    Value<int>? position,
    Value<String>? receiptId,
    Value<String>? jws,
    Value<bool>? damaged,
    Value<String>? certSerial,
    Value<int>? rowid,
  }) {
    return RksvEntryRowsCompanion(
      chain: chain ?? this.chain,
      position: position ?? this.position,
      receiptId: receiptId ?? this.receiptId,
      jws: jws ?? this.jws,
      damaged: damaged ?? this.damaged,
      certSerial: certSerial ?? this.certSerial,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chain.present) {
      map['chain'] = Variable<int>(chain.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (receiptId.present) {
      map['receipt_id'] = Variable<String>(receiptId.value);
    }
    if (jws.present) {
      map['jws'] = Variable<String>(jws.value);
    }
    if (damaged.present) {
      map['damaged'] = Variable<bool>(damaged.value);
    }
    if (certSerial.present) {
      map['cert_serial'] = Variable<String>(certSerial.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RksvEntryRowsCompanion(')
          ..write('chain: $chain, ')
          ..write('position: $position, ')
          ..write('receiptId: $receiptId, ')
          ..write('jws: $jws, ')
          ..write('damaged: $damaged, ')
          ..write('certSerial: $certSerial, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RksvStateRowsTable extends RksvStateRows
    with TableInfo<$RksvStateRowsTable, RksvStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RksvStateRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('off'),
  );
  static const VerificationMeta _chainMeta = const VerificationMeta('chain');
  @override
  late final GeneratedColumn<int> chain = GeneratedColumn<int>(
    'chain',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _counterCentsMeta = const VerificationMeta(
    'counterCents',
  );
  @override
  late final GeneratedColumn<int> counterCents = GeneratedColumn<int>(
    'counter_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _outageSinceMeta = const VerificationMeta(
    'outageSince',
  );
  @override
  late final GeneratedColumn<DateTime> outageSince = GeneratedColumn<DateTime>(
    'outage_since',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outageReasonMeta = const VerificationMeta(
    'outageReason',
  );
  @override
  late final GeneratedColumn<String> outageReason = GeneratedColumn<String>(
    'outage_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tasksMeta = const VerificationMeta('tasks');
  @override
  late final GeneratedColumn<String> tasks = GeneratedColumn<String>(
    'tasks',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _noticeMeta = const VerificationMeta('notice');
  @override
  late final GeneratedColumn<String> notice = GeneratedColumn<String>(
    'notice',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mode,
    chain,
    counterCents,
    outageSince,
    outageReason,
    tasks,
    notice,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rksv_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<RksvStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('chain')) {
      context.handle(
        _chainMeta,
        chain.isAcceptableOrUnknown(data['chain']!, _chainMeta),
      );
    }
    if (data.containsKey('counter_cents')) {
      context.handle(
        _counterCentsMeta,
        counterCents.isAcceptableOrUnknown(
          data['counter_cents']!,
          _counterCentsMeta,
        ),
      );
    }
    if (data.containsKey('outage_since')) {
      context.handle(
        _outageSinceMeta,
        outageSince.isAcceptableOrUnknown(
          data['outage_since']!,
          _outageSinceMeta,
        ),
      );
    }
    if (data.containsKey('outage_reason')) {
      context.handle(
        _outageReasonMeta,
        outageReason.isAcceptableOrUnknown(
          data['outage_reason']!,
          _outageReasonMeta,
        ),
      );
    }
    if (data.containsKey('tasks')) {
      context.handle(
        _tasksMeta,
        tasks.isAcceptableOrUnknown(data['tasks']!, _tasksMeta),
      );
    }
    if (data.containsKey('notice')) {
      context.handle(
        _noticeMeta,
        notice.isAcceptableOrUnknown(data['notice']!, _noticeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RksvStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RksvStateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      chain: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chain'],
      ),
      counterCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}counter_cents'],
      )!,
      outageSince: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}outage_since'],
      ),
      outageReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outage_reason'],
      ),
      tasks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tasks'],
      )!,
      notice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notice'],
      ),
    );
  }

  @override
  $RksvStateRowsTable createAlias(String alias) {
    return $RksvStateRowsTable(attachedDatabase, alias);
  }
}

class RksvStateRow extends DataClass implements Insertable<RksvStateRow> {
  final int id;

  /// `off`, `probe` oder `live`.
  final String mode;

  /// Die laufende Kette, `null` ohne.
  final int? chain;
  final int counterCents;
  final DateTime? outageSince;
  final String? outageReason;

  /// Offene Aufgaben als JSON-Liste.
  final String tasks;
  final String? notice;
  const RksvStateRow({
    required this.id,
    required this.mode,
    this.chain,
    required this.counterCents,
    this.outageSince,
    this.outageReason,
    required this.tasks,
    this.notice,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['mode'] = Variable<String>(mode);
    if (!nullToAbsent || chain != null) {
      map['chain'] = Variable<int>(chain);
    }
    map['counter_cents'] = Variable<int>(counterCents);
    if (!nullToAbsent || outageSince != null) {
      map['outage_since'] = Variable<DateTime>(outageSince);
    }
    if (!nullToAbsent || outageReason != null) {
      map['outage_reason'] = Variable<String>(outageReason);
    }
    map['tasks'] = Variable<String>(tasks);
    if (!nullToAbsent || notice != null) {
      map['notice'] = Variable<String>(notice);
    }
    return map;
  }

  RksvStateRowsCompanion toCompanion(bool nullToAbsent) {
    return RksvStateRowsCompanion(
      id: Value(id),
      mode: Value(mode),
      chain: chain == null && nullToAbsent
          ? const Value.absent()
          : Value(chain),
      counterCents: Value(counterCents),
      outageSince: outageSince == null && nullToAbsent
          ? const Value.absent()
          : Value(outageSince),
      outageReason: outageReason == null && nullToAbsent
          ? const Value.absent()
          : Value(outageReason),
      tasks: Value(tasks),
      notice: notice == null && nullToAbsent
          ? const Value.absent()
          : Value(notice),
    );
  }

  factory RksvStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RksvStateRow(
      id: serializer.fromJson<int>(json['id']),
      mode: serializer.fromJson<String>(json['mode']),
      chain: serializer.fromJson<int?>(json['chain']),
      counterCents: serializer.fromJson<int>(json['counterCents']),
      outageSince: serializer.fromJson<DateTime?>(json['outageSince']),
      outageReason: serializer.fromJson<String?>(json['outageReason']),
      tasks: serializer.fromJson<String>(json['tasks']),
      notice: serializer.fromJson<String?>(json['notice']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mode': serializer.toJson<String>(mode),
      'chain': serializer.toJson<int?>(chain),
      'counterCents': serializer.toJson<int>(counterCents),
      'outageSince': serializer.toJson<DateTime?>(outageSince),
      'outageReason': serializer.toJson<String?>(outageReason),
      'tasks': serializer.toJson<String>(tasks),
      'notice': serializer.toJson<String?>(notice),
    };
  }

  RksvStateRow copyWith({
    int? id,
    String? mode,
    Value<int?> chain = const Value.absent(),
    int? counterCents,
    Value<DateTime?> outageSince = const Value.absent(),
    Value<String?> outageReason = const Value.absent(),
    String? tasks,
    Value<String?> notice = const Value.absent(),
  }) => RksvStateRow(
    id: id ?? this.id,
    mode: mode ?? this.mode,
    chain: chain.present ? chain.value : this.chain,
    counterCents: counterCents ?? this.counterCents,
    outageSince: outageSince.present ? outageSince.value : this.outageSince,
    outageReason: outageReason.present ? outageReason.value : this.outageReason,
    tasks: tasks ?? this.tasks,
    notice: notice.present ? notice.value : this.notice,
  );
  RksvStateRow copyWithCompanion(RksvStateRowsCompanion data) {
    return RksvStateRow(
      id: data.id.present ? data.id.value : this.id,
      mode: data.mode.present ? data.mode.value : this.mode,
      chain: data.chain.present ? data.chain.value : this.chain,
      counterCents: data.counterCents.present
          ? data.counterCents.value
          : this.counterCents,
      outageSince: data.outageSince.present
          ? data.outageSince.value
          : this.outageSince,
      outageReason: data.outageReason.present
          ? data.outageReason.value
          : this.outageReason,
      tasks: data.tasks.present ? data.tasks.value : this.tasks,
      notice: data.notice.present ? data.notice.value : this.notice,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RksvStateRow(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('chain: $chain, ')
          ..write('counterCents: $counterCents, ')
          ..write('outageSince: $outageSince, ')
          ..write('outageReason: $outageReason, ')
          ..write('tasks: $tasks, ')
          ..write('notice: $notice')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mode,
    chain,
    counterCents,
    outageSince,
    outageReason,
    tasks,
    notice,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RksvStateRow &&
          other.id == this.id &&
          other.mode == this.mode &&
          other.chain == this.chain &&
          other.counterCents == this.counterCents &&
          other.outageSince == this.outageSince &&
          other.outageReason == this.outageReason &&
          other.tasks == this.tasks &&
          other.notice == this.notice);
}

class RksvStateRowsCompanion extends UpdateCompanion<RksvStateRow> {
  final Value<int> id;
  final Value<String> mode;
  final Value<int?> chain;
  final Value<int> counterCents;
  final Value<DateTime?> outageSince;
  final Value<String?> outageReason;
  final Value<String> tasks;
  final Value<String?> notice;
  const RksvStateRowsCompanion({
    this.id = const Value.absent(),
    this.mode = const Value.absent(),
    this.chain = const Value.absent(),
    this.counterCents = const Value.absent(),
    this.outageSince = const Value.absent(),
    this.outageReason = const Value.absent(),
    this.tasks = const Value.absent(),
    this.notice = const Value.absent(),
  });
  RksvStateRowsCompanion.insert({
    this.id = const Value.absent(),
    this.mode = const Value.absent(),
    this.chain = const Value.absent(),
    this.counterCents = const Value.absent(),
    this.outageSince = const Value.absent(),
    this.outageReason = const Value.absent(),
    this.tasks = const Value.absent(),
    this.notice = const Value.absent(),
  });
  static Insertable<RksvStateRow> custom({
    Expression<int>? id,
    Expression<String>? mode,
    Expression<int>? chain,
    Expression<int>? counterCents,
    Expression<DateTime>? outageSince,
    Expression<String>? outageReason,
    Expression<String>? tasks,
    Expression<String>? notice,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mode != null) 'mode': mode,
      if (chain != null) 'chain': chain,
      if (counterCents != null) 'counter_cents': counterCents,
      if (outageSince != null) 'outage_since': outageSince,
      if (outageReason != null) 'outage_reason': outageReason,
      if (tasks != null) 'tasks': tasks,
      if (notice != null) 'notice': notice,
    });
  }

  RksvStateRowsCompanion copyWith({
    Value<int>? id,
    Value<String>? mode,
    Value<int?>? chain,
    Value<int>? counterCents,
    Value<DateTime?>? outageSince,
    Value<String?>? outageReason,
    Value<String>? tasks,
    Value<String?>? notice,
  }) {
    return RksvStateRowsCompanion(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      chain: chain ?? this.chain,
      counterCents: counterCents ?? this.counterCents,
      outageSince: outageSince ?? this.outageSince,
      outageReason: outageReason ?? this.outageReason,
      tasks: tasks ?? this.tasks,
      notice: notice ?? this.notice,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (chain.present) {
      map['chain'] = Variable<int>(chain.value);
    }
    if (counterCents.present) {
      map['counter_cents'] = Variable<int>(counterCents.value);
    }
    if (outageSince.present) {
      map['outage_since'] = Variable<DateTime>(outageSince.value);
    }
    if (outageReason.present) {
      map['outage_reason'] = Variable<String>(outageReason.value);
    }
    if (tasks.present) {
      map['tasks'] = Variable<String>(tasks.value);
    }
    if (notice.present) {
      map['notice'] = Variable<String>(notice.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RksvStateRowsCompanion(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('chain: $chain, ')
          ..write('counterCents: $counterCents, ')
          ..write('outageSince: $outageSince, ')
          ..write('outageReason: $outageReason, ')
          ..write('tasks: $tasks, ')
          ..write('notice: $notice')
          ..write(')'))
        .toString();
  }
}

class $OutboxRowsTable extends OutboxRows
    with TableInfo<$OutboxRowsTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refMeta = const VerificationMeta('ref');
  @override
  late final GeneratedColumn<String> ref = GeneratedColumn<String>(
    'ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldMeta = const VerificationMeta('field');
  @override
  late final GeneratedColumn<String> field = GeneratedColumn<String>(
    'field',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _changedAtMeta = const VerificationMeta(
    'changedAt',
  );
  @override
  late final GeneratedColumn<DateTime> changedAt = GeneratedColumn<DateTime>(
    'changed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revMeta = const VerificationMeta('rev');
  @override
  late final GeneratedColumn<int> rev = GeneratedColumn<int>(
    'rev',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    ref,
    field,
    value,
    changedAt,
    rev,
    state,
    reason,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('ref')) {
      context.handle(
        _refMeta,
        ref.isAcceptableOrUnknown(data['ref']!, _refMeta),
      );
    } else if (isInserting) {
      context.missing(_refMeta);
    }
    if (data.containsKey('field')) {
      context.handle(
        _fieldMeta,
        field.isAcceptableOrUnknown(data['field']!, _fieldMeta),
      );
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    }
    if (data.containsKey('rev')) {
      context.handle(
        _revMeta,
        rev.isAcceptableOrUnknown(data['rev']!, _revMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      ref: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref'],
      )!,
      field: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field'],
      ),
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      changedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}changed_at'],
      ),
      rev: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rev'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
    );
  }

  @override
  $OutboxRowsTable createAlias(String alias) {
    return $OutboxRowsTable(attachedDatabase, alias);
  }
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final int id;

  /// `receipt`, `day`, `cash_movement`, `item_change`, `report`,
  /// `rksv_certificate` oder `rksv_chain`.
  final String kind;

  /// Kennung der Sache (bei Artikel-Änderungen die Artikel-Kennung).
  final String ref;

  /// Nur bei Artikel-Änderungen: Feld, Wert als JSON und Zeitpunkt.
  final String? field;
  final String? value;
  final DateTime? changedAt;

  /// Zählt hoch, wenn sich die Sache ändert, solange der Eintrag wartet.
  final int rev;

  /// `pending` oder `rejected`.
  final String state;
  final String? reason;
  const OutboxRow({
    required this.id,
    required this.kind,
    required this.ref,
    this.field,
    this.value,
    this.changedAt,
    required this.rev,
    required this.state,
    this.reason,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['ref'] = Variable<String>(ref);
    if (!nullToAbsent || field != null) {
      map['field'] = Variable<String>(field);
    }
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    if (!nullToAbsent || changedAt != null) {
      map['changed_at'] = Variable<DateTime>(changedAt);
    }
    map['rev'] = Variable<int>(rev);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    return map;
  }

  OutboxRowsCompanion toCompanion(bool nullToAbsent) {
    return OutboxRowsCompanion(
      id: Value(id),
      kind: Value(kind),
      ref: Value(ref),
      field: field == null && nullToAbsent
          ? const Value.absent()
          : Value(field),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      changedAt: changedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(changedAt),
      rev: Value(rev),
      state: Value(state),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      ref: serializer.fromJson<String>(json['ref']),
      field: serializer.fromJson<String?>(json['field']),
      value: serializer.fromJson<String?>(json['value']),
      changedAt: serializer.fromJson<DateTime?>(json['changedAt']),
      rev: serializer.fromJson<int>(json['rev']),
      state: serializer.fromJson<String>(json['state']),
      reason: serializer.fromJson<String?>(json['reason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'ref': serializer.toJson<String>(ref),
      'field': serializer.toJson<String?>(field),
      'value': serializer.toJson<String?>(value),
      'changedAt': serializer.toJson<DateTime?>(changedAt),
      'rev': serializer.toJson<int>(rev),
      'state': serializer.toJson<String>(state),
      'reason': serializer.toJson<String?>(reason),
    };
  }

  OutboxRow copyWith({
    int? id,
    String? kind,
    String? ref,
    Value<String?> field = const Value.absent(),
    Value<String?> value = const Value.absent(),
    Value<DateTime?> changedAt = const Value.absent(),
    int? rev,
    String? state,
    Value<String?> reason = const Value.absent(),
  }) => OutboxRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    ref: ref ?? this.ref,
    field: field.present ? field.value : this.field,
    value: value.present ? value.value : this.value,
    changedAt: changedAt.present ? changedAt.value : this.changedAt,
    rev: rev ?? this.rev,
    state: state ?? this.state,
    reason: reason.present ? reason.value : this.reason,
  );
  OutboxRow copyWithCompanion(OutboxRowsCompanion data) {
    return OutboxRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      ref: data.ref.present ? data.ref.value : this.ref,
      field: data.field.present ? data.field.value : this.field,
      value: data.value.present ? data.value.value : this.value,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
      rev: data.rev.present ? data.rev.value : this.rev,
      state: data.state.present ? data.state.value : this.state,
      reason: data.reason.present ? data.reason.value : this.reason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('ref: $ref, ')
          ..write('field: $field, ')
          ..write('value: $value, ')
          ..write('changedAt: $changedAt, ')
          ..write('rev: $rev, ')
          ..write('state: $state, ')
          ..write('reason: $reason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, kind, ref, field, value, changedAt, rev, state, reason);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.ref == this.ref &&
          other.field == this.field &&
          other.value == this.value &&
          other.changedAt == this.changedAt &&
          other.rev == this.rev &&
          other.state == this.state &&
          other.reason == this.reason);
}

class OutboxRowsCompanion extends UpdateCompanion<OutboxRow> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> ref;
  final Value<String?> field;
  final Value<String?> value;
  final Value<DateTime?> changedAt;
  final Value<int> rev;
  final Value<String> state;
  final Value<String?> reason;
  const OutboxRowsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.ref = const Value.absent(),
    this.field = const Value.absent(),
    this.value = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.rev = const Value.absent(),
    this.state = const Value.absent(),
    this.reason = const Value.absent(),
  });
  OutboxRowsCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String ref,
    this.field = const Value.absent(),
    this.value = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.rev = const Value.absent(),
    this.state = const Value.absent(),
    this.reason = const Value.absent(),
  }) : kind = Value(kind),
       ref = Value(ref);
  static Insertable<OutboxRow> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? ref,
    Expression<String>? field,
    Expression<String>? value,
    Expression<DateTime>? changedAt,
    Expression<int>? rev,
    Expression<String>? state,
    Expression<String>? reason,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (ref != null) 'ref': ref,
      if (field != null) 'field': field,
      if (value != null) 'value': value,
      if (changedAt != null) 'changed_at': changedAt,
      if (rev != null) 'rev': rev,
      if (state != null) 'state': state,
      if (reason != null) 'reason': reason,
    });
  }

  OutboxRowsCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String>? ref,
    Value<String?>? field,
    Value<String?>? value,
    Value<DateTime?>? changedAt,
    Value<int>? rev,
    Value<String>? state,
    Value<String?>? reason,
  }) {
    return OutboxRowsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      ref: ref ?? this.ref,
      field: field ?? this.field,
      value: value ?? this.value,
      changedAt: changedAt ?? this.changedAt,
      rev: rev ?? this.rev,
      state: state ?? this.state,
      reason: reason ?? this.reason,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (ref.present) {
      map['ref'] = Variable<String>(ref.value);
    }
    if (field.present) {
      map['field'] = Variable<String>(field.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (changedAt.present) {
      map['changed_at'] = Variable<DateTime>(changedAt.value);
    }
    if (rev.present) {
      map['rev'] = Variable<int>(rev.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRowsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('ref: $ref, ')
          ..write('field: $field, ')
          ..write('value: $value, ')
          ..write('changedAt: $changedAt, ')
          ..write('rev: $rev, ')
          ..write('state: $state, ')
          ..write('reason: $reason')
          ..write(')'))
        .toString();
  }
}

class $ReportRowsTable extends ReportRows
    with TableInfo<$ReportRowsTable, ReportRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReportRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appVersionMeta = const VerificationMeta(
    'appVersion',
  );
  @override
  late final GeneratedColumn<String> appVersion = GeneratedColumn<String>(
    'app_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _androidVersionMeta = const VerificationMeta(
    'androidVersion',
  );
  @override
  late final GeneratedColumn<String> androidVersion = GeneratedColumn<String>(
    'android_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceModelMeta = const VerificationMeta(
    'deviceModel',
  );
  @override
  late final GeneratedColumn<String> deviceModel = GeneratedColumn<String>(
    'device_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _signatureMeta = const VerificationMeta(
    'signature',
  );
  @override
  late final GeneratedColumn<String> signature = GeneratedColumn<String>(
    'signature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    at,
    appVersion,
    androidVersion,
    deviceModel,
    count,
    signature,
    content,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reports';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReportRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('app_version')) {
      context.handle(
        _appVersionMeta,
        appVersion.isAcceptableOrUnknown(data['app_version']!, _appVersionMeta),
      );
    } else if (isInserting) {
      context.missing(_appVersionMeta);
    }
    if (data.containsKey('android_version')) {
      context.handle(
        _androidVersionMeta,
        androidVersion.isAcceptableOrUnknown(
          data['android_version']!,
          _androidVersionMeta,
        ),
      );
    }
    if (data.containsKey('device_model')) {
      context.handle(
        _deviceModelMeta,
        deviceModel.isAcceptableOrUnknown(
          data['device_model']!,
          _deviceModelMeta,
        ),
      );
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    }
    if (data.containsKey('signature')) {
      context.handle(
        _signatureMeta,
        signature.isAcceptableOrUnknown(data['signature']!, _signatureMeta),
      );
    } else if (isInserting) {
      context.missing(_signatureMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReportRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReportRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
      appVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}app_version'],
      )!,
      androidVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}android_version'],
      ),
      deviceModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_model'],
      ),
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
      signature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signature'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
    );
  }

  @override
  $ReportRowsTable createAlias(String alias) {
    return $ReportRowsTable(attachedDatabase, alias);
  }
}

class ReportRow extends DataClass implements Insertable<ReportRow> {
  final String id;

  /// `error` oder `device_test`.
  final String kind;
  final DateTime at;
  final String appVersion;
  final String? androidVersion;
  final String? deviceModel;

  /// Wie oft derselbe Fehler (gleiche `signature`) aufgetreten ist.
  final int count;
  final String signature;

  /// Inhalt als JSON.
  final String content;
  const ReportRow({
    required this.id,
    required this.kind,
    required this.at,
    required this.appVersion,
    this.androidVersion,
    this.deviceModel,
    required this.count,
    required this.signature,
    required this.content,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['at'] = Variable<DateTime>(at);
    map['app_version'] = Variable<String>(appVersion);
    if (!nullToAbsent || androidVersion != null) {
      map['android_version'] = Variable<String>(androidVersion);
    }
    if (!nullToAbsent || deviceModel != null) {
      map['device_model'] = Variable<String>(deviceModel);
    }
    map['count'] = Variable<int>(count);
    map['signature'] = Variable<String>(signature);
    map['content'] = Variable<String>(content);
    return map;
  }

  ReportRowsCompanion toCompanion(bool nullToAbsent) {
    return ReportRowsCompanion(
      id: Value(id),
      kind: Value(kind),
      at: Value(at),
      appVersion: Value(appVersion),
      androidVersion: androidVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(androidVersion),
      deviceModel: deviceModel == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceModel),
      count: Value(count),
      signature: Value(signature),
      content: Value(content),
    );
  }

  factory ReportRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReportRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      at: serializer.fromJson<DateTime>(json['at']),
      appVersion: serializer.fromJson<String>(json['appVersion']),
      androidVersion: serializer.fromJson<String?>(json['androidVersion']),
      deviceModel: serializer.fromJson<String?>(json['deviceModel']),
      count: serializer.fromJson<int>(json['count']),
      signature: serializer.fromJson<String>(json['signature']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'at': serializer.toJson<DateTime>(at),
      'appVersion': serializer.toJson<String>(appVersion),
      'androidVersion': serializer.toJson<String?>(androidVersion),
      'deviceModel': serializer.toJson<String?>(deviceModel),
      'count': serializer.toJson<int>(count),
      'signature': serializer.toJson<String>(signature),
      'content': serializer.toJson<String>(content),
    };
  }

  ReportRow copyWith({
    String? id,
    String? kind,
    DateTime? at,
    String? appVersion,
    Value<String?> androidVersion = const Value.absent(),
    Value<String?> deviceModel = const Value.absent(),
    int? count,
    String? signature,
    String? content,
  }) => ReportRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    at: at ?? this.at,
    appVersion: appVersion ?? this.appVersion,
    androidVersion: androidVersion.present
        ? androidVersion.value
        : this.androidVersion,
    deviceModel: deviceModel.present ? deviceModel.value : this.deviceModel,
    count: count ?? this.count,
    signature: signature ?? this.signature,
    content: content ?? this.content,
  );
  ReportRow copyWithCompanion(ReportRowsCompanion data) {
    return ReportRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      at: data.at.present ? data.at.value : this.at,
      appVersion: data.appVersion.present
          ? data.appVersion.value
          : this.appVersion,
      androidVersion: data.androidVersion.present
          ? data.androidVersion.value
          : this.androidVersion,
      deviceModel: data.deviceModel.present
          ? data.deviceModel.value
          : this.deviceModel,
      count: data.count.present ? data.count.value : this.count,
      signature: data.signature.present ? data.signature.value : this.signature,
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReportRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('at: $at, ')
          ..write('appVersion: $appVersion, ')
          ..write('androidVersion: $androidVersion, ')
          ..write('deviceModel: $deviceModel, ')
          ..write('count: $count, ')
          ..write('signature: $signature, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    at,
    appVersion,
    androidVersion,
    deviceModel,
    count,
    signature,
    content,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReportRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.at == this.at &&
          other.appVersion == this.appVersion &&
          other.androidVersion == this.androidVersion &&
          other.deviceModel == this.deviceModel &&
          other.count == this.count &&
          other.signature == this.signature &&
          other.content == this.content);
}

class ReportRowsCompanion extends UpdateCompanion<ReportRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<DateTime> at;
  final Value<String> appVersion;
  final Value<String?> androidVersion;
  final Value<String?> deviceModel;
  final Value<int> count;
  final Value<String> signature;
  final Value<String> content;
  final Value<int> rowid;
  const ReportRowsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.at = const Value.absent(),
    this.appVersion = const Value.absent(),
    this.androidVersion = const Value.absent(),
    this.deviceModel = const Value.absent(),
    this.count = const Value.absent(),
    this.signature = const Value.absent(),
    this.content = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReportRowsCompanion.insert({
    required String id,
    required String kind,
    required DateTime at,
    required String appVersion,
    this.androidVersion = const Value.absent(),
    this.deviceModel = const Value.absent(),
    this.count = const Value.absent(),
    required String signature,
    required String content,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       at = Value(at),
       appVersion = Value(appVersion),
       signature = Value(signature),
       content = Value(content);
  static Insertable<ReportRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<DateTime>? at,
    Expression<String>? appVersion,
    Expression<String>? androidVersion,
    Expression<String>? deviceModel,
    Expression<int>? count,
    Expression<String>? signature,
    Expression<String>? content,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (at != null) 'at': at,
      if (appVersion != null) 'app_version': appVersion,
      if (androidVersion != null) 'android_version': androidVersion,
      if (deviceModel != null) 'device_model': deviceModel,
      if (count != null) 'count': count,
      if (signature != null) 'signature': signature,
      if (content != null) 'content': content,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReportRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<DateTime>? at,
    Value<String>? appVersion,
    Value<String?>? androidVersion,
    Value<String?>? deviceModel,
    Value<int>? count,
    Value<String>? signature,
    Value<String>? content,
    Value<int>? rowid,
  }) {
    return ReportRowsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      at: at ?? this.at,
      appVersion: appVersion ?? this.appVersion,
      androidVersion: androidVersion ?? this.androidVersion,
      deviceModel: deviceModel ?? this.deviceModel,
      count: count ?? this.count,
      signature: signature ?? this.signature,
      content: content ?? this.content,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (appVersion.present) {
      map['app_version'] = Variable<String>(appVersion.value);
    }
    if (androidVersion.present) {
      map['android_version'] = Variable<String>(androidVersion.value);
    }
    if (deviceModel.present) {
      map['device_model'] = Variable<String>(deviceModel.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (signature.present) {
      map['signature'] = Variable<String>(signature.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReportRowsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('at: $at, ')
          ..write('appVersion: $appVersion, ')
          ..write('androidVersion: $androidVersion, ')
          ..write('deviceModel: $deviceModel, ')
          ..write('count: $count, ')
          ..write('signature: $signature, ')
          ..write('content: $content, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$KassaDatabase extends GeneratedDatabase {
  _$KassaDatabase(QueryExecutor e) : super(e);
  $KassaDatabaseManager get managers => $KassaDatabaseManager(this);
  late final $BusinessRowsTable businessRows = $BusinessRowsTable(this);
  late final $CategoryRowsTable categoryRows = $CategoryRowsTable(this);
  late final $ItemRowsTable itemRows = $ItemRowsTable(this);
  late final $ModifierTemplateRowsTable modifierTemplateRows =
      $ModifierTemplateRowsTable(this);
  late final $ModifierGroupRowsTable modifierGroupRows =
      $ModifierGroupRowsTable(this);
  late final $ModifierOptionRowsTable modifierOptionRows =
      $ModifierOptionRowsTable(this);
  late final $StaffRowsTable staffRows = $StaffRowsTable(this);
  late final $SettingsRowsTable settingsRows = $SettingsRowsTable(this);
  late final $TranslationRowsTable translationRows = $TranslationRowsTable(
    this,
  );
  late final $BusinessDayRowsTable businessDayRows = $BusinessDayRowsTable(
    this,
  );
  late final $CashMovementRowsTable cashMovementRows = $CashMovementRowsTable(
    this,
  );
  late final $ReceiptRowsTable receiptRows = $ReceiptRowsTable(this);
  late final $ReceiptLineRowsTable receiptLineRows = $ReceiptLineRowsTable(
    this,
  );
  late final $ReceiptLineOptionRowsTable receiptLineOptionRows =
      $ReceiptLineOptionRowsTable(this);
  late final $PaymentRowsTable paymentRows = $PaymentRowsTable(this);
  late final $PendingCardPaymentRowsTable pendingCardPaymentRows =
      $PendingCardPaymentRowsTable(this);
  late final $SyncStateRowsTable syncStateRows = $SyncStateRowsTable(this);
  late final $RksvCertificateRowsTable rksvCertificateRows =
      $RksvCertificateRowsTable(this);
  late final $RksvChainRowsTable rksvChainRows = $RksvChainRowsTable(this);
  late final $RksvEntryRowsTable rksvEntryRows = $RksvEntryRowsTable(this);
  late final $RksvStateRowsTable rksvStateRows = $RksvStateRowsTable(this);
  late final $OutboxRowsTable outboxRows = $OutboxRowsTable(this);
  late final $ReportRowsTable reportRows = $ReportRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    businessRows,
    categoryRows,
    itemRows,
    modifierTemplateRows,
    modifierGroupRows,
    modifierOptionRows,
    staffRows,
    settingsRows,
    translationRows,
    businessDayRows,
    cashMovementRows,
    receiptRows,
    receiptLineRows,
    receiptLineOptionRows,
    paymentRows,
    pendingCardPaymentRows,
    syncStateRows,
    rksvCertificateRows,
    rksvChainRows,
    rksvEntryRows,
    rksvStateRows,
    outboxRows,
    reportRows,
  ];
}

typedef $$BusinessRowsTableCreateCompanionBuilder =
    BusinessRowsCompanion Function({
      Value<int> id,
      required String name,
      Value<String> addressLines,
      Value<String?> vatId,
      Value<String?> receiptFooter,
      Value<String?> logoFileId,
      Value<String?> logoPath,
      Value<String?> logoColor,
    });
typedef $$BusinessRowsTableUpdateCompanionBuilder =
    BusinessRowsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> addressLines,
      Value<String?> vatId,
      Value<String?> receiptFooter,
      Value<String?> logoFileId,
      Value<String?> logoPath,
      Value<String?> logoColor,
    });

class $$BusinessRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $BusinessRowsTable> {
  $$BusinessRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addressLines => $composableBuilder(
    column: $table.addressLines,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vatId => $composableBuilder(
    column: $table.vatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptFooter => $composableBuilder(
    column: $table.receiptFooter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logoFileId => $composableBuilder(
    column: $table.logoFileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logoPath => $composableBuilder(
    column: $table.logoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logoColor => $composableBuilder(
    column: $table.logoColor,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BusinessRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $BusinessRowsTable> {
  $$BusinessRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addressLines => $composableBuilder(
    column: $table.addressLines,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vatId => $composableBuilder(
    column: $table.vatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptFooter => $composableBuilder(
    column: $table.receiptFooter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logoFileId => $composableBuilder(
    column: $table.logoFileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logoPath => $composableBuilder(
    column: $table.logoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logoColor => $composableBuilder(
    column: $table.logoColor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BusinessRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $BusinessRowsTable> {
  $$BusinessRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get addressLines => $composableBuilder(
    column: $table.addressLines,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vatId =>
      $composableBuilder(column: $table.vatId, builder: (column) => column);

  GeneratedColumn<String> get receiptFooter => $composableBuilder(
    column: $table.receiptFooter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get logoFileId => $composableBuilder(
    column: $table.logoFileId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get logoPath =>
      $composableBuilder(column: $table.logoPath, builder: (column) => column);

  GeneratedColumn<String> get logoColor =>
      $composableBuilder(column: $table.logoColor, builder: (column) => column);
}

class $$BusinessRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $BusinessRowsTable,
          BusinessRow,
          $$BusinessRowsTableFilterComposer,
          $$BusinessRowsTableOrderingComposer,
          $$BusinessRowsTableAnnotationComposer,
          $$BusinessRowsTableCreateCompanionBuilder,
          $$BusinessRowsTableUpdateCompanionBuilder,
          (
            BusinessRow,
            BaseReferences<_$KassaDatabase, $BusinessRowsTable, BusinessRow>,
          ),
          BusinessRow,
          PrefetchHooks Function()
        > {
  $$BusinessRowsTableTableManager(_$KassaDatabase db, $BusinessRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BusinessRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BusinessRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BusinessRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> addressLines = const Value.absent(),
                Value<String?> vatId = const Value.absent(),
                Value<String?> receiptFooter = const Value.absent(),
                Value<String?> logoFileId = const Value.absent(),
                Value<String?> logoPath = const Value.absent(),
                Value<String?> logoColor = const Value.absent(),
              }) => BusinessRowsCompanion(
                id: id,
                name: name,
                addressLines: addressLines,
                vatId: vatId,
                receiptFooter: receiptFooter,
                logoFileId: logoFileId,
                logoPath: logoPath,
                logoColor: logoColor,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> addressLines = const Value.absent(),
                Value<String?> vatId = const Value.absent(),
                Value<String?> receiptFooter = const Value.absent(),
                Value<String?> logoFileId = const Value.absent(),
                Value<String?> logoPath = const Value.absent(),
                Value<String?> logoColor = const Value.absent(),
              }) => BusinessRowsCompanion.insert(
                id: id,
                name: name,
                addressLines: addressLines,
                vatId: vatId,
                receiptFooter: receiptFooter,
                logoFileId: logoFileId,
                logoPath: logoPath,
                logoColor: logoColor,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BusinessRowsTable, BusinessRow>(table),
                  BaseReferences<
                    _$KassaDatabase,
                    $BusinessRowsTable,
                    BusinessRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BusinessRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $BusinessRowsTable,
      BusinessRow,
      $$BusinessRowsTableFilterComposer,
      $$BusinessRowsTableOrderingComposer,
      $$BusinessRowsTableAnnotationComposer,
      $$BusinessRowsTableCreateCompanionBuilder,
      $$BusinessRowsTableUpdateCompanionBuilder,
      (
        BusinessRow,
        BaseReferences<_$KassaDatabase, $BusinessRowsTable, BusinessRow>,
      ),
      BusinessRow,
      PrefetchHooks Function()
    >;
typedef $$CategoryRowsTableCreateCompanionBuilder =
    CategoryRowsCompanion Function({
      required String id,
      required String name,
      required int position,
      Value<bool> archived,
      Value<int> rowid,
    });
typedef $$CategoryRowsTableUpdateCompanionBuilder =
    CategoryRowsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> position,
      Value<bool> archived,
      Value<int> rowid,
    });

final class $$CategoryRowsTableReferences
    extends BaseReferences<_$KassaDatabase, $CategoryRowsTable, CategoryRow> {
  $$CategoryRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ItemRowsTable, List<ItemRow>> _itemRowsRefsTable(
    _$KassaDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.itemRows,
    aliasName: 'categories__id__items__category_id',
  );

  $$ItemRowsTableProcessedTableManager get itemRowsRefs {
    final manager = $$ItemRowsTableTableManager(
      $_db,
      $_db.itemRows,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_itemRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoryRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $CategoryRowsTable> {
  $$CategoryRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> itemRowsRefs(
    Expression<bool> Function($$ItemRowsTableFilterComposer f) f,
  ) {
    final $$ItemRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemRows,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemRowsTableFilterComposer(
            $db: $db,
            $table: $db.itemRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoryRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $CategoryRowsTable> {
  $$CategoryRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoryRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $CategoryRowsTable> {
  $$CategoryRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  Expression<T> itemRowsRefs<T extends Object>(
    Expression<T> Function($$ItemRowsTableAnnotationComposer a) f,
  ) {
    final $$ItemRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemRows,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.itemRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoryRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $CategoryRowsTable,
          CategoryRow,
          $$CategoryRowsTableFilterComposer,
          $$CategoryRowsTableOrderingComposer,
          $$CategoryRowsTableAnnotationComposer,
          $$CategoryRowsTableCreateCompanionBuilder,
          $$CategoryRowsTableUpdateCompanionBuilder,
          (CategoryRow, $$CategoryRowsTableReferences),
          CategoryRow,
          PrefetchHooks Function({bool itemRowsRefs})
        > {
  $$CategoryRowsTableTableManager(_$KassaDatabase db, $CategoryRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryRowsCompanion(
                id: id,
                name: name,
                position: position,
                archived: archived,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int position,
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryRowsCompanion.insert(
                id: id,
                name: name,
                position: position,
                archived: archived,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoryRowsTable, CategoryRow>(table),
                  $$CategoryRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemRowsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (itemRowsRefs) db.itemRows],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (itemRowsRefs)
                    await $_getPrefetchedDataByColumns<
                      CategoryRow,
                      $CategoryRowsTable,
                      ItemRow,
                      $ItemRowsTable
                    >(
                      currentTable: table,
                      referencedTable: $$CategoryRowsTableReferences
                          ._itemRowsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CategoryRowsTableReferences(
                            db,
                            table,
                            p0,
                          ).itemRowsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'category_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CategoryRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $CategoryRowsTable,
      CategoryRow,
      $$CategoryRowsTableFilterComposer,
      $$CategoryRowsTableOrderingComposer,
      $$CategoryRowsTableAnnotationComposer,
      $$CategoryRowsTableCreateCompanionBuilder,
      $$CategoryRowsTableUpdateCompanionBuilder,
      (CategoryRow, $$CategoryRowsTableReferences),
      CategoryRow,
      PrefetchHooks Function({bool itemRowsRefs})
    >;
typedef $$ItemRowsTableCreateCompanionBuilder = ItemRowsCompanion Function({
  required String id,
  required String name,
  required int priceCents,
  required String categoryId,
  required int taxPercent,
  Value<int> depositCents,
  Value<String> tags,
  Value<String?> info,
  Value<String?> templateId,
  Value<bool> favorite,
  Value<bool> inSale,
  Value<String?> photoPath,
  Value<String?> photoFileId,
  Value<String?> photoColor,
  required int position,
  Value<bool> archived,
  Value<int> rowid,
});
typedef $$ItemRowsTableUpdateCompanionBuilder = ItemRowsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> priceCents,
  Value<String> categoryId,
  Value<int> taxPercent,
  Value<int> depositCents,
  Value<String> tags,
  Value<String?> info,
  Value<String?> templateId,
  Value<bool> favorite,
  Value<bool> inSale,
  Value<String?> photoPath,
  Value<String?> photoFileId,
  Value<String?> photoColor,
  Value<int> position,
  Value<bool> archived,
  Value<int> rowid,
});

final class $$ItemRowsTableReferences
    extends BaseReferences<_$KassaDatabase, $ItemRowsTable, ItemRow> {
  $$ItemRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoryRowsTable _categoryIdTable(_$KassaDatabase db) =>
      db.categoryRows.createAlias('items__category_id__categories__id');

  $$CategoryRowsTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoryRowsTableTableManager(
      $_db,
      $_db.categoryRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ItemRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $ItemRowsTable> {
  $$ItemRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priceCents => $composableBuilder(
    column: $table.priceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taxPercent => $composableBuilder(
    column: $table.taxPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get depositCents => $composableBuilder(
    column: $table.depositCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get info => $composableBuilder(
    column: $table.info,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get inSale => $composableBuilder(
    column: $table.inSale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoFileId => $composableBuilder(
    column: $table.photoFileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoColor => $composableBuilder(
    column: $table.photoColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoryRowsTableFilterComposer get categoryId {
    final $$CategoryRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categoryRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryRowsTableFilterComposer(
            $db: $db,
            $table: $db.categoryRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $ItemRowsTable> {
  $$ItemRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priceCents => $composableBuilder(
    column: $table.priceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taxPercent => $composableBuilder(
    column: $table.taxPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get depositCents => $composableBuilder(
    column: $table.depositCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get info => $composableBuilder(
    column: $table.info,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get inSale => $composableBuilder(
    column: $table.inSale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoFileId => $composableBuilder(
    column: $table.photoFileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoColor => $composableBuilder(
    column: $table.photoColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoryRowsTableOrderingComposer get categoryId {
    final $$CategoryRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categoryRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryRowsTableOrderingComposer(
            $db: $db,
            $table: $db.categoryRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $ItemRowsTable> {
  $$ItemRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get priceCents => $composableBuilder(
    column: $table.priceCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get taxPercent => $composableBuilder(
    column: $table.taxPercent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get depositCents => $composableBuilder(
    column: $table.depositCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get info =>
      $composableBuilder(column: $table.info, builder: (column) => column);

  GeneratedColumn<String> get templateId => $composableBuilder(
    column: $table.templateId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get favorite =>
      $composableBuilder(column: $table.favorite, builder: (column) => column);

  GeneratedColumn<bool> get inSale =>
      $composableBuilder(column: $table.inSale, builder: (column) => column);

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<String> get photoFileId => $composableBuilder(
    column: $table.photoFileId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoColor => $composableBuilder(
    column: $table.photoColor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  $$CategoryRowsTableAnnotationComposer get categoryId {
    final $$CategoryRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categoryRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $ItemRowsTable,
          ItemRow,
          $$ItemRowsTableFilterComposer,
          $$ItemRowsTableOrderingComposer,
          $$ItemRowsTableAnnotationComposer,
          $$ItemRowsTableCreateCompanionBuilder,
          $$ItemRowsTableUpdateCompanionBuilder,
          (ItemRow, $$ItemRowsTableReferences),
          ItemRow,
          PrefetchHooks Function({bool categoryId})
        > {
  $$ItemRowsTableTableManager(_$KassaDatabase db, $ItemRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> priceCents = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<int> taxPercent = const Value.absent(),
                Value<int> depositCents = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String?> info = const Value.absent(),
                Value<String?> templateId = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<bool> inSale = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<String?> photoFileId = const Value.absent(),
                Value<String?> photoColor = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemRowsCompanion(
                id: id,
                name: name,
                priceCents: priceCents,
                categoryId: categoryId,
                taxPercent: taxPercent,
                depositCents: depositCents,
                tags: tags,
                info: info,
                templateId: templateId,
                favorite: favorite,
                inSale: inSale,
                photoPath: photoPath,
                photoFileId: photoFileId,
                photoColor: photoColor,
                position: position,
                archived: archived,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int priceCents,
                required String categoryId,
                required int taxPercent,
                Value<int> depositCents = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String?> info = const Value.absent(),
                Value<String?> templateId = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<bool> inSale = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<String?> photoFileId = const Value.absent(),
                Value<String?> photoColor = const Value.absent(),
                required int position,
                Value<bool> archived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemRowsCompanion.insert(
                id: id,
                name: name,
                priceCents: priceCents,
                categoryId: categoryId,
                taxPercent: taxPercent,
                depositCents: depositCents,
                tags: tags,
                info: info,
                templateId: templateId,
                favorite: favorite,
                inSale: inSale,
                photoPath: photoPath,
                photoFileId: photoFileId,
                photoColor: photoColor,
                position: position,
                archived: archived,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ItemRowsTable, ItemRow>(table),
                  $$ItemRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$ItemRowsTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$ItemRowsTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ItemRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $ItemRowsTable,
      ItemRow,
      $$ItemRowsTableFilterComposer,
      $$ItemRowsTableOrderingComposer,
      $$ItemRowsTableAnnotationComposer,
      $$ItemRowsTableCreateCompanionBuilder,
      $$ItemRowsTableUpdateCompanionBuilder,
      (ItemRow, $$ItemRowsTableReferences),
      ItemRow,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$ModifierTemplateRowsTableCreateCompanionBuilder =
    ModifierTemplateRowsCompanion Function({
      required String id,
      required String name,
      required int position,
      Value<int> rowid,
    });
typedef $$ModifierTemplateRowsTableUpdateCompanionBuilder =
    ModifierTemplateRowsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> position,
      Value<int> rowid,
    });

final class $$ModifierTemplateRowsTableReferences
    extends
        BaseReferences<
          _$KassaDatabase,
          $ModifierTemplateRowsTable,
          ModifierTemplateRow
        > {
  $$ModifierTemplateRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ModifierGroupRowsTable, List<ModifierGroupRow>>
  _modifierGroupRowsRefsTable(_$KassaDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.modifierGroupRows,
        aliasName: 'modifier_templates__id__modifier_groups__template_id',
      );

  $$ModifierGroupRowsTableProcessedTableManager get modifierGroupRowsRefs {
    final manager = $$ModifierGroupRowsTableTableManager(
      $_db,
      $_db.modifierGroupRows,
    ).filter((f) => f.templateId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _modifierGroupRowsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ModifierTemplateRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $ModifierTemplateRowsTable> {
  $$ModifierTemplateRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> modifierGroupRowsRefs(
    Expression<bool> Function($$ModifierGroupRowsTableFilterComposer f) f,
  ) {
    final $$ModifierGroupRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.modifierGroupRows,
      getReferencedColumn: (t) => t.templateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModifierGroupRowsTableFilterComposer(
            $db: $db,
            $table: $db.modifierGroupRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ModifierTemplateRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $ModifierTemplateRowsTable> {
  $$ModifierTemplateRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ModifierTemplateRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $ModifierTemplateRowsTable> {
  $$ModifierTemplateRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  Expression<T> modifierGroupRowsRefs<T extends Object>(
    Expression<T> Function($$ModifierGroupRowsTableAnnotationComposer a) f,
  ) {
    final $$ModifierGroupRowsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.modifierGroupRows,
          getReferencedColumn: (t) => t.templateId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ModifierGroupRowsTableAnnotationComposer(
                $db: $db,
                $table: $db.modifierGroupRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ModifierTemplateRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $ModifierTemplateRowsTable,
          ModifierTemplateRow,
          $$ModifierTemplateRowsTableFilterComposer,
          $$ModifierTemplateRowsTableOrderingComposer,
          $$ModifierTemplateRowsTableAnnotationComposer,
          $$ModifierTemplateRowsTableCreateCompanionBuilder,
          $$ModifierTemplateRowsTableUpdateCompanionBuilder,
          (ModifierTemplateRow, $$ModifierTemplateRowsTableReferences),
          ModifierTemplateRow,
          PrefetchHooks Function({bool modifierGroupRowsRefs})
        > {
  $$ModifierTemplateRowsTableTableManager(
    _$KassaDatabase db,
    $ModifierTemplateRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModifierTemplateRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModifierTemplateRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ModifierTemplateRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModifierTemplateRowsCompanion(
                id: id,
                name: name,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => ModifierTemplateRowsCompanion.insert(
                id: id,
                name: name,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModifierTemplateRowsTable, ModifierTemplateRow>(
                    table,
                  ),
                  $$ModifierTemplateRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({modifierGroupRowsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (modifierGroupRowsRefs) db.modifierGroupRows,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (modifierGroupRowsRefs)
                    await $_getPrefetchedDataByColumns<
                      ModifierTemplateRow,
                      $ModifierTemplateRowsTable,
                      ModifierGroupRow,
                      $ModifierGroupRowsTable
                    >(
                      currentTable: table,
                      referencedTable: $$ModifierTemplateRowsTableReferences
                          ._modifierGroupRowsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ModifierTemplateRowsTableReferences(
                            db,
                            table,
                            p0,
                          ).modifierGroupRowsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'template_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ModifierTemplateRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $ModifierTemplateRowsTable,
      ModifierTemplateRow,
      $$ModifierTemplateRowsTableFilterComposer,
      $$ModifierTemplateRowsTableOrderingComposer,
      $$ModifierTemplateRowsTableAnnotationComposer,
      $$ModifierTemplateRowsTableCreateCompanionBuilder,
      $$ModifierTemplateRowsTableUpdateCompanionBuilder,
      (ModifierTemplateRow, $$ModifierTemplateRowsTableReferences),
      ModifierTemplateRow,
      PrefetchHooks Function({bool modifierGroupRowsRefs})
    >;
typedef $$ModifierGroupRowsTableCreateCompanionBuilder =
    ModifierGroupRowsCompanion Function({
      required String id,
      required String templateId,
      required String name,
      required int minCount,
      Value<int?> maxCount,
      required int position,
      Value<int> rowid,
    });
typedef $$ModifierGroupRowsTableUpdateCompanionBuilder =
    ModifierGroupRowsCompanion Function({
      Value<String> id,
      Value<String> templateId,
      Value<String> name,
      Value<int> minCount,
      Value<int?> maxCount,
      Value<int> position,
      Value<int> rowid,
    });

final class $$ModifierGroupRowsTableReferences
    extends
        BaseReferences<
          _$KassaDatabase,
          $ModifierGroupRowsTable,
          ModifierGroupRow
        > {
  $$ModifierGroupRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ModifierTemplateRowsTable _templateIdTable(_$KassaDatabase db) => db
      .modifierTemplateRows
      .createAlias('modifier_groups__template_id__modifier_templates__id');

  $$ModifierTemplateRowsTableProcessedTableManager get templateId {
    final $_column = $_itemColumn<String>('template_id')!;

    final manager = $$ModifierTemplateRowsTableTableManager(
      $_db,
      $_db.modifierTemplateRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_templateIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ModifierOptionRowsTable, List<ModifierOptionRow>>
  _modifierOptionRowsRefsTable(_$KassaDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.modifierOptionRows,
        aliasName: 'modifier_groups__id__modifier_options__group_id',
      );

  $$ModifierOptionRowsTableProcessedTableManager get modifierOptionRowsRefs {
    final manager = $$ModifierOptionRowsTableTableManager(
      $_db,
      $_db.modifierOptionRows,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _modifierOptionRowsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ModifierGroupRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $ModifierGroupRowsTable> {
  $$ModifierGroupRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minCount => $composableBuilder(
    column: $table.minCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxCount => $composableBuilder(
    column: $table.maxCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$ModifierTemplateRowsTableFilterComposer get templateId {
    final $$ModifierTemplateRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.modifierTemplateRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModifierTemplateRowsTableFilterComposer(
            $db: $db,
            $table: $db.modifierTemplateRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> modifierOptionRowsRefs(
    Expression<bool> Function($$ModifierOptionRowsTableFilterComposer f) f,
  ) {
    final $$ModifierOptionRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.modifierOptionRows,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModifierOptionRowsTableFilterComposer(
            $db: $db,
            $table: $db.modifierOptionRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ModifierGroupRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $ModifierGroupRowsTable> {
  $$ModifierGroupRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minCount => $composableBuilder(
    column: $table.minCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxCount => $composableBuilder(
    column: $table.maxCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$ModifierTemplateRowsTableOrderingComposer get templateId {
    final $$ModifierTemplateRowsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.templateId,
          referencedTable: $db.modifierTemplateRows,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ModifierTemplateRowsTableOrderingComposer(
                $db: $db,
                $table: $db.modifierTemplateRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ModifierGroupRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $ModifierGroupRowsTable> {
  $$ModifierGroupRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get minCount =>
      $composableBuilder(column: $table.minCount, builder: (column) => column);

  GeneratedColumn<int> get maxCount =>
      $composableBuilder(column: $table.maxCount, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$ModifierTemplateRowsTableAnnotationComposer get templateId {
    final $$ModifierTemplateRowsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.templateId,
          referencedTable: $db.modifierTemplateRows,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ModifierTemplateRowsTableAnnotationComposer(
                $db: $db,
                $table: $db.modifierTemplateRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> modifierOptionRowsRefs<T extends Object>(
    Expression<T> Function($$ModifierOptionRowsTableAnnotationComposer a) f,
  ) {
    final $$ModifierOptionRowsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.modifierOptionRows,
          getReferencedColumn: (t) => t.groupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ModifierOptionRowsTableAnnotationComposer(
                $db: $db,
                $table: $db.modifierOptionRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ModifierGroupRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $ModifierGroupRowsTable,
          ModifierGroupRow,
          $$ModifierGroupRowsTableFilterComposer,
          $$ModifierGroupRowsTableOrderingComposer,
          $$ModifierGroupRowsTableAnnotationComposer,
          $$ModifierGroupRowsTableCreateCompanionBuilder,
          $$ModifierGroupRowsTableUpdateCompanionBuilder,
          (ModifierGroupRow, $$ModifierGroupRowsTableReferences),
          ModifierGroupRow,
          PrefetchHooks Function({bool templateId, bool modifierOptionRowsRefs})
        > {
  $$ModifierGroupRowsTableTableManager(
    _$KassaDatabase db,
    $ModifierGroupRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModifierGroupRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModifierGroupRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModifierGroupRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> templateId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> minCount = const Value.absent(),
                Value<int?> maxCount = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModifierGroupRowsCompanion(
                id: id,
                templateId: templateId,
                name: name,
                minCount: minCount,
                maxCount: maxCount,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String templateId,
                required String name,
                required int minCount,
                Value<int?> maxCount = const Value.absent(),
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => ModifierGroupRowsCompanion.insert(
                id: id,
                templateId: templateId,
                name: name,
                minCount: minCount,
                maxCount: maxCount,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModifierGroupRowsTable, ModifierGroupRow>(table),
                  $$ModifierGroupRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({templateId = false, modifierOptionRowsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (modifierOptionRowsRefs) db.modifierOptionRows,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (templateId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.templateId,
                            referencedTable: $$ModifierGroupRowsTableReferences
                                ._templateIdTable(db),
                            referencedColumn: $$ModifierGroupRowsTableReferences
                                ._templateIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (modifierOptionRowsRefs)
                        await $_getPrefetchedDataByColumns<
                          ModifierGroupRow,
                          $ModifierGroupRowsTable,
                          ModifierOptionRow,
                          $ModifierOptionRowsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ModifierGroupRowsTableReferences
                              ._modifierOptionRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ModifierGroupRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).modifierOptionRowsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'group_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ModifierGroupRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $ModifierGroupRowsTable,
      ModifierGroupRow,
      $$ModifierGroupRowsTableFilterComposer,
      $$ModifierGroupRowsTableOrderingComposer,
      $$ModifierGroupRowsTableAnnotationComposer,
      $$ModifierGroupRowsTableCreateCompanionBuilder,
      $$ModifierGroupRowsTableUpdateCompanionBuilder,
      (ModifierGroupRow, $$ModifierGroupRowsTableReferences),
      ModifierGroupRow,
      PrefetchHooks Function({bool templateId, bool modifierOptionRowsRefs})
    >;
typedef $$ModifierOptionRowsTableCreateCompanionBuilder =
    ModifierOptionRowsCompanion Function({
      required String id,
      required String groupId,
      required String name,
      Value<int> surchargeCents,
      Value<bool> isDefault,
      Value<int?> taxPercent,
      Value<int?> depositCents,
      required int position,
      Value<int> rowid,
    });
typedef $$ModifierOptionRowsTableUpdateCompanionBuilder =
    ModifierOptionRowsCompanion Function({
      Value<String> id,
      Value<String> groupId,
      Value<String> name,
      Value<int> surchargeCents,
      Value<bool> isDefault,
      Value<int?> taxPercent,
      Value<int?> depositCents,
      Value<int> position,
      Value<int> rowid,
    });

final class $$ModifierOptionRowsTableReferences
    extends
        BaseReferences<
          _$KassaDatabase,
          $ModifierOptionRowsTable,
          ModifierOptionRow
        > {
  $$ModifierOptionRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ModifierGroupRowsTable _groupIdTable(_$KassaDatabase db) => db
      .modifierGroupRows
      .createAlias('modifier_options__group_id__modifier_groups__id');

  $$ModifierGroupRowsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<String>('group_id')!;

    final manager = $$ModifierGroupRowsTableTableManager(
      $_db,
      $_db.modifierGroupRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ModifierOptionRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $ModifierOptionRowsTable> {
  $$ModifierOptionRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get surchargeCents => $composableBuilder(
    column: $table.surchargeCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taxPercent => $composableBuilder(
    column: $table.taxPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get depositCents => $composableBuilder(
    column: $table.depositCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$ModifierGroupRowsTableFilterComposer get groupId {
    final $$ModifierGroupRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.modifierGroupRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModifierGroupRowsTableFilterComposer(
            $db: $db,
            $table: $db.modifierGroupRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModifierOptionRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $ModifierOptionRowsTable> {
  $$ModifierOptionRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get surchargeCents => $composableBuilder(
    column: $table.surchargeCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taxPercent => $composableBuilder(
    column: $table.taxPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get depositCents => $composableBuilder(
    column: $table.depositCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$ModifierGroupRowsTableOrderingComposer get groupId {
    final $$ModifierGroupRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.modifierGroupRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ModifierGroupRowsTableOrderingComposer(
            $db: $db,
            $table: $db.modifierGroupRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ModifierOptionRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $ModifierOptionRowsTable> {
  $$ModifierOptionRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get surchargeCents => $composableBuilder(
    column: $table.surchargeCents,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<int> get taxPercent => $composableBuilder(
    column: $table.taxPercent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get depositCents => $composableBuilder(
    column: $table.depositCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$ModifierGroupRowsTableAnnotationComposer get groupId {
    final $$ModifierGroupRowsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.groupId,
          referencedTable: $db.modifierGroupRows,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ModifierGroupRowsTableAnnotationComposer(
                $db: $db,
                $table: $db.modifierGroupRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ModifierOptionRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $ModifierOptionRowsTable,
          ModifierOptionRow,
          $$ModifierOptionRowsTableFilterComposer,
          $$ModifierOptionRowsTableOrderingComposer,
          $$ModifierOptionRowsTableAnnotationComposer,
          $$ModifierOptionRowsTableCreateCompanionBuilder,
          $$ModifierOptionRowsTableUpdateCompanionBuilder,
          (ModifierOptionRow, $$ModifierOptionRowsTableReferences),
          ModifierOptionRow,
          PrefetchHooks Function({bool groupId})
        > {
  $$ModifierOptionRowsTableTableManager(
    _$KassaDatabase db,
    $ModifierOptionRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModifierOptionRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModifierOptionRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModifierOptionRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> surchargeCents = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int?> taxPercent = const Value.absent(),
                Value<int?> depositCents = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModifierOptionRowsCompanion(
                id: id,
                groupId: groupId,
                name: name,
                surchargeCents: surchargeCents,
                isDefault: isDefault,
                taxPercent: taxPercent,
                depositCents: depositCents,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                required String name,
                Value<int> surchargeCents = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int?> taxPercent = const Value.absent(),
                Value<int?> depositCents = const Value.absent(),
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => ModifierOptionRowsCompanion.insert(
                id: id,
                groupId: groupId,
                name: name,
                surchargeCents: surchargeCents,
                isDefault: isDefault,
                taxPercent: taxPercent,
                depositCents: depositCents,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ModifierOptionRowsTable, ModifierOptionRow>(
                    table,
                  ),
                  $$ModifierOptionRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.groupId,
                        referencedTable: $$ModifierOptionRowsTableReferences
                            ._groupIdTable(db),
                        referencedColumn: $$ModifierOptionRowsTableReferences
                            ._groupIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ModifierOptionRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $ModifierOptionRowsTable,
      ModifierOptionRow,
      $$ModifierOptionRowsTableFilterComposer,
      $$ModifierOptionRowsTableOrderingComposer,
      $$ModifierOptionRowsTableAnnotationComposer,
      $$ModifierOptionRowsTableCreateCompanionBuilder,
      $$ModifierOptionRowsTableUpdateCompanionBuilder,
      (ModifierOptionRow, $$ModifierOptionRowsTableReferences),
      ModifierOptionRow,
      PrefetchHooks Function({bool groupId})
    >;
typedef $$StaffRowsTableCreateCompanionBuilder = StaffRowsCompanion Function({
  required String id,
  required String name,
  required String role,
  required String pinSalt,
  required String pinHash,
  Value<int> rowid,
});
typedef $$StaffRowsTableUpdateCompanionBuilder = StaffRowsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> role,
  Value<String> pinSalt,
  Value<String> pinHash,
  Value<int> rowid,
});

class $$StaffRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $StaffRowsTable> {
  $$StaffRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinSalt => $composableBuilder(
    column: $table.pinSalt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StaffRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $StaffRowsTable> {
  $$StaffRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinSalt => $composableBuilder(
    column: $table.pinSalt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StaffRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $StaffRowsTable> {
  $$StaffRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get pinSalt =>
      $composableBuilder(column: $table.pinSalt, builder: (column) => column);

  GeneratedColumn<String> get pinHash =>
      $composableBuilder(column: $table.pinHash, builder: (column) => column);
}

class $$StaffRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $StaffRowsTable,
          StaffRow,
          $$StaffRowsTableFilterComposer,
          $$StaffRowsTableOrderingComposer,
          $$StaffRowsTableAnnotationComposer,
          $$StaffRowsTableCreateCompanionBuilder,
          $$StaffRowsTableUpdateCompanionBuilder,
          (
            StaffRow,
            BaseReferences<_$KassaDatabase, $StaffRowsTable, StaffRow>,
          ),
          StaffRow,
          PrefetchHooks Function()
        > {
  $$StaffRowsTableTableManager(_$KassaDatabase db, $StaffRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StaffRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StaffRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StaffRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> pinSalt = const Value.absent(),
                Value<String> pinHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StaffRowsCompanion(
                id: id,
                name: name,
                role: role,
                pinSalt: pinSalt,
                pinHash: pinHash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String role,
                required String pinSalt,
                required String pinHash,
                Value<int> rowid = const Value.absent(),
              }) => StaffRowsCompanion.insert(
                id: id,
                name: name,
                role: role,
                pinSalt: pinSalt,
                pinHash: pinHash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StaffRowsTable, StaffRow>(table),
                  BaseReferences<_$KassaDatabase, $StaffRowsTable, StaffRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StaffRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $StaffRowsTable,
      StaffRow,
      $$StaffRowsTableFilterComposer,
      $$StaffRowsTableOrderingComposer,
      $$StaffRowsTableAnnotationComposer,
      $$StaffRowsTableCreateCompanionBuilder,
      $$StaffRowsTableUpdateCompanionBuilder,
      (StaffRow, BaseReferences<_$KassaDatabase, $StaffRowsTable, StaffRow>),
      StaffRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsRowsTableCreateCompanionBuilder =
    SettingsRowsCompanion Function({
      Value<int> id,
      Value<bool> cashDrawerEnabled,
      Value<bool> showImages,
      Value<String> themeMode,
      Value<bool> voidRequiresChef,
      Value<String?> receiptDraft,
      Value<String> printerKind,
      Value<String?> printerAddress,
      Value<String?> printerName,
      Value<int> printerColumns,
      Value<bool> printerQrAsImage,
      Value<String> language,
      Value<String> kitchenMode,
      Value<String> kitchenLanguage,
      Value<String> kitchenPrinterKind,
      Value<String?> kitchenPrinterAddress,
      Value<String?> kitchenPrinterName,
      Value<int> kitchenPrinterColumns,
      Value<String> kitchenSkipCategories,
    });
typedef $$SettingsRowsTableUpdateCompanionBuilder =
    SettingsRowsCompanion Function({
      Value<int> id,
      Value<bool> cashDrawerEnabled,
      Value<bool> showImages,
      Value<String> themeMode,
      Value<bool> voidRequiresChef,
      Value<String?> receiptDraft,
      Value<String> printerKind,
      Value<String?> printerAddress,
      Value<String?> printerName,
      Value<int> printerColumns,
      Value<bool> printerQrAsImage,
      Value<String> language,
      Value<String> kitchenMode,
      Value<String> kitchenLanguage,
      Value<String> kitchenPrinterKind,
      Value<String?> kitchenPrinterAddress,
      Value<String?> kitchenPrinterName,
      Value<int> kitchenPrinterColumns,
      Value<String> kitchenSkipCategories,
    });

class $$SettingsRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $SettingsRowsTable> {
  $$SettingsRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get cashDrawerEnabled => $composableBuilder(
    column: $table.cashDrawerEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showImages => $composableBuilder(
    column: $table.showImages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get voidRequiresChef => $composableBuilder(
    column: $table.voidRequiresChef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptDraft => $composableBuilder(
    column: $table.receiptDraft,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get printerKind => $composableBuilder(
    column: $table.printerKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get printerAddress => $composableBuilder(
    column: $table.printerAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get printerName => $composableBuilder(
    column: $table.printerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get printerColumns => $composableBuilder(
    column: $table.printerColumns,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get printerQrAsImage => $composableBuilder(
    column: $table.printerQrAsImage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kitchenMode => $composableBuilder(
    column: $table.kitchenMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kitchenLanguage => $composableBuilder(
    column: $table.kitchenLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kitchenPrinterKind => $composableBuilder(
    column: $table.kitchenPrinterKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kitchenPrinterAddress => $composableBuilder(
    column: $table.kitchenPrinterAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kitchenPrinterName => $composableBuilder(
    column: $table.kitchenPrinterName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kitchenPrinterColumns => $composableBuilder(
    column: $table.kitchenPrinterColumns,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kitchenSkipCategories => $composableBuilder(
    column: $table.kitchenSkipCategories,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $SettingsRowsTable> {
  $$SettingsRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get cashDrawerEnabled => $composableBuilder(
    column: $table.cashDrawerEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showImages => $composableBuilder(
    column: $table.showImages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get voidRequiresChef => $composableBuilder(
    column: $table.voidRequiresChef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptDraft => $composableBuilder(
    column: $table.receiptDraft,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get printerKind => $composableBuilder(
    column: $table.printerKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get printerAddress => $composableBuilder(
    column: $table.printerAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get printerName => $composableBuilder(
    column: $table.printerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get printerColumns => $composableBuilder(
    column: $table.printerColumns,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get printerQrAsImage => $composableBuilder(
    column: $table.printerQrAsImage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kitchenMode => $composableBuilder(
    column: $table.kitchenMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kitchenLanguage => $composableBuilder(
    column: $table.kitchenLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kitchenPrinterKind => $composableBuilder(
    column: $table.kitchenPrinterKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kitchenPrinterAddress => $composableBuilder(
    column: $table.kitchenPrinterAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kitchenPrinterName => $composableBuilder(
    column: $table.kitchenPrinterName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kitchenPrinterColumns => $composableBuilder(
    column: $table.kitchenPrinterColumns,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kitchenSkipCategories => $composableBuilder(
    column: $table.kitchenSkipCategories,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $SettingsRowsTable> {
  $$SettingsRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get cashDrawerEnabled => $composableBuilder(
    column: $table.cashDrawerEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showImages => $composableBuilder(
    column: $table.showImages,
    builder: (column) => column,
  );

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<bool> get voidRequiresChef => $composableBuilder(
    column: $table.voidRequiresChef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receiptDraft => $composableBuilder(
    column: $table.receiptDraft,
    builder: (column) => column,
  );

  GeneratedColumn<String> get printerKind => $composableBuilder(
    column: $table.printerKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get printerAddress => $composableBuilder(
    column: $table.printerAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get printerName => $composableBuilder(
    column: $table.printerName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get printerColumns => $composableBuilder(
    column: $table.printerColumns,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get printerQrAsImage => $composableBuilder(
    column: $table.printerQrAsImage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get kitchenMode => $composableBuilder(
    column: $table.kitchenMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kitchenLanguage => $composableBuilder(
    column: $table.kitchenLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kitchenPrinterKind => $composableBuilder(
    column: $table.kitchenPrinterKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kitchenPrinterAddress => $composableBuilder(
    column: $table.kitchenPrinterAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kitchenPrinterName => $composableBuilder(
    column: $table.kitchenPrinterName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get kitchenPrinterColumns => $composableBuilder(
    column: $table.kitchenPrinterColumns,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kitchenSkipCategories => $composableBuilder(
    column: $table.kitchenSkipCategories,
    builder: (column) => column,
  );
}

class $$SettingsRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $SettingsRowsTable,
          SettingsRow,
          $$SettingsRowsTableFilterComposer,
          $$SettingsRowsTableOrderingComposer,
          $$SettingsRowsTableAnnotationComposer,
          $$SettingsRowsTableCreateCompanionBuilder,
          $$SettingsRowsTableUpdateCompanionBuilder,
          (
            SettingsRow,
            BaseReferences<_$KassaDatabase, $SettingsRowsTable, SettingsRow>,
          ),
          SettingsRow,
          PrefetchHooks Function()
        > {
  $$SettingsRowsTableTableManager(_$KassaDatabase db, $SettingsRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> cashDrawerEnabled = const Value.absent(),
                Value<bool> showImages = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<bool> voidRequiresChef = const Value.absent(),
                Value<String?> receiptDraft = const Value.absent(),
                Value<String> printerKind = const Value.absent(),
                Value<String?> printerAddress = const Value.absent(),
                Value<String?> printerName = const Value.absent(),
                Value<int> printerColumns = const Value.absent(),
                Value<bool> printerQrAsImage = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> kitchenMode = const Value.absent(),
                Value<String> kitchenLanguage = const Value.absent(),
                Value<String> kitchenPrinterKind = const Value.absent(),
                Value<String?> kitchenPrinterAddress = const Value.absent(),
                Value<String?> kitchenPrinterName = const Value.absent(),
                Value<int> kitchenPrinterColumns = const Value.absent(),
                Value<String> kitchenSkipCategories = const Value.absent(),
              }) => SettingsRowsCompanion(
                id: id,
                cashDrawerEnabled: cashDrawerEnabled,
                showImages: showImages,
                themeMode: themeMode,
                voidRequiresChef: voidRequiresChef,
                receiptDraft: receiptDraft,
                printerKind: printerKind,
                printerAddress: printerAddress,
                printerName: printerName,
                printerColumns: printerColumns,
                printerQrAsImage: printerQrAsImage,
                language: language,
                kitchenMode: kitchenMode,
                kitchenLanguage: kitchenLanguage,
                kitchenPrinterKind: kitchenPrinterKind,
                kitchenPrinterAddress: kitchenPrinterAddress,
                kitchenPrinterName: kitchenPrinterName,
                kitchenPrinterColumns: kitchenPrinterColumns,
                kitchenSkipCategories: kitchenSkipCategories,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> cashDrawerEnabled = const Value.absent(),
                Value<bool> showImages = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<bool> voidRequiresChef = const Value.absent(),
                Value<String?> receiptDraft = const Value.absent(),
                Value<String> printerKind = const Value.absent(),
                Value<String?> printerAddress = const Value.absent(),
                Value<String?> printerName = const Value.absent(),
                Value<int> printerColumns = const Value.absent(),
                Value<bool> printerQrAsImage = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> kitchenMode = const Value.absent(),
                Value<String> kitchenLanguage = const Value.absent(),
                Value<String> kitchenPrinterKind = const Value.absent(),
                Value<String?> kitchenPrinterAddress = const Value.absent(),
                Value<String?> kitchenPrinterName = const Value.absent(),
                Value<int> kitchenPrinterColumns = const Value.absent(),
                Value<String> kitchenSkipCategories = const Value.absent(),
              }) => SettingsRowsCompanion.insert(
                id: id,
                cashDrawerEnabled: cashDrawerEnabled,
                showImages: showImages,
                themeMode: themeMode,
                voidRequiresChef: voidRequiresChef,
                receiptDraft: receiptDraft,
                printerKind: printerKind,
                printerAddress: printerAddress,
                printerName: printerName,
                printerColumns: printerColumns,
                printerQrAsImage: printerQrAsImage,
                language: language,
                kitchenMode: kitchenMode,
                kitchenLanguage: kitchenLanguage,
                kitchenPrinterKind: kitchenPrinterKind,
                kitchenPrinterAddress: kitchenPrinterAddress,
                kitchenPrinterName: kitchenPrinterName,
                kitchenPrinterColumns: kitchenPrinterColumns,
                kitchenSkipCategories: kitchenSkipCategories,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsRowsTable, SettingsRow>(table),
                  BaseReferences<
                    _$KassaDatabase,
                    $SettingsRowsTable,
                    SettingsRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $SettingsRowsTable,
      SettingsRow,
      $$SettingsRowsTableFilterComposer,
      $$SettingsRowsTableOrderingComposer,
      $$SettingsRowsTableAnnotationComposer,
      $$SettingsRowsTableCreateCompanionBuilder,
      $$SettingsRowsTableUpdateCompanionBuilder,
      (
        SettingsRow,
        BaseReferences<_$KassaDatabase, $SettingsRowsTable, SettingsRow>,
      ),
      SettingsRow,
      PrefetchHooks Function()
    >;
typedef $$TranslationRowsTableCreateCompanionBuilder =
    TranslationRowsCompanion Function({
      required String source,
      required String valuesJson,
      Value<int> rowid,
    });
typedef $$TranslationRowsTableUpdateCompanionBuilder =
    TranslationRowsCompanion Function({
      Value<String> source,
      Value<String> valuesJson,
      Value<int> rowid,
    });

class $$TranslationRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $TranslationRowsTable> {
  $$TranslationRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valuesJson => $composableBuilder(
    column: $table.valuesJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TranslationRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $TranslationRowsTable> {
  $$TranslationRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valuesJson => $composableBuilder(
    column: $table.valuesJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TranslationRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $TranslationRowsTable> {
  $$TranslationRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get valuesJson => $composableBuilder(
    column: $table.valuesJson,
    builder: (column) => column,
  );
}

class $$TranslationRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $TranslationRowsTable,
          TranslationRow,
          $$TranslationRowsTableFilterComposer,
          $$TranslationRowsTableOrderingComposer,
          $$TranslationRowsTableAnnotationComposer,
          $$TranslationRowsTableCreateCompanionBuilder,
          $$TranslationRowsTableUpdateCompanionBuilder,
          (
            TranslationRow,
            BaseReferences<
              _$KassaDatabase,
              $TranslationRowsTable,
              TranslationRow
            >,
          ),
          TranslationRow,
          PrefetchHooks Function()
        > {
  $$TranslationRowsTableTableManager(
    _$KassaDatabase db,
    $TranslationRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranslationRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranslationRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranslationRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> source = const Value.absent(),
                Value<String> valuesJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranslationRowsCompanion(
                source: source,
                valuesJson: valuesJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String source,
                required String valuesJson,
                Value<int> rowid = const Value.absent(),
              }) => TranslationRowsCompanion.insert(
                source: source,
                valuesJson: valuesJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TranslationRowsTable, TranslationRow>(table),
                  BaseReferences<
                    _$KassaDatabase,
                    $TranslationRowsTable,
                    TranslationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TranslationRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $TranslationRowsTable,
      TranslationRow,
      $$TranslationRowsTableFilterComposer,
      $$TranslationRowsTableOrderingComposer,
      $$TranslationRowsTableAnnotationComposer,
      $$TranslationRowsTableCreateCompanionBuilder,
      $$TranslationRowsTableUpdateCompanionBuilder,
      (
        TranslationRow,
        BaseReferences<_$KassaDatabase, $TranslationRowsTable, TranslationRow>,
      ),
      TranslationRow,
      PrefetchHooks Function()
    >;
typedef $$BusinessDayRowsTableCreateCompanionBuilder =
    BusinessDayRowsCompanion Function({
      required String id,
      required DateTime openedAt,
      Value<DateTime?> closedAt,
      Value<int?> openingFloatCents,
      Value<int?> countedCents,
      Value<int?> leftInDrawerCents,
      Value<int?> expectedCents,
      Value<int?> differenceCents,
      Value<String?> closedByName,
      Value<int> rowid,
    });
typedef $$BusinessDayRowsTableUpdateCompanionBuilder =
    BusinessDayRowsCompanion Function({
      Value<String> id,
      Value<DateTime> openedAt,
      Value<DateTime?> closedAt,
      Value<int?> openingFloatCents,
      Value<int?> countedCents,
      Value<int?> leftInDrawerCents,
      Value<int?> expectedCents,
      Value<int?> differenceCents,
      Value<String?> closedByName,
      Value<int> rowid,
    });

final class $$BusinessDayRowsTableReferences
    extends
        BaseReferences<_$KassaDatabase, $BusinessDayRowsTable, BusinessDayRow> {
  $$BusinessDayRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$CashMovementRowsTable, List<CashMovementRow>>
  _cashMovementRowsRefsTable(_$KassaDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.cashMovementRows,
        aliasName: 'business_days__id__cash_movements__business_day_id',
      );

  $$CashMovementRowsTableProcessedTableManager get cashMovementRowsRefs {
    final manager = $$CashMovementRowsTableTableManager(
      $_db,
      $_db.cashMovementRows,
    ).filter((f) => f.businessDayId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cashMovementRowsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReceiptRowsTable, List<ReceiptRow>>
  _receiptRowsRefsTable(_$KassaDatabase db) => MultiTypedResultKey.fromTable(
    db.receiptRows,
    aliasName: 'business_days__id__receipts__business_day_id',
  );

  $$ReceiptRowsTableProcessedTableManager get receiptRowsRefs {
    final manager = $$ReceiptRowsTableTableManager(
      $_db,
      $_db.receiptRows,
    ).filter((f) => f.businessDayId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_receiptRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BusinessDayRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $BusinessDayRowsTable> {
  $$BusinessDayRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openingFloatCents => $composableBuilder(
    column: $table.openingFloatCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get countedCents => $composableBuilder(
    column: $table.countedCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get leftInDrawerCents => $composableBuilder(
    column: $table.leftInDrawerCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedCents => $composableBuilder(
    column: $table.expectedCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get differenceCents => $composableBuilder(
    column: $table.differenceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get closedByName => $composableBuilder(
    column: $table.closedByName,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> cashMovementRowsRefs(
    Expression<bool> Function($$CashMovementRowsTableFilterComposer f) f,
  ) {
    final $$CashMovementRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cashMovementRows,
      getReferencedColumn: (t) => t.businessDayId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CashMovementRowsTableFilterComposer(
            $db: $db,
            $table: $db.cashMovementRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> receiptRowsRefs(
    Expression<bool> Function($$ReceiptRowsTableFilterComposer f) f,
  ) {
    final $$ReceiptRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.receiptRows,
      getReferencedColumn: (t) => t.businessDayId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptRowsTableFilterComposer(
            $db: $db,
            $table: $db.receiptRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BusinessDayRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $BusinessDayRowsTable> {
  $$BusinessDayRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openingFloatCents => $composableBuilder(
    column: $table.openingFloatCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get countedCents => $composableBuilder(
    column: $table.countedCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get leftInDrawerCents => $composableBuilder(
    column: $table.leftInDrawerCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedCents => $composableBuilder(
    column: $table.expectedCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get differenceCents => $composableBuilder(
    column: $table.differenceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get closedByName => $composableBuilder(
    column: $table.closedByName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BusinessDayRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $BusinessDayRowsTable> {
  $$BusinessDayRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => column);

  GeneratedColumn<int> get openingFloatCents => $composableBuilder(
    column: $table.openingFloatCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get countedCents => $composableBuilder(
    column: $table.countedCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get leftInDrawerCents => $composableBuilder(
    column: $table.leftInDrawerCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expectedCents => $composableBuilder(
    column: $table.expectedCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get differenceCents => $composableBuilder(
    column: $table.differenceCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get closedByName => $composableBuilder(
    column: $table.closedByName,
    builder: (column) => column,
  );

  Expression<T> cashMovementRowsRefs<T extends Object>(
    Expression<T> Function($$CashMovementRowsTableAnnotationComposer a) f,
  ) {
    final $$CashMovementRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cashMovementRows,
      getReferencedColumn: (t) => t.businessDayId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CashMovementRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.cashMovementRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> receiptRowsRefs<T extends Object>(
    Expression<T> Function($$ReceiptRowsTableAnnotationComposer a) f,
  ) {
    final $$ReceiptRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.receiptRows,
      getReferencedColumn: (t) => t.businessDayId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.receiptRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BusinessDayRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $BusinessDayRowsTable,
          BusinessDayRow,
          $$BusinessDayRowsTableFilterComposer,
          $$BusinessDayRowsTableOrderingComposer,
          $$BusinessDayRowsTableAnnotationComposer,
          $$BusinessDayRowsTableCreateCompanionBuilder,
          $$BusinessDayRowsTableUpdateCompanionBuilder,
          (BusinessDayRow, $$BusinessDayRowsTableReferences),
          BusinessDayRow,
          PrefetchHooks Function({
            bool cashMovementRowsRefs,
            bool receiptRowsRefs,
          })
        > {
  $$BusinessDayRowsTableTableManager(
    _$KassaDatabase db,
    $BusinessDayRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BusinessDayRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BusinessDayRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BusinessDayRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> openedAt = const Value.absent(),
                Value<DateTime?> closedAt = const Value.absent(),
                Value<int?> openingFloatCents = const Value.absent(),
                Value<int?> countedCents = const Value.absent(),
                Value<int?> leftInDrawerCents = const Value.absent(),
                Value<int?> expectedCents = const Value.absent(),
                Value<int?> differenceCents = const Value.absent(),
                Value<String?> closedByName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BusinessDayRowsCompanion(
                id: id,
                openedAt: openedAt,
                closedAt: closedAt,
                openingFloatCents: openingFloatCents,
                countedCents: countedCents,
                leftInDrawerCents: leftInDrawerCents,
                expectedCents: expectedCents,
                differenceCents: differenceCents,
                closedByName: closedByName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime openedAt,
                Value<DateTime?> closedAt = const Value.absent(),
                Value<int?> openingFloatCents = const Value.absent(),
                Value<int?> countedCents = const Value.absent(),
                Value<int?> leftInDrawerCents = const Value.absent(),
                Value<int?> expectedCents = const Value.absent(),
                Value<int?> differenceCents = const Value.absent(),
                Value<String?> closedByName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BusinessDayRowsCompanion.insert(
                id: id,
                openedAt: openedAt,
                closedAt: closedAt,
                openingFloatCents: openingFloatCents,
                countedCents: countedCents,
                leftInDrawerCents: leftInDrawerCents,
                expectedCents: expectedCents,
                differenceCents: differenceCents,
                closedByName: closedByName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BusinessDayRowsTable, BusinessDayRow>(table),
                  $$BusinessDayRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({cashMovementRowsRefs = false, receiptRowsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (cashMovementRowsRefs) db.cashMovementRows,
                    if (receiptRowsRefs) db.receiptRows,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (cashMovementRowsRefs)
                        await $_getPrefetchedDataByColumns<
                          BusinessDayRow,
                          $BusinessDayRowsTable,
                          CashMovementRow,
                          $CashMovementRowsTable
                        >(
                          currentTable: table,
                          referencedTable: $$BusinessDayRowsTableReferences
                              ._cashMovementRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BusinessDayRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).cashMovementRowsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'business_day_id',
                          typedResults: items,
                        ),
                      if (receiptRowsRefs)
                        await $_getPrefetchedDataByColumns<
                          BusinessDayRow,
                          $BusinessDayRowsTable,
                          ReceiptRow,
                          $ReceiptRowsTable
                        >(
                          currentTable: table,
                          referencedTable: $$BusinessDayRowsTableReferences
                              ._receiptRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BusinessDayRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).receiptRowsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'business_day_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BusinessDayRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $BusinessDayRowsTable,
      BusinessDayRow,
      $$BusinessDayRowsTableFilterComposer,
      $$BusinessDayRowsTableOrderingComposer,
      $$BusinessDayRowsTableAnnotationComposer,
      $$BusinessDayRowsTableCreateCompanionBuilder,
      $$BusinessDayRowsTableUpdateCompanionBuilder,
      (BusinessDayRow, $$BusinessDayRowsTableReferences),
      BusinessDayRow,
      PrefetchHooks Function({bool cashMovementRowsRefs, bool receiptRowsRefs})
    >;
typedef $$CashMovementRowsTableCreateCompanionBuilder =
    CashMovementRowsCompanion Function({
      required String id,
      required String businessDayId,
      required String kind,
      required int amountCents,
      required String reason,
      required DateTime createdAt,
      required String staffId,
      required String staffName,
      Value<int> rowid,
    });
typedef $$CashMovementRowsTableUpdateCompanionBuilder =
    CashMovementRowsCompanion Function({
      Value<String> id,
      Value<String> businessDayId,
      Value<String> kind,
      Value<int> amountCents,
      Value<String> reason,
      Value<DateTime> createdAt,
      Value<String> staffId,
      Value<String> staffName,
      Value<int> rowid,
    });

final class $$CashMovementRowsTableReferences
    extends
        BaseReferences<
          _$KassaDatabase,
          $CashMovementRowsTable,
          CashMovementRow
        > {
  $$CashMovementRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BusinessDayRowsTable _businessDayIdTable(_$KassaDatabase db) => db
      .businessDayRows
      .createAlias('cash_movements__business_day_id__business_days__id');

  $$BusinessDayRowsTableProcessedTableManager get businessDayId {
    final $_column = $_itemColumn<String>('business_day_id')!;

    final manager = $$BusinessDayRowsTableTableManager(
      $_db,
      $_db.businessDayRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_businessDayIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CashMovementRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $CashMovementRowsTable> {
  $$CashMovementRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get staffId => $composableBuilder(
    column: $table.staffId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get staffName => $composableBuilder(
    column: $table.staffName,
    builder: (column) => ColumnFilters(column),
  );

  $$BusinessDayRowsTableFilterComposer get businessDayId {
    final $$BusinessDayRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.businessDayId,
      referencedTable: $db.businessDayRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BusinessDayRowsTableFilterComposer(
            $db: $db,
            $table: $db.businessDayRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CashMovementRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $CashMovementRowsTable> {
  $$CashMovementRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get staffId => $composableBuilder(
    column: $table.staffId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get staffName => $composableBuilder(
    column: $table.staffName,
    builder: (column) => ColumnOrderings(column),
  );

  $$BusinessDayRowsTableOrderingComposer get businessDayId {
    final $$BusinessDayRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.businessDayId,
      referencedTable: $db.businessDayRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BusinessDayRowsTableOrderingComposer(
            $db: $db,
            $table: $db.businessDayRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CashMovementRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $CashMovementRowsTable> {
  $$CashMovementRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get staffId =>
      $composableBuilder(column: $table.staffId, builder: (column) => column);

  GeneratedColumn<String> get staffName =>
      $composableBuilder(column: $table.staffName, builder: (column) => column);

  $$BusinessDayRowsTableAnnotationComposer get businessDayId {
    final $$BusinessDayRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.businessDayId,
      referencedTable: $db.businessDayRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BusinessDayRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.businessDayRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CashMovementRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $CashMovementRowsTable,
          CashMovementRow,
          $$CashMovementRowsTableFilterComposer,
          $$CashMovementRowsTableOrderingComposer,
          $$CashMovementRowsTableAnnotationComposer,
          $$CashMovementRowsTableCreateCompanionBuilder,
          $$CashMovementRowsTableUpdateCompanionBuilder,
          (CashMovementRow, $$CashMovementRowsTableReferences),
          CashMovementRow,
          PrefetchHooks Function({bool businessDayId})
        > {
  $$CashMovementRowsTableTableManager(
    _$KassaDatabase db,
    $CashMovementRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CashMovementRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CashMovementRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CashMovementRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> businessDayId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> staffId = const Value.absent(),
                Value<String> staffName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CashMovementRowsCompanion(
                id: id,
                businessDayId: businessDayId,
                kind: kind,
                amountCents: amountCents,
                reason: reason,
                createdAt: createdAt,
                staffId: staffId,
                staffName: staffName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String businessDayId,
                required String kind,
                required int amountCents,
                required String reason,
                required DateTime createdAt,
                required String staffId,
                required String staffName,
                Value<int> rowid = const Value.absent(),
              }) => CashMovementRowsCompanion.insert(
                id: id,
                businessDayId: businessDayId,
                kind: kind,
                amountCents: amountCents,
                reason: reason,
                createdAt: createdAt,
                staffId: staffId,
                staffName: staffName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CashMovementRowsTable, CashMovementRow>(table),
                  $$CashMovementRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({businessDayId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (businessDayId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.businessDayId,
                        referencedTable: $$CashMovementRowsTableReferences
                            ._businessDayIdTable(db),
                        referencedColumn: $$CashMovementRowsTableReferences
                            ._businessDayIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CashMovementRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $CashMovementRowsTable,
      CashMovementRow,
      $$CashMovementRowsTableFilterComposer,
      $$CashMovementRowsTableOrderingComposer,
      $$CashMovementRowsTableAnnotationComposer,
      $$CashMovementRowsTableCreateCompanionBuilder,
      $$CashMovementRowsTableUpdateCompanionBuilder,
      (CashMovementRow, $$CashMovementRowsTableReferences),
      CashMovementRow,
      PrefetchHooks Function({bool businessDayId})
    >;
typedef $$ReceiptRowsTableCreateCompanionBuilder =
    ReceiptRowsCompanion Function({
      required String id,
      required int number,
      required DateTime createdAt,
      required String staffId,
      required String staffName,
      Value<String?> businessDayId,
      required String kind,
      Value<String?> voidsReceiptId,
      required int goodsCents,
      required int depositCents,
      required int totalCents,
      Value<int> rowid,
    });
typedef $$ReceiptRowsTableUpdateCompanionBuilder =
    ReceiptRowsCompanion Function({
      Value<String> id,
      Value<int> number,
      Value<DateTime> createdAt,
      Value<String> staffId,
      Value<String> staffName,
      Value<String?> businessDayId,
      Value<String> kind,
      Value<String?> voidsReceiptId,
      Value<int> goodsCents,
      Value<int> depositCents,
      Value<int> totalCents,
      Value<int> rowid,
    });

final class $$ReceiptRowsTableReferences
    extends BaseReferences<_$KassaDatabase, $ReceiptRowsTable, ReceiptRow> {
  $$ReceiptRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BusinessDayRowsTable _businessDayIdTable(_$KassaDatabase db) => db
      .businessDayRows
      .createAlias('receipts__business_day_id__business_days__id');

  $$BusinessDayRowsTableProcessedTableManager? get businessDayId {
    final $_column = $_itemColumn<String>('business_day_id');
    if ($_column == null) return null;
    final manager = $$BusinessDayRowsTableTableManager(
      $_db,
      $_db.businessDayRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_businessDayIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ReceiptRowsTable _voidsReceiptIdTable(_$KassaDatabase db) =>
      db.receiptRows.createAlias('receipts__voids_receipt_id__receipts__id');

  $$ReceiptRowsTableProcessedTableManager? get voidsReceiptId {
    final $_column = $_itemColumn<String>('voids_receipt_id');
    if ($_column == null) return null;
    final manager = $$ReceiptRowsTableTableManager(
      $_db,
      $_db.receiptRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_voidsReceiptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ReceiptLineRowsTable, List<ReceiptLineRow>>
  _receiptLineRowsRefsTable(_$KassaDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.receiptLineRows,
        aliasName: 'receipts__id__receipt_lines__receipt_id',
      );

  $$ReceiptLineRowsTableProcessedTableManager get receiptLineRowsRefs {
    final manager = $$ReceiptLineRowsTableTableManager(
      $_db,
      $_db.receiptLineRows,
    ).filter((f) => f.receiptId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _receiptLineRowsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PaymentRowsTable, List<PaymentRow>>
  _paymentRowsRefsTable(_$KassaDatabase db) => MultiTypedResultKey.fromTable(
    db.paymentRows,
    aliasName: 'receipts__id__payments__receipt_id',
  );

  $$PaymentRowsTableProcessedTableManager get paymentRowsRefs {
    final manager = $$PaymentRowsTableTableManager(
      $_db,
      $_db.paymentRows,
    ).filter((f) => f.receiptId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_paymentRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RksvEntryRowsTable, List<RksvEntryRow>>
  _rksvEntryRowsRefsTable(_$KassaDatabase db) => MultiTypedResultKey.fromTable(
    db.rksvEntryRows,
    aliasName: 'receipts__id__rksv_entries__receipt_id',
  );

  $$RksvEntryRowsTableProcessedTableManager get rksvEntryRowsRefs {
    final manager = $$RksvEntryRowsTableTableManager(
      $_db,
      $_db.rksvEntryRows,
    ).filter((f) => f.receiptId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_rksvEntryRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ReceiptRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $ReceiptRowsTable> {
  $$ReceiptRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get staffId => $composableBuilder(
    column: $table.staffId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get staffName => $composableBuilder(
    column: $table.staffName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goodsCents => $composableBuilder(
    column: $table.goodsCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get depositCents => $composableBuilder(
    column: $table.depositCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCents => $composableBuilder(
    column: $table.totalCents,
    builder: (column) => ColumnFilters(column),
  );

  $$BusinessDayRowsTableFilterComposer get businessDayId {
    final $$BusinessDayRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.businessDayId,
      referencedTable: $db.businessDayRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BusinessDayRowsTableFilterComposer(
            $db: $db,
            $table: $db.businessDayRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReceiptRowsTableFilterComposer get voidsReceiptId {
    final $$ReceiptRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.voidsReceiptId,
      referencedTable: $db.receiptRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptRowsTableFilterComposer(
            $db: $db,
            $table: $db.receiptRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> receiptLineRowsRefs(
    Expression<bool> Function($$ReceiptLineRowsTableFilterComposer f) f,
  ) {
    final $$ReceiptLineRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.receiptLineRows,
      getReferencedColumn: (t) => t.receiptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptLineRowsTableFilterComposer(
            $db: $db,
            $table: $db.receiptLineRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> paymentRowsRefs(
    Expression<bool> Function($$PaymentRowsTableFilterComposer f) f,
  ) {
    final $$PaymentRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.paymentRows,
      getReferencedColumn: (t) => t.receiptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentRowsTableFilterComposer(
            $db: $db,
            $table: $db.paymentRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> rksvEntryRowsRefs(
    Expression<bool> Function($$RksvEntryRowsTableFilterComposer f) f,
  ) {
    final $$RksvEntryRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rksvEntryRows,
      getReferencedColumn: (t) => t.receiptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RksvEntryRowsTableFilterComposer(
            $db: $db,
            $table: $db.rksvEntryRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReceiptRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $ReceiptRowsTable> {
  $$ReceiptRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get staffId => $composableBuilder(
    column: $table.staffId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get staffName => $composableBuilder(
    column: $table.staffName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goodsCents => $composableBuilder(
    column: $table.goodsCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get depositCents => $composableBuilder(
    column: $table.depositCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCents => $composableBuilder(
    column: $table.totalCents,
    builder: (column) => ColumnOrderings(column),
  );

  $$BusinessDayRowsTableOrderingComposer get businessDayId {
    final $$BusinessDayRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.businessDayId,
      referencedTable: $db.businessDayRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BusinessDayRowsTableOrderingComposer(
            $db: $db,
            $table: $db.businessDayRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReceiptRowsTableOrderingComposer get voidsReceiptId {
    final $$ReceiptRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.voidsReceiptId,
      referencedTable: $db.receiptRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptRowsTableOrderingComposer(
            $db: $db,
            $table: $db.receiptRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReceiptRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $ReceiptRowsTable> {
  $$ReceiptRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get staffId =>
      $composableBuilder(column: $table.staffId, builder: (column) => column);

  GeneratedColumn<String> get staffName =>
      $composableBuilder(column: $table.staffName, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get goodsCents => $composableBuilder(
    column: $table.goodsCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get depositCents => $composableBuilder(
    column: $table.depositCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalCents => $composableBuilder(
    column: $table.totalCents,
    builder: (column) => column,
  );

  $$BusinessDayRowsTableAnnotationComposer get businessDayId {
    final $$BusinessDayRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.businessDayId,
      referencedTable: $db.businessDayRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BusinessDayRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.businessDayRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReceiptRowsTableAnnotationComposer get voidsReceiptId {
    final $$ReceiptRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.voidsReceiptId,
      referencedTable: $db.receiptRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.receiptRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> receiptLineRowsRefs<T extends Object>(
    Expression<T> Function($$ReceiptLineRowsTableAnnotationComposer a) f,
  ) {
    final $$ReceiptLineRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.receiptLineRows,
      getReferencedColumn: (t) => t.receiptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptLineRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.receiptLineRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> paymentRowsRefs<T extends Object>(
    Expression<T> Function($$PaymentRowsTableAnnotationComposer a) f,
  ) {
    final $$PaymentRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.paymentRows,
      getReferencedColumn: (t) => t.receiptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PaymentRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.paymentRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> rksvEntryRowsRefs<T extends Object>(
    Expression<T> Function($$RksvEntryRowsTableAnnotationComposer a) f,
  ) {
    final $$RksvEntryRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rksvEntryRows,
      getReferencedColumn: (t) => t.receiptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RksvEntryRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.rksvEntryRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReceiptRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $ReceiptRowsTable,
          ReceiptRow,
          $$ReceiptRowsTableFilterComposer,
          $$ReceiptRowsTableOrderingComposer,
          $$ReceiptRowsTableAnnotationComposer,
          $$ReceiptRowsTableCreateCompanionBuilder,
          $$ReceiptRowsTableUpdateCompanionBuilder,
          (ReceiptRow, $$ReceiptRowsTableReferences),
          ReceiptRow,
          PrefetchHooks Function({
            bool businessDayId,
            bool voidsReceiptId,
            bool receiptLineRowsRefs,
            bool paymentRowsRefs,
            bool rksvEntryRowsRefs,
          })
        > {
  $$ReceiptRowsTableTableManager(_$KassaDatabase db, $ReceiptRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReceiptRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReceiptRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReceiptRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> number = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> staffId = const Value.absent(),
                Value<String> staffName = const Value.absent(),
                Value<String?> businessDayId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> voidsReceiptId = const Value.absent(),
                Value<int> goodsCents = const Value.absent(),
                Value<int> depositCents = const Value.absent(),
                Value<int> totalCents = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReceiptRowsCompanion(
                id: id,
                number: number,
                createdAt: createdAt,
                staffId: staffId,
                staffName: staffName,
                businessDayId: businessDayId,
                kind: kind,
                voidsReceiptId: voidsReceiptId,
                goodsCents: goodsCents,
                depositCents: depositCents,
                totalCents: totalCents,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int number,
                required DateTime createdAt,
                required String staffId,
                required String staffName,
                Value<String?> businessDayId = const Value.absent(),
                required String kind,
                Value<String?> voidsReceiptId = const Value.absent(),
                required int goodsCents,
                required int depositCents,
                required int totalCents,
                Value<int> rowid = const Value.absent(),
              }) => ReceiptRowsCompanion.insert(
                id: id,
                number: number,
                createdAt: createdAt,
                staffId: staffId,
                staffName: staffName,
                businessDayId: businessDayId,
                kind: kind,
                voidsReceiptId: voidsReceiptId,
                goodsCents: goodsCents,
                depositCents: depositCents,
                totalCents: totalCents,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReceiptRowsTable, ReceiptRow>(table),
                  $$ReceiptRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                businessDayId = false,
                voidsReceiptId = false,
                receiptLineRowsRefs = false,
                paymentRowsRefs = false,
                rksvEntryRowsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (receiptLineRowsRefs) db.receiptLineRows,
                    if (paymentRowsRefs) db.paymentRows,
                    if (rksvEntryRowsRefs) db.rksvEntryRows,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (businessDayId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.businessDayId,
                            referencedTable: $$ReceiptRowsTableReferences
                                ._businessDayIdTable(db),
                            referencedColumn: $$ReceiptRowsTableReferences
                                ._businessDayIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (voidsReceiptId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.voidsReceiptId,
                            referencedTable: $$ReceiptRowsTableReferences
                                ._voidsReceiptIdTable(db),
                            referencedColumn: $$ReceiptRowsTableReferences
                                ._voidsReceiptIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (receiptLineRowsRefs)
                        await $_getPrefetchedDataByColumns<
                          ReceiptRow,
                          $ReceiptRowsTable,
                          ReceiptLineRow,
                          $ReceiptLineRowsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ReceiptRowsTableReferences
                              ._receiptLineRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ReceiptRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).receiptLineRowsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'receipt_id',
                          typedResults: items,
                        ),
                      if (paymentRowsRefs)
                        await $_getPrefetchedDataByColumns<
                          ReceiptRow,
                          $ReceiptRowsTable,
                          PaymentRow,
                          $PaymentRowsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ReceiptRowsTableReferences
                              ._paymentRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ReceiptRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).paymentRowsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'receipt_id',
                          typedResults: items,
                        ),
                      if (rksvEntryRowsRefs)
                        await $_getPrefetchedDataByColumns<
                          ReceiptRow,
                          $ReceiptRowsTable,
                          RksvEntryRow,
                          $RksvEntryRowsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ReceiptRowsTableReferences
                              ._rksvEntryRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ReceiptRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).rksvEntryRowsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'receipt_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ReceiptRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $ReceiptRowsTable,
      ReceiptRow,
      $$ReceiptRowsTableFilterComposer,
      $$ReceiptRowsTableOrderingComposer,
      $$ReceiptRowsTableAnnotationComposer,
      $$ReceiptRowsTableCreateCompanionBuilder,
      $$ReceiptRowsTableUpdateCompanionBuilder,
      (ReceiptRow, $$ReceiptRowsTableReferences),
      ReceiptRow,
      PrefetchHooks Function({
        bool businessDayId,
        bool voidsReceiptId,
        bool receiptLineRowsRefs,
        bool paymentRowsRefs,
        bool rksvEntryRowsRefs,
      })
    >;
typedef $$ReceiptLineRowsTableCreateCompanionBuilder =
    ReceiptLineRowsCompanion Function({
      required String receiptId,
      required int position,
      required String itemId,
      required String name,
      Value<String?> info,
      required int unitPriceCents,
      required int quantity,
      required int unitDepositCents,
      Value<int> gross20Cents,
      Value<int> gross10Cents,
      Value<int> gross13Cents,
      Value<int> gross0Cents,
      Value<int> gross19Cents,
      Value<int> rowid,
    });
typedef $$ReceiptLineRowsTableUpdateCompanionBuilder =
    ReceiptLineRowsCompanion Function({
      Value<String> receiptId,
      Value<int> position,
      Value<String> itemId,
      Value<String> name,
      Value<String?> info,
      Value<int> unitPriceCents,
      Value<int> quantity,
      Value<int> unitDepositCents,
      Value<int> gross20Cents,
      Value<int> gross10Cents,
      Value<int> gross13Cents,
      Value<int> gross0Cents,
      Value<int> gross19Cents,
      Value<int> rowid,
    });

final class $$ReceiptLineRowsTableReferences
    extends
        BaseReferences<_$KassaDatabase, $ReceiptLineRowsTable, ReceiptLineRow> {
  $$ReceiptLineRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ReceiptRowsTable _receiptIdTable(_$KassaDatabase db) =>
      db.receiptRows.createAlias('receipt_lines__receipt_id__receipts__id');

  $$ReceiptRowsTableProcessedTableManager get receiptId {
    final $_column = $_itemColumn<String>('receipt_id')!;

    final manager = $$ReceiptRowsTableTableManager(
      $_db,
      $_db.receiptRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_receiptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReceiptLineRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $ReceiptLineRowsTable> {
  $$ReceiptLineRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get info => $composableBuilder(
    column: $table.info,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitPriceCents => $composableBuilder(
    column: $table.unitPriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitDepositCents => $composableBuilder(
    column: $table.unitDepositCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gross20Cents => $composableBuilder(
    column: $table.gross20Cents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gross10Cents => $composableBuilder(
    column: $table.gross10Cents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gross13Cents => $composableBuilder(
    column: $table.gross13Cents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gross0Cents => $composableBuilder(
    column: $table.gross0Cents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gross19Cents => $composableBuilder(
    column: $table.gross19Cents,
    builder: (column) => ColumnFilters(column),
  );

  $$ReceiptRowsTableFilterComposer get receiptId {
    final $$ReceiptRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receiptRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptRowsTableFilterComposer(
            $db: $db,
            $table: $db.receiptRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReceiptLineRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $ReceiptLineRowsTable> {
  $$ReceiptLineRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get info => $composableBuilder(
    column: $table.info,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitPriceCents => $composableBuilder(
    column: $table.unitPriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitDepositCents => $composableBuilder(
    column: $table.unitDepositCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gross20Cents => $composableBuilder(
    column: $table.gross20Cents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gross10Cents => $composableBuilder(
    column: $table.gross10Cents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gross13Cents => $composableBuilder(
    column: $table.gross13Cents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gross0Cents => $composableBuilder(
    column: $table.gross0Cents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gross19Cents => $composableBuilder(
    column: $table.gross19Cents,
    builder: (column) => ColumnOrderings(column),
  );

  $$ReceiptRowsTableOrderingComposer get receiptId {
    final $$ReceiptRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receiptRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptRowsTableOrderingComposer(
            $db: $db,
            $table: $db.receiptRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReceiptLineRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $ReceiptLineRowsTable> {
  $$ReceiptLineRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get info =>
      $composableBuilder(column: $table.info, builder: (column) => column);

  GeneratedColumn<int> get unitPriceCents => $composableBuilder(
    column: $table.unitPriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<int> get unitDepositCents => $composableBuilder(
    column: $table.unitDepositCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gross20Cents => $composableBuilder(
    column: $table.gross20Cents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gross10Cents => $composableBuilder(
    column: $table.gross10Cents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gross13Cents => $composableBuilder(
    column: $table.gross13Cents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gross0Cents => $composableBuilder(
    column: $table.gross0Cents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gross19Cents => $composableBuilder(
    column: $table.gross19Cents,
    builder: (column) => column,
  );

  $$ReceiptRowsTableAnnotationComposer get receiptId {
    final $$ReceiptRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receiptRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.receiptRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReceiptLineRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $ReceiptLineRowsTable,
          ReceiptLineRow,
          $$ReceiptLineRowsTableFilterComposer,
          $$ReceiptLineRowsTableOrderingComposer,
          $$ReceiptLineRowsTableAnnotationComposer,
          $$ReceiptLineRowsTableCreateCompanionBuilder,
          $$ReceiptLineRowsTableUpdateCompanionBuilder,
          (ReceiptLineRow, $$ReceiptLineRowsTableReferences),
          ReceiptLineRow,
          PrefetchHooks Function({bool receiptId})
        > {
  $$ReceiptLineRowsTableTableManager(
    _$KassaDatabase db,
    $ReceiptLineRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReceiptLineRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReceiptLineRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReceiptLineRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> receiptId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> info = const Value.absent(),
                Value<int> unitPriceCents = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<int> unitDepositCents = const Value.absent(),
                Value<int> gross20Cents = const Value.absent(),
                Value<int> gross10Cents = const Value.absent(),
                Value<int> gross13Cents = const Value.absent(),
                Value<int> gross0Cents = const Value.absent(),
                Value<int> gross19Cents = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReceiptLineRowsCompanion(
                receiptId: receiptId,
                position: position,
                itemId: itemId,
                name: name,
                info: info,
                unitPriceCents: unitPriceCents,
                quantity: quantity,
                unitDepositCents: unitDepositCents,
                gross20Cents: gross20Cents,
                gross10Cents: gross10Cents,
                gross13Cents: gross13Cents,
                gross0Cents: gross0Cents,
                gross19Cents: gross19Cents,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String receiptId,
                required int position,
                required String itemId,
                required String name,
                Value<String?> info = const Value.absent(),
                required int unitPriceCents,
                required int quantity,
                required int unitDepositCents,
                Value<int> gross20Cents = const Value.absent(),
                Value<int> gross10Cents = const Value.absent(),
                Value<int> gross13Cents = const Value.absent(),
                Value<int> gross0Cents = const Value.absent(),
                Value<int> gross19Cents = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReceiptLineRowsCompanion.insert(
                receiptId: receiptId,
                position: position,
                itemId: itemId,
                name: name,
                info: info,
                unitPriceCents: unitPriceCents,
                quantity: quantity,
                unitDepositCents: unitDepositCents,
                gross20Cents: gross20Cents,
                gross10Cents: gross10Cents,
                gross13Cents: gross13Cents,
                gross0Cents: gross0Cents,
                gross19Cents: gross19Cents,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReceiptLineRowsTable, ReceiptLineRow>(table),
                  $$ReceiptLineRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({receiptId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (receiptId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.receiptId,
                        referencedTable: $$ReceiptLineRowsTableReferences
                            ._receiptIdTable(db),
                        referencedColumn: $$ReceiptLineRowsTableReferences
                            ._receiptIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReceiptLineRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $ReceiptLineRowsTable,
      ReceiptLineRow,
      $$ReceiptLineRowsTableFilterComposer,
      $$ReceiptLineRowsTableOrderingComposer,
      $$ReceiptLineRowsTableAnnotationComposer,
      $$ReceiptLineRowsTableCreateCompanionBuilder,
      $$ReceiptLineRowsTableUpdateCompanionBuilder,
      (ReceiptLineRow, $$ReceiptLineRowsTableReferences),
      ReceiptLineRow,
      PrefetchHooks Function({bool receiptId})
    >;
typedef $$ReceiptLineOptionRowsTableCreateCompanionBuilder =
    ReceiptLineOptionRowsCompanion Function({
      required String receiptId,
      required int linePosition,
      required int position,
      required String groupName,
      required String optionName,
      required int surchargeCents,
      Value<int> rowid,
    });
typedef $$ReceiptLineOptionRowsTableUpdateCompanionBuilder =
    ReceiptLineOptionRowsCompanion Function({
      Value<String> receiptId,
      Value<int> linePosition,
      Value<int> position,
      Value<String> groupName,
      Value<String> optionName,
      Value<int> surchargeCents,
      Value<int> rowid,
    });

class $$ReceiptLineOptionRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $ReceiptLineOptionRowsTable> {
  $$ReceiptLineOptionRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get receiptId => $composableBuilder(
    column: $table.receiptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get linePosition => $composableBuilder(
    column: $table.linePosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get optionName => $composableBuilder(
    column: $table.optionName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get surchargeCents => $composableBuilder(
    column: $table.surchargeCents,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReceiptLineOptionRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $ReceiptLineOptionRowsTable> {
  $$ReceiptLineOptionRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get receiptId => $composableBuilder(
    column: $table.receiptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get linePosition => $composableBuilder(
    column: $table.linePosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get optionName => $composableBuilder(
    column: $table.optionName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get surchargeCents => $composableBuilder(
    column: $table.surchargeCents,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReceiptLineOptionRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $ReceiptLineOptionRowsTable> {
  $$ReceiptLineOptionRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get receiptId =>
      $composableBuilder(column: $table.receiptId, builder: (column) => column);

  GeneratedColumn<int> get linePosition => $composableBuilder(
    column: $table.linePosition,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<String> get optionName => $composableBuilder(
    column: $table.optionName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get surchargeCents => $composableBuilder(
    column: $table.surchargeCents,
    builder: (column) => column,
  );
}

class $$ReceiptLineOptionRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $ReceiptLineOptionRowsTable,
          ReceiptLineOptionRow,
          $$ReceiptLineOptionRowsTableFilterComposer,
          $$ReceiptLineOptionRowsTableOrderingComposer,
          $$ReceiptLineOptionRowsTableAnnotationComposer,
          $$ReceiptLineOptionRowsTableCreateCompanionBuilder,
          $$ReceiptLineOptionRowsTableUpdateCompanionBuilder,
          (
            ReceiptLineOptionRow,
            BaseReferences<
              _$KassaDatabase,
              $ReceiptLineOptionRowsTable,
              ReceiptLineOptionRow
            >,
          ),
          ReceiptLineOptionRow,
          PrefetchHooks Function()
        > {
  $$ReceiptLineOptionRowsTableTableManager(
    _$KassaDatabase db,
    $ReceiptLineOptionRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReceiptLineOptionRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ReceiptLineOptionRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ReceiptLineOptionRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> receiptId = const Value.absent(),
                Value<int> linePosition = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> groupName = const Value.absent(),
                Value<String> optionName = const Value.absent(),
                Value<int> surchargeCents = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReceiptLineOptionRowsCompanion(
                receiptId: receiptId,
                linePosition: linePosition,
                position: position,
                groupName: groupName,
                optionName: optionName,
                surchargeCents: surchargeCents,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String receiptId,
                required int linePosition,
                required int position,
                required String groupName,
                required String optionName,
                required int surchargeCents,
                Value<int> rowid = const Value.absent(),
              }) => ReceiptLineOptionRowsCompanion.insert(
                receiptId: receiptId,
                linePosition: linePosition,
                position: position,
                groupName: groupName,
                optionName: optionName,
                surchargeCents: surchargeCents,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ReceiptLineOptionRowsTable,
                    ReceiptLineOptionRow
                  >(table),
                  BaseReferences<
                    _$KassaDatabase,
                    $ReceiptLineOptionRowsTable,
                    ReceiptLineOptionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReceiptLineOptionRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $ReceiptLineOptionRowsTable,
      ReceiptLineOptionRow,
      $$ReceiptLineOptionRowsTableFilterComposer,
      $$ReceiptLineOptionRowsTableOrderingComposer,
      $$ReceiptLineOptionRowsTableAnnotationComposer,
      $$ReceiptLineOptionRowsTableCreateCompanionBuilder,
      $$ReceiptLineOptionRowsTableUpdateCompanionBuilder,
      (
        ReceiptLineOptionRow,
        BaseReferences<
          _$KassaDatabase,
          $ReceiptLineOptionRowsTable,
          ReceiptLineOptionRow
        >,
      ),
      ReceiptLineOptionRow,
      PrefetchHooks Function()
    >;
typedef $$PaymentRowsTableCreateCompanionBuilder =
    PaymentRowsCompanion Function({
      required String receiptId,
      required String kind,
      required int amountCents,
      required int givenCents,
      required int changeCents,
      Value<String?> provider,
      Value<String?> providerTxCode,
      Value<String?> cardScheme,
      Value<String?> cardLast4,
      Value<int> rowid,
    });
typedef $$PaymentRowsTableUpdateCompanionBuilder =
    PaymentRowsCompanion Function({
      Value<String> receiptId,
      Value<String> kind,
      Value<int> amountCents,
      Value<int> givenCents,
      Value<int> changeCents,
      Value<String?> provider,
      Value<String?> providerTxCode,
      Value<String?> cardScheme,
      Value<String?> cardLast4,
      Value<int> rowid,
    });

final class $$PaymentRowsTableReferences
    extends BaseReferences<_$KassaDatabase, $PaymentRowsTable, PaymentRow> {
  $$PaymentRowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ReceiptRowsTable _receiptIdTable(_$KassaDatabase db) =>
      db.receiptRows.createAlias('payments__receipt_id__receipts__id');

  $$ReceiptRowsTableProcessedTableManager get receiptId {
    final $_column = $_itemColumn<String>('receipt_id')!;

    final manager = $$ReceiptRowsTableTableManager(
      $_db,
      $_db.receiptRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_receiptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PaymentRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $PaymentRowsTable> {
  $$PaymentRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get givenCents => $composableBuilder(
    column: $table.givenCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changeCents => $composableBuilder(
    column: $table.changeCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerTxCode => $composableBuilder(
    column: $table.providerTxCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardScheme => $composableBuilder(
    column: $table.cardScheme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardLast4 => $composableBuilder(
    column: $table.cardLast4,
    builder: (column) => ColumnFilters(column),
  );

  $$ReceiptRowsTableFilterComposer get receiptId {
    final $$ReceiptRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receiptRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptRowsTableFilterComposer(
            $db: $db,
            $table: $db.receiptRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $PaymentRowsTable> {
  $$PaymentRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get givenCents => $composableBuilder(
    column: $table.givenCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changeCents => $composableBuilder(
    column: $table.changeCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerTxCode => $composableBuilder(
    column: $table.providerTxCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardScheme => $composableBuilder(
    column: $table.cardScheme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardLast4 => $composableBuilder(
    column: $table.cardLast4,
    builder: (column) => ColumnOrderings(column),
  );

  $$ReceiptRowsTableOrderingComposer get receiptId {
    final $$ReceiptRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receiptRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptRowsTableOrderingComposer(
            $db: $db,
            $table: $db.receiptRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $PaymentRowsTable> {
  $$PaymentRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get givenCents => $composableBuilder(
    column: $table.givenCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get changeCents => $composableBuilder(
    column: $table.changeCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get providerTxCode => $composableBuilder(
    column: $table.providerTxCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cardScheme => $composableBuilder(
    column: $table.cardScheme,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cardLast4 =>
      $composableBuilder(column: $table.cardLast4, builder: (column) => column);

  $$ReceiptRowsTableAnnotationComposer get receiptId {
    final $$ReceiptRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receiptRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.receiptRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $PaymentRowsTable,
          PaymentRow,
          $$PaymentRowsTableFilterComposer,
          $$PaymentRowsTableOrderingComposer,
          $$PaymentRowsTableAnnotationComposer,
          $$PaymentRowsTableCreateCompanionBuilder,
          $$PaymentRowsTableUpdateCompanionBuilder,
          (PaymentRow, $$PaymentRowsTableReferences),
          PaymentRow,
          PrefetchHooks Function({bool receiptId})
        > {
  $$PaymentRowsTableTableManager(_$KassaDatabase db, $PaymentRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PaymentRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PaymentRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PaymentRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> receiptId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<int> givenCents = const Value.absent(),
                Value<int> changeCents = const Value.absent(),
                Value<String?> provider = const Value.absent(),
                Value<String?> providerTxCode = const Value.absent(),
                Value<String?> cardScheme = const Value.absent(),
                Value<String?> cardLast4 = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaymentRowsCompanion(
                receiptId: receiptId,
                kind: kind,
                amountCents: amountCents,
                givenCents: givenCents,
                changeCents: changeCents,
                provider: provider,
                providerTxCode: providerTxCode,
                cardScheme: cardScheme,
                cardLast4: cardLast4,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String receiptId,
                required String kind,
                required int amountCents,
                required int givenCents,
                required int changeCents,
                Value<String?> provider = const Value.absent(),
                Value<String?> providerTxCode = const Value.absent(),
                Value<String?> cardScheme = const Value.absent(),
                Value<String?> cardLast4 = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaymentRowsCompanion.insert(
                receiptId: receiptId,
                kind: kind,
                amountCents: amountCents,
                givenCents: givenCents,
                changeCents: changeCents,
                provider: provider,
                providerTxCode: providerTxCode,
                cardScheme: cardScheme,
                cardLast4: cardLast4,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PaymentRowsTable, PaymentRow>(table),
                  $$PaymentRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({receiptId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (receiptId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.receiptId,
                        referencedTable: $$PaymentRowsTableReferences
                            ._receiptIdTable(db),
                        referencedColumn: $$PaymentRowsTableReferences
                            ._receiptIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PaymentRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $PaymentRowsTable,
      PaymentRow,
      $$PaymentRowsTableFilterComposer,
      $$PaymentRowsTableOrderingComposer,
      $$PaymentRowsTableAnnotationComposer,
      $$PaymentRowsTableCreateCompanionBuilder,
      $$PaymentRowsTableUpdateCompanionBuilder,
      (PaymentRow, $$PaymentRowsTableReferences),
      PaymentRow,
      PrefetchHooks Function({bool receiptId})
    >;
typedef $$PendingCardPaymentRowsTableCreateCompanionBuilder =
    PendingCardPaymentRowsCompanion Function({
      required String id,
      required String cartJson,
      required int amountCents,
      required String staffId,
      required String staffName,
      required DateTime startedAt,
      required String state,
      Value<int> rowid,
    });
typedef $$PendingCardPaymentRowsTableUpdateCompanionBuilder =
    PendingCardPaymentRowsCompanion Function({
      Value<String> id,
      Value<String> cartJson,
      Value<int> amountCents,
      Value<String> staffId,
      Value<String> staffName,
      Value<DateTime> startedAt,
      Value<String> state,
      Value<int> rowid,
    });

class $$PendingCardPaymentRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $PendingCardPaymentRowsTable> {
  $$PendingCardPaymentRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cartJson => $composableBuilder(
    column: $table.cartJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get staffId => $composableBuilder(
    column: $table.staffId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get staffName => $composableBuilder(
    column: $table.staffName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingCardPaymentRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $PendingCardPaymentRowsTable> {
  $$PendingCardPaymentRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cartJson => $composableBuilder(
    column: $table.cartJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get staffId => $composableBuilder(
    column: $table.staffId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get staffName => $composableBuilder(
    column: $table.staffName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingCardPaymentRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $PendingCardPaymentRowsTable> {
  $$PendingCardPaymentRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get cartJson =>
      $composableBuilder(column: $table.cartJson, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get staffId =>
      $composableBuilder(column: $table.staffId, builder: (column) => column);

  GeneratedColumn<String> get staffName =>
      $composableBuilder(column: $table.staffName, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);
}

class $$PendingCardPaymentRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $PendingCardPaymentRowsTable,
          PendingCardPaymentRow,
          $$PendingCardPaymentRowsTableFilterComposer,
          $$PendingCardPaymentRowsTableOrderingComposer,
          $$PendingCardPaymentRowsTableAnnotationComposer,
          $$PendingCardPaymentRowsTableCreateCompanionBuilder,
          $$PendingCardPaymentRowsTableUpdateCompanionBuilder,
          (
            PendingCardPaymentRow,
            BaseReferences<
              _$KassaDatabase,
              $PendingCardPaymentRowsTable,
              PendingCardPaymentRow
            >,
          ),
          PendingCardPaymentRow,
          PrefetchHooks Function()
        > {
  $$PendingCardPaymentRowsTableTableManager(
    _$KassaDatabase db,
    $PendingCardPaymentRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingCardPaymentRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PendingCardPaymentRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PendingCardPaymentRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> cartJson = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<String> staffId = const Value.absent(),
                Value<String> staffName = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingCardPaymentRowsCompanion(
                id: id,
                cartJson: cartJson,
                amountCents: amountCents,
                staffId: staffId,
                staffName: staffName,
                startedAt: startedAt,
                state: state,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String cartJson,
                required int amountCents,
                required String staffId,
                required String staffName,
                required DateTime startedAt,
                required String state,
                Value<int> rowid = const Value.absent(),
              }) => PendingCardPaymentRowsCompanion.insert(
                id: id,
                cartJson: cartJson,
                amountCents: amountCents,
                staffId: staffId,
                staffName: staffName,
                startedAt: startedAt,
                state: state,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $PendingCardPaymentRowsTable,
                    PendingCardPaymentRow
                  >(table),
                  BaseReferences<
                    _$KassaDatabase,
                    $PendingCardPaymentRowsTable,
                    PendingCardPaymentRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingCardPaymentRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $PendingCardPaymentRowsTable,
      PendingCardPaymentRow,
      $$PendingCardPaymentRowsTableFilterComposer,
      $$PendingCardPaymentRowsTableOrderingComposer,
      $$PendingCardPaymentRowsTableAnnotationComposer,
      $$PendingCardPaymentRowsTableCreateCompanionBuilder,
      $$PendingCardPaymentRowsTableUpdateCompanionBuilder,
      (
        PendingCardPaymentRow,
        BaseReferences<
          _$KassaDatabase,
          $PendingCardPaymentRowsTable,
          PendingCardPaymentRow
        >,
      ),
      PendingCardPaymentRow,
      PrefetchHooks Function()
    >;
typedef $$SyncStateRowsTableCreateCompanionBuilder =
    SyncStateRowsCompanion Function({
      Value<int> id,
      Value<String?> registerId,
      Value<String?> registerName,
      Value<String?> businessId,
      Value<int> pullCursor,
      Value<bool> initialPullDone,
      Value<DateTime?> lastPullAt,
      Value<String?> lastError,
      Value<bool> blocked,
      Value<String?> deviceId,
      Value<DateTime?> lastPushAt,
      Value<bool> photosAutoEnabled,
    });
typedef $$SyncStateRowsTableUpdateCompanionBuilder =
    SyncStateRowsCompanion Function({
      Value<int> id,
      Value<String?> registerId,
      Value<String?> registerName,
      Value<String?> businessId,
      Value<int> pullCursor,
      Value<bool> initialPullDone,
      Value<DateTime?> lastPullAt,
      Value<String?> lastError,
      Value<bool> blocked,
      Value<String?> deviceId,
      Value<DateTime?> lastPushAt,
      Value<bool> photosAutoEnabled,
    });

class $$SyncStateRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $SyncStateRowsTable> {
  $$SyncStateRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get registerId => $composableBuilder(
    column: $table.registerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get registerName => $composableBuilder(
    column: $table.registerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pullCursor => $composableBuilder(
    column: $table.pullCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get initialPullDone => $composableBuilder(
    column: $table.initialPullDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPullAt => $composableBuilder(
    column: $table.lastPullAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get blocked => $composableBuilder(
    column: $table.blocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPushAt => $composableBuilder(
    column: $table.lastPushAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get photosAutoEnabled => $composableBuilder(
    column: $table.photosAutoEnabled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $SyncStateRowsTable> {
  $$SyncStateRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registerId => $composableBuilder(
    column: $table.registerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registerName => $composableBuilder(
    column: $table.registerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pullCursor => $composableBuilder(
    column: $table.pullCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get initialPullDone => $composableBuilder(
    column: $table.initialPullDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPullAt => $composableBuilder(
    column: $table.lastPullAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get blocked => $composableBuilder(
    column: $table.blocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPushAt => $composableBuilder(
    column: $table.lastPushAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get photosAutoEnabled => $composableBuilder(
    column: $table.photosAutoEnabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $SyncStateRowsTable> {
  $$SyncStateRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get registerId => $composableBuilder(
    column: $table.registerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get registerName => $composableBuilder(
    column: $table.registerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get businessId => $composableBuilder(
    column: $table.businessId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pullCursor => $composableBuilder(
    column: $table.pullCursor,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get initialPullDone => $composableBuilder(
    column: $table.initialPullDone,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPullAt => $composableBuilder(
    column: $table.lastPullAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<bool> get blocked =>
      $composableBuilder(column: $table.blocked, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPushAt => $composableBuilder(
    column: $table.lastPushAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get photosAutoEnabled => $composableBuilder(
    column: $table.photosAutoEnabled,
    builder: (column) => column,
  );
}

class $$SyncStateRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $SyncStateRowsTable,
          SyncStateRow,
          $$SyncStateRowsTableFilterComposer,
          $$SyncStateRowsTableOrderingComposer,
          $$SyncStateRowsTableAnnotationComposer,
          $$SyncStateRowsTableCreateCompanionBuilder,
          $$SyncStateRowsTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$KassaDatabase, $SyncStateRowsTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStateRowsTableTableManager(
    _$KassaDatabase db,
    $SyncStateRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> registerId = const Value.absent(),
                Value<String?> registerName = const Value.absent(),
                Value<String?> businessId = const Value.absent(),
                Value<int> pullCursor = const Value.absent(),
                Value<bool> initialPullDone = const Value.absent(),
                Value<DateTime?> lastPullAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<bool> blocked = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<DateTime?> lastPushAt = const Value.absent(),
                Value<bool> photosAutoEnabled = const Value.absent(),
              }) => SyncStateRowsCompanion(
                id: id,
                registerId: registerId,
                registerName: registerName,
                businessId: businessId,
                pullCursor: pullCursor,
                initialPullDone: initialPullDone,
                lastPullAt: lastPullAt,
                lastError: lastError,
                blocked: blocked,
                deviceId: deviceId,
                lastPushAt: lastPushAt,
                photosAutoEnabled: photosAutoEnabled,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> registerId = const Value.absent(),
                Value<String?> registerName = const Value.absent(),
                Value<String?> businessId = const Value.absent(),
                Value<int> pullCursor = const Value.absent(),
                Value<bool> initialPullDone = const Value.absent(),
                Value<DateTime?> lastPullAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<bool> blocked = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<DateTime?> lastPushAt = const Value.absent(),
                Value<bool> photosAutoEnabled = const Value.absent(),
              }) => SyncStateRowsCompanion.insert(
                id: id,
                registerId: registerId,
                registerName: registerName,
                businessId: businessId,
                pullCursor: pullCursor,
                initialPullDone: initialPullDone,
                lastPullAt: lastPullAt,
                lastError: lastError,
                blocked: blocked,
                deviceId: deviceId,
                lastPushAt: lastPushAt,
                photosAutoEnabled: photosAutoEnabled,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStateRowsTable, SyncStateRow>(table),
                  BaseReferences<
                    _$KassaDatabase,
                    $SyncStateRowsTable,
                    SyncStateRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $SyncStateRowsTable,
      SyncStateRow,
      $$SyncStateRowsTableFilterComposer,
      $$SyncStateRowsTableOrderingComposer,
      $$SyncStateRowsTableAnnotationComposer,
      $$SyncStateRowsTableCreateCompanionBuilder,
      $$SyncStateRowsTableUpdateCompanionBuilder,
      (
        SyncStateRow,
        BaseReferences<_$KassaDatabase, $SyncStateRowsTable, SyncStateRow>,
      ),
      SyncStateRow,
      PrefetchHooks Function()
    >;
typedef $$RksvCertificateRowsTableCreateCompanionBuilder =
    RksvCertificateRowsCompanion Function({
      required String serialHex,
      required Uint8List certificate,
      Value<String> issuers,
      Value<int> rowid,
    });
typedef $$RksvCertificateRowsTableUpdateCompanionBuilder =
    RksvCertificateRowsCompanion Function({
      Value<String> serialHex,
      Value<Uint8List> certificate,
      Value<String> issuers,
      Value<int> rowid,
    });

final class $$RksvCertificateRowsTableReferences
    extends
        BaseReferences<
          _$KassaDatabase,
          $RksvCertificateRowsTable,
          RksvCertificateRow
        > {
  $$RksvCertificateRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$RksvChainRowsTable, List<RksvChainRow>>
  _rksvChainRowsRefsTable(_$KassaDatabase db) => MultiTypedResultKey.fromTable(
    db.rksvChainRows,
    aliasName: 'rksv_certificates__serial_hex__rksv_chains__cert_serial',
  );

  $$RksvChainRowsTableProcessedTableManager get rksvChainRowsRefs {
    final manager = $$RksvChainRowsTableTableManager($_db, $_db.rksvChainRows)
        .filter(
          (f) => f.certSerial.serialHex.sqlEquals(
            $_itemColumn<String>('serial_hex')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_rksvChainRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RksvCertificateRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $RksvCertificateRowsTable> {
  $$RksvCertificateRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serialHex => $composableBuilder(
    column: $table.serialHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get certificate => $composableBuilder(
    column: $table.certificate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get issuers => $composableBuilder(
    column: $table.issuers,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> rksvChainRowsRefs(
    Expression<bool> Function($$RksvChainRowsTableFilterComposer f) f,
  ) {
    final $$RksvChainRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serialHex,
      referencedTable: $db.rksvChainRows,
      getReferencedColumn: (t) => t.certSerial,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RksvChainRowsTableFilterComposer(
            $db: $db,
            $table: $db.rksvChainRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RksvCertificateRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $RksvCertificateRowsTable> {
  $$RksvCertificateRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serialHex => $composableBuilder(
    column: $table.serialHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get certificate => $composableBuilder(
    column: $table.certificate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get issuers => $composableBuilder(
    column: $table.issuers,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RksvCertificateRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $RksvCertificateRowsTable> {
  $$RksvCertificateRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serialHex =>
      $composableBuilder(column: $table.serialHex, builder: (column) => column);

  GeneratedColumn<Uint8List> get certificate => $composableBuilder(
    column: $table.certificate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get issuers =>
      $composableBuilder(column: $table.issuers, builder: (column) => column);

  Expression<T> rksvChainRowsRefs<T extends Object>(
    Expression<T> Function($$RksvChainRowsTableAnnotationComposer a) f,
  ) {
    final $$RksvChainRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.serialHex,
      referencedTable: $db.rksvChainRows,
      getReferencedColumn: (t) => t.certSerial,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RksvChainRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.rksvChainRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RksvCertificateRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $RksvCertificateRowsTable,
          RksvCertificateRow,
          $$RksvCertificateRowsTableFilterComposer,
          $$RksvCertificateRowsTableOrderingComposer,
          $$RksvCertificateRowsTableAnnotationComposer,
          $$RksvCertificateRowsTableCreateCompanionBuilder,
          $$RksvCertificateRowsTableUpdateCompanionBuilder,
          (RksvCertificateRow, $$RksvCertificateRowsTableReferences),
          RksvCertificateRow,
          PrefetchHooks Function({bool rksvChainRowsRefs})
        > {
  $$RksvCertificateRowsTableTableManager(
    _$KassaDatabase db,
    $RksvCertificateRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RksvCertificateRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RksvCertificateRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RksvCertificateRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> serialHex = const Value.absent(),
                Value<Uint8List> certificate = const Value.absent(),
                Value<String> issuers = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RksvCertificateRowsCompanion(
                serialHex: serialHex,
                certificate: certificate,
                issuers: issuers,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serialHex,
                required Uint8List certificate,
                Value<String> issuers = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RksvCertificateRowsCompanion.insert(
                serialHex: serialHex,
                certificate: certificate,
                issuers: issuers,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RksvCertificateRowsTable, RksvCertificateRow>(
                    table,
                  ),
                  $$RksvCertificateRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({rksvChainRowsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (rksvChainRowsRefs) db.rksvChainRows,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (rksvChainRowsRefs)
                    await $_getPrefetchedDataByColumns<
                      RksvCertificateRow,
                      $RksvCertificateRowsTable,
                      RksvChainRow,
                      $RksvChainRowsTable
                    >(
                      currentTable: table,
                      referencedTable: $$RksvCertificateRowsTableReferences
                          ._rksvChainRowsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$RksvCertificateRowsTableReferences(
                            db,
                            table,
                            p0,
                          ).rksvChainRowsRefs,
                      currentColumn: 'serial_hex',
                      referencedColumn: 'cert_serial',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RksvCertificateRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $RksvCertificateRowsTable,
      RksvCertificateRow,
      $$RksvCertificateRowsTableFilterComposer,
      $$RksvCertificateRowsTableOrderingComposer,
      $$RksvCertificateRowsTableAnnotationComposer,
      $$RksvCertificateRowsTableCreateCompanionBuilder,
      $$RksvCertificateRowsTableUpdateCompanionBuilder,
      (RksvCertificateRow, $$RksvCertificateRowsTableReferences),
      RksvCertificateRow,
      PrefetchHooks Function({bool rksvChainRowsRefs})
    >;
typedef $$RksvChainRowsTableCreateCompanionBuilder =
    RksvChainRowsCompanion Function({
      Value<int> chain,
      required String mode,
      Value<String> unit,
      required String cashBoxId,
      required String zdaId,
      required String certSerial,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
    });
typedef $$RksvChainRowsTableUpdateCompanionBuilder =
    RksvChainRowsCompanion Function({
      Value<int> chain,
      Value<String> mode,
      Value<String> unit,
      Value<String> cashBoxId,
      Value<String> zdaId,
      Value<String> certSerial,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
    });

final class $$RksvChainRowsTableReferences
    extends BaseReferences<_$KassaDatabase, $RksvChainRowsTable, RksvChainRow> {
  $$RksvChainRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RksvCertificateRowsTable _certSerialTable(_$KassaDatabase db) => db
      .rksvCertificateRows
      .createAlias('rksv_chains__cert_serial__rksv_certificates__serial_hex');

  $$RksvCertificateRowsTableProcessedTableManager get certSerial {
    final $_column = $_itemColumn<String>('cert_serial')!;

    final manager = $$RksvCertificateRowsTableTableManager(
      $_db,
      $_db.rksvCertificateRows,
    ).filter((f) => f.serialHex.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_certSerialTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RksvEntryRowsTable, List<RksvEntryRow>>
  _rksvEntryRowsRefsTable(_$KassaDatabase db) => MultiTypedResultKey.fromTable(
    db.rksvEntryRows,
    aliasName: 'rksv_chains__chain__rksv_entries__chain',
  );

  $$RksvEntryRowsTableProcessedTableManager get rksvEntryRowsRefs {
    final manager = $$RksvEntryRowsTableTableManager(
      $_db,
      $_db.rksvEntryRows,
    ).filter((f) => f.chain.chain.sqlEquals($_itemColumn<int>('chain')!));

    final cache = $_typedResult.readTableOrNull(_rksvEntryRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RksvChainRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $RksvChainRowsTable> {
  $$RksvChainRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get chain => $composableBuilder(
    column: $table.chain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cashBoxId => $composableBuilder(
    column: $table.cashBoxId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get zdaId => $composableBuilder(
    column: $table.zdaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$RksvCertificateRowsTableFilterComposer get certSerial {
    final $$RksvCertificateRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.certSerial,
      referencedTable: $db.rksvCertificateRows,
      getReferencedColumn: (t) => t.serialHex,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RksvCertificateRowsTableFilterComposer(
            $db: $db,
            $table: $db.rksvCertificateRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> rksvEntryRowsRefs(
    Expression<bool> Function($$RksvEntryRowsTableFilterComposer f) f,
  ) {
    final $$RksvEntryRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chain,
      referencedTable: $db.rksvEntryRows,
      getReferencedColumn: (t) => t.chain,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RksvEntryRowsTableFilterComposer(
            $db: $db,
            $table: $db.rksvEntryRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RksvChainRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $RksvChainRowsTable> {
  $$RksvChainRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get chain => $composableBuilder(
    column: $table.chain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cashBoxId => $composableBuilder(
    column: $table.cashBoxId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get zdaId => $composableBuilder(
    column: $table.zdaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$RksvCertificateRowsTableOrderingComposer get certSerial {
    final $$RksvCertificateRowsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.certSerial,
          referencedTable: $db.rksvCertificateRows,
          getReferencedColumn: (t) => t.serialHex,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RksvCertificateRowsTableOrderingComposer(
                $db: $db,
                $table: $db.rksvCertificateRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$RksvChainRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $RksvChainRowsTable> {
  $$RksvChainRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get chain =>
      $composableBuilder(column: $table.chain, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get cashBoxId =>
      $composableBuilder(column: $table.cashBoxId, builder: (column) => column);

  GeneratedColumn<String> get zdaId =>
      $composableBuilder(column: $table.zdaId, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  $$RksvCertificateRowsTableAnnotationComposer get certSerial {
    final $$RksvCertificateRowsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.certSerial,
          referencedTable: $db.rksvCertificateRows,
          getReferencedColumn: (t) => t.serialHex,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RksvCertificateRowsTableAnnotationComposer(
                $db: $db,
                $table: $db.rksvCertificateRows,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> rksvEntryRowsRefs<T extends Object>(
    Expression<T> Function($$RksvEntryRowsTableAnnotationComposer a) f,
  ) {
    final $$RksvEntryRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chain,
      referencedTable: $db.rksvEntryRows,
      getReferencedColumn: (t) => t.chain,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RksvEntryRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.rksvEntryRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RksvChainRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $RksvChainRowsTable,
          RksvChainRow,
          $$RksvChainRowsTableFilterComposer,
          $$RksvChainRowsTableOrderingComposer,
          $$RksvChainRowsTableAnnotationComposer,
          $$RksvChainRowsTableCreateCompanionBuilder,
          $$RksvChainRowsTableUpdateCompanionBuilder,
          (RksvChainRow, $$RksvChainRowsTableReferences),
          RksvChainRow,
          PrefetchHooks Function({bool certSerial, bool rksvEntryRowsRefs})
        > {
  $$RksvChainRowsTableTableManager(
    _$KassaDatabase db,
    $RksvChainRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RksvChainRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RksvChainRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RksvChainRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> chain = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String> cashBoxId = const Value.absent(),
                Value<String> zdaId = const Value.absent(),
                Value<String> certSerial = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
              }) => RksvChainRowsCompanion(
                chain: chain,
                mode: mode,
                unit: unit,
                cashBoxId: cashBoxId,
                zdaId: zdaId,
                certSerial: certSerial,
                startedAt: startedAt,
                endedAt: endedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> chain = const Value.absent(),
                required String mode,
                Value<String> unit = const Value.absent(),
                required String cashBoxId,
                required String zdaId,
                required String certSerial,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
              }) => RksvChainRowsCompanion.insert(
                chain: chain,
                mode: mode,
                unit: unit,
                cashBoxId: cashBoxId,
                zdaId: zdaId,
                certSerial: certSerial,
                startedAt: startedAt,
                endedAt: endedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RksvChainRowsTable, RksvChainRow>(table),
                  $$RksvChainRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({certSerial = false, rksvEntryRowsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (rksvEntryRowsRefs) db.rksvEntryRows,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (certSerial) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.certSerial,
                            referencedTable: $$RksvChainRowsTableReferences
                                ._certSerialTable(db),
                            referencedColumn: $$RksvChainRowsTableReferences
                                ._certSerialTable(db)
                                .serialHex,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (rksvEntryRowsRefs)
                        await $_getPrefetchedDataByColumns<
                          RksvChainRow,
                          $RksvChainRowsTable,
                          RksvEntryRow,
                          $RksvEntryRowsTable
                        >(
                          currentTable: table,
                          referencedTable: $$RksvChainRowsTableReferences
                              ._rksvEntryRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RksvChainRowsTableReferences(
                                db,
                                table,
                                p0,
                              ).rksvEntryRowsRefs,
                          currentColumn: 'chain',
                          referencedColumn: 'chain',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RksvChainRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $RksvChainRowsTable,
      RksvChainRow,
      $$RksvChainRowsTableFilterComposer,
      $$RksvChainRowsTableOrderingComposer,
      $$RksvChainRowsTableAnnotationComposer,
      $$RksvChainRowsTableCreateCompanionBuilder,
      $$RksvChainRowsTableUpdateCompanionBuilder,
      (RksvChainRow, $$RksvChainRowsTableReferences),
      RksvChainRow,
      PrefetchHooks Function({bool certSerial, bool rksvEntryRowsRefs})
    >;
typedef $$RksvEntryRowsTableCreateCompanionBuilder =
    RksvEntryRowsCompanion Function({
      required int chain,
      required int position,
      required String receiptId,
      required String jws,
      required bool damaged,
      required String certSerial,
      Value<int> rowid,
    });
typedef $$RksvEntryRowsTableUpdateCompanionBuilder =
    RksvEntryRowsCompanion Function({
      Value<int> chain,
      Value<int> position,
      Value<String> receiptId,
      Value<String> jws,
      Value<bool> damaged,
      Value<String> certSerial,
      Value<int> rowid,
    });

final class $$RksvEntryRowsTableReferences
    extends BaseReferences<_$KassaDatabase, $RksvEntryRowsTable, RksvEntryRow> {
  $$RksvEntryRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RksvChainRowsTable _chainTable(_$KassaDatabase db) =>
      db.rksvChainRows.createAlias('rksv_entries__chain__rksv_chains__chain');

  $$RksvChainRowsTableProcessedTableManager get chain {
    final $_column = $_itemColumn<int>('chain')!;

    final manager = $$RksvChainRowsTableTableManager(
      $_db,
      $_db.rksvChainRows,
    ).filter((f) => f.chain.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_chainTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ReceiptRowsTable _receiptIdTable(_$KassaDatabase db) =>
      db.receiptRows.createAlias('rksv_entries__receipt_id__receipts__id');

  $$ReceiptRowsTableProcessedTableManager get receiptId {
    final $_column = $_itemColumn<String>('receipt_id')!;

    final manager = $$ReceiptRowsTableTableManager(
      $_db,
      $_db.receiptRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_receiptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RksvEntryRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $RksvEntryRowsTable> {
  $$RksvEntryRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jws => $composableBuilder(
    column: $table.jws,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get damaged => $composableBuilder(
    column: $table.damaged,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get certSerial => $composableBuilder(
    column: $table.certSerial,
    builder: (column) => ColumnFilters(column),
  );

  $$RksvChainRowsTableFilterComposer get chain {
    final $$RksvChainRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chain,
      referencedTable: $db.rksvChainRows,
      getReferencedColumn: (t) => t.chain,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RksvChainRowsTableFilterComposer(
            $db: $db,
            $table: $db.rksvChainRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReceiptRowsTableFilterComposer get receiptId {
    final $$ReceiptRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receiptRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptRowsTableFilterComposer(
            $db: $db,
            $table: $db.receiptRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RksvEntryRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $RksvEntryRowsTable> {
  $$RksvEntryRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jws => $composableBuilder(
    column: $table.jws,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get damaged => $composableBuilder(
    column: $table.damaged,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get certSerial => $composableBuilder(
    column: $table.certSerial,
    builder: (column) => ColumnOrderings(column),
  );

  $$RksvChainRowsTableOrderingComposer get chain {
    final $$RksvChainRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chain,
      referencedTable: $db.rksvChainRows,
      getReferencedColumn: (t) => t.chain,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RksvChainRowsTableOrderingComposer(
            $db: $db,
            $table: $db.rksvChainRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReceiptRowsTableOrderingComposer get receiptId {
    final $$ReceiptRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receiptRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptRowsTableOrderingComposer(
            $db: $db,
            $table: $db.receiptRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RksvEntryRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $RksvEntryRowsTable> {
  $$RksvEntryRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get jws =>
      $composableBuilder(column: $table.jws, builder: (column) => column);

  GeneratedColumn<bool> get damaged =>
      $composableBuilder(column: $table.damaged, builder: (column) => column);

  GeneratedColumn<String> get certSerial => $composableBuilder(
    column: $table.certSerial,
    builder: (column) => column,
  );

  $$RksvChainRowsTableAnnotationComposer get chain {
    final $$RksvChainRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chain,
      referencedTable: $db.rksvChainRows,
      getReferencedColumn: (t) => t.chain,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RksvChainRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.rksvChainRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReceiptRowsTableAnnotationComposer get receiptId {
    final $$ReceiptRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receiptRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.receiptRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RksvEntryRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $RksvEntryRowsTable,
          RksvEntryRow,
          $$RksvEntryRowsTableFilterComposer,
          $$RksvEntryRowsTableOrderingComposer,
          $$RksvEntryRowsTableAnnotationComposer,
          $$RksvEntryRowsTableCreateCompanionBuilder,
          $$RksvEntryRowsTableUpdateCompanionBuilder,
          (RksvEntryRow, $$RksvEntryRowsTableReferences),
          RksvEntryRow,
          PrefetchHooks Function({bool chain, bool receiptId})
        > {
  $$RksvEntryRowsTableTableManager(
    _$KassaDatabase db,
    $RksvEntryRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RksvEntryRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RksvEntryRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RksvEntryRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> chain = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> receiptId = const Value.absent(),
                Value<String> jws = const Value.absent(),
                Value<bool> damaged = const Value.absent(),
                Value<String> certSerial = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RksvEntryRowsCompanion(
                chain: chain,
                position: position,
                receiptId: receiptId,
                jws: jws,
                damaged: damaged,
                certSerial: certSerial,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int chain,
                required int position,
                required String receiptId,
                required String jws,
                required bool damaged,
                required String certSerial,
                Value<int> rowid = const Value.absent(),
              }) => RksvEntryRowsCompanion.insert(
                chain: chain,
                position: position,
                receiptId: receiptId,
                jws: jws,
                damaged: damaged,
                certSerial: certSerial,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RksvEntryRowsTable, RksvEntryRow>(table),
                  $$RksvEntryRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({chain = false, receiptId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (chain) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.chain,
                        referencedTable: $$RksvEntryRowsTableReferences
                            ._chainTable(db),
                        referencedColumn: $$RksvEntryRowsTableReferences
                            ._chainTable(db)
                            .chain,
                      ) as T;
                    }
                    if (receiptId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.receiptId,
                        referencedTable: $$RksvEntryRowsTableReferences
                            ._receiptIdTable(db),
                        referencedColumn: $$RksvEntryRowsTableReferences
                            ._receiptIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RksvEntryRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $RksvEntryRowsTable,
      RksvEntryRow,
      $$RksvEntryRowsTableFilterComposer,
      $$RksvEntryRowsTableOrderingComposer,
      $$RksvEntryRowsTableAnnotationComposer,
      $$RksvEntryRowsTableCreateCompanionBuilder,
      $$RksvEntryRowsTableUpdateCompanionBuilder,
      (RksvEntryRow, $$RksvEntryRowsTableReferences),
      RksvEntryRow,
      PrefetchHooks Function({bool chain, bool receiptId})
    >;
typedef $$RksvStateRowsTableCreateCompanionBuilder =
    RksvStateRowsCompanion Function({
      Value<int> id,
      Value<String> mode,
      Value<int?> chain,
      Value<int> counterCents,
      Value<DateTime?> outageSince,
      Value<String?> outageReason,
      Value<String> tasks,
      Value<String?> notice,
    });
typedef $$RksvStateRowsTableUpdateCompanionBuilder =
    RksvStateRowsCompanion Function({
      Value<int> id,
      Value<String> mode,
      Value<int?> chain,
      Value<int> counterCents,
      Value<DateTime?> outageSince,
      Value<String?> outageReason,
      Value<String> tasks,
      Value<String?> notice,
    });

class $$RksvStateRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $RksvStateRowsTable> {
  $$RksvStateRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chain => $composableBuilder(
    column: $table.chain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get counterCents => $composableBuilder(
    column: $table.counterCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get outageSince => $composableBuilder(
    column: $table.outageSince,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outageReason => $composableBuilder(
    column: $table.outageReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tasks => $composableBuilder(
    column: $table.tasks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notice => $composableBuilder(
    column: $table.notice,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RksvStateRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $RksvStateRowsTable> {
  $$RksvStateRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chain => $composableBuilder(
    column: $table.chain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get counterCents => $composableBuilder(
    column: $table.counterCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get outageSince => $composableBuilder(
    column: $table.outageSince,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outageReason => $composableBuilder(
    column: $table.outageReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tasks => $composableBuilder(
    column: $table.tasks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notice => $composableBuilder(
    column: $table.notice,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RksvStateRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $RksvStateRowsTable> {
  $$RksvStateRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get chain =>
      $composableBuilder(column: $table.chain, builder: (column) => column);

  GeneratedColumn<int> get counterCents => $composableBuilder(
    column: $table.counterCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get outageSince => $composableBuilder(
    column: $table.outageSince,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outageReason => $composableBuilder(
    column: $table.outageReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tasks =>
      $composableBuilder(column: $table.tasks, builder: (column) => column);

  GeneratedColumn<String> get notice =>
      $composableBuilder(column: $table.notice, builder: (column) => column);
}

class $$RksvStateRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $RksvStateRowsTable,
          RksvStateRow,
          $$RksvStateRowsTableFilterComposer,
          $$RksvStateRowsTableOrderingComposer,
          $$RksvStateRowsTableAnnotationComposer,
          $$RksvStateRowsTableCreateCompanionBuilder,
          $$RksvStateRowsTableUpdateCompanionBuilder,
          (
            RksvStateRow,
            BaseReferences<_$KassaDatabase, $RksvStateRowsTable, RksvStateRow>,
          ),
          RksvStateRow,
          PrefetchHooks Function()
        > {
  $$RksvStateRowsTableTableManager(
    _$KassaDatabase db,
    $RksvStateRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RksvStateRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RksvStateRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RksvStateRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int?> chain = const Value.absent(),
                Value<int> counterCents = const Value.absent(),
                Value<DateTime?> outageSince = const Value.absent(),
                Value<String?> outageReason = const Value.absent(),
                Value<String> tasks = const Value.absent(),
                Value<String?> notice = const Value.absent(),
              }) => RksvStateRowsCompanion(
                id: id,
                mode: mode,
                chain: chain,
                counterCents: counterCents,
                outageSince: outageSince,
                outageReason: outageReason,
                tasks: tasks,
                notice: notice,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int?> chain = const Value.absent(),
                Value<int> counterCents = const Value.absent(),
                Value<DateTime?> outageSince = const Value.absent(),
                Value<String?> outageReason = const Value.absent(),
                Value<String> tasks = const Value.absent(),
                Value<String?> notice = const Value.absent(),
              }) => RksvStateRowsCompanion.insert(
                id: id,
                mode: mode,
                chain: chain,
                counterCents: counterCents,
                outageSince: outageSince,
                outageReason: outageReason,
                tasks: tasks,
                notice: notice,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RksvStateRowsTable, RksvStateRow>(table),
                  BaseReferences<
                    _$KassaDatabase,
                    $RksvStateRowsTable,
                    RksvStateRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RksvStateRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $RksvStateRowsTable,
      RksvStateRow,
      $$RksvStateRowsTableFilterComposer,
      $$RksvStateRowsTableOrderingComposer,
      $$RksvStateRowsTableAnnotationComposer,
      $$RksvStateRowsTableCreateCompanionBuilder,
      $$RksvStateRowsTableUpdateCompanionBuilder,
      (
        RksvStateRow,
        BaseReferences<_$KassaDatabase, $RksvStateRowsTable, RksvStateRow>,
      ),
      RksvStateRow,
      PrefetchHooks Function()
    >;
typedef $$OutboxRowsTableCreateCompanionBuilder = OutboxRowsCompanion Function({
  Value<int> id,
  required String kind,
  required String ref,
  Value<String?> field,
  Value<String?> value,
  Value<DateTime?> changedAt,
  Value<int> rev,
  Value<String> state,
  Value<String?> reason,
});
typedef $$OutboxRowsTableUpdateCompanionBuilder = OutboxRowsCompanion Function({
  Value<int> id,
  Value<String> kind,
  Value<String> ref,
  Value<String?> field,
  Value<String?> value,
  Value<DateTime?> changedAt,
  Value<int> rev,
  Value<String> state,
  Value<String?> reason,
});

class $$OutboxRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $OutboxRowsTable> {
  $$OutboxRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ref => $composableBuilder(
    column: $table.ref,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rev => $composableBuilder(
    column: $table.rev,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $OutboxRowsTable> {
  $$OutboxRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ref => $composableBuilder(
    column: $table.ref,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rev => $composableBuilder(
    column: $table.rev,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $OutboxRowsTable> {
  $$OutboxRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get ref =>
      $composableBuilder(column: $table.ref, builder: (column) => column);

  GeneratedColumn<String> get field =>
      $composableBuilder(column: $table.field, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => column);

  GeneratedColumn<int> get rev =>
      $composableBuilder(column: $table.rev, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);
}

class $$OutboxRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $OutboxRowsTable,
          OutboxRow,
          $$OutboxRowsTableFilterComposer,
          $$OutboxRowsTableOrderingComposer,
          $$OutboxRowsTableAnnotationComposer,
          $$OutboxRowsTableCreateCompanionBuilder,
          $$OutboxRowsTableUpdateCompanionBuilder,
          (
            OutboxRow,
            BaseReferences<_$KassaDatabase, $OutboxRowsTable, OutboxRow>,
          ),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxRowsTableTableManager(_$KassaDatabase db, $OutboxRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> ref = const Value.absent(),
                Value<String?> field = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<DateTime?> changedAt = const Value.absent(),
                Value<int> rev = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> reason = const Value.absent(),
              }) => OutboxRowsCompanion(
                id: id,
                kind: kind,
                ref: ref,
                field: field,
                value: value,
                changedAt: changedAt,
                rev: rev,
                state: state,
                reason: reason,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kind,
                required String ref,
                Value<String?> field = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<DateTime?> changedAt = const Value.absent(),
                Value<int> rev = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> reason = const Value.absent(),
              }) => OutboxRowsCompanion.insert(
                id: id,
                kind: kind,
                ref: ref,
                field: field,
                value: value,
                changedAt: changedAt,
                rev: rev,
                state: state,
                reason: reason,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxRowsTable, OutboxRow>(table),
                  BaseReferences<_$KassaDatabase, $OutboxRowsTable, OutboxRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $OutboxRowsTable,
      OutboxRow,
      $$OutboxRowsTableFilterComposer,
      $$OutboxRowsTableOrderingComposer,
      $$OutboxRowsTableAnnotationComposer,
      $$OutboxRowsTableCreateCompanionBuilder,
      $$OutboxRowsTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$KassaDatabase, $OutboxRowsTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$ReportRowsTableCreateCompanionBuilder = ReportRowsCompanion Function({
  required String id,
  required String kind,
  required DateTime at,
  required String appVersion,
  Value<String?> androidVersion,
  Value<String?> deviceModel,
  Value<int> count,
  required String signature,
  required String content,
  Value<int> rowid,
});
typedef $$ReportRowsTableUpdateCompanionBuilder = ReportRowsCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<DateTime> at,
  Value<String> appVersion,
  Value<String?> androidVersion,
  Value<String?> deviceModel,
  Value<int> count,
  Value<String> signature,
  Value<String> content,
  Value<int> rowid,
});

class $$ReportRowsTableFilterComposer
    extends Composer<_$KassaDatabase, $ReportRowsTable> {
  $$ReportRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get androidVersion => $composableBuilder(
    column: $table.androidVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceModel => $composableBuilder(
    column: $table.deviceModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReportRowsTableOrderingComposer
    extends Composer<_$KassaDatabase, $ReportRowsTable> {
  $$ReportRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get androidVersion => $composableBuilder(
    column: $table.androidVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceModel => $composableBuilder(
    column: $table.deviceModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReportRowsTableAnnotationComposer
    extends Composer<_$KassaDatabase, $ReportRowsTable> {
  $$ReportRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get androidVersion => $composableBuilder(
    column: $table.androidVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceModel => $composableBuilder(
    column: $table.deviceModel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<String> get signature =>
      $composableBuilder(column: $table.signature, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);
}

class $$ReportRowsTableTableManager
    extends
        RootTableManager<
          _$KassaDatabase,
          $ReportRowsTable,
          ReportRow,
          $$ReportRowsTableFilterComposer,
          $$ReportRowsTableOrderingComposer,
          $$ReportRowsTableAnnotationComposer,
          $$ReportRowsTableCreateCompanionBuilder,
          $$ReportRowsTableUpdateCompanionBuilder,
          (
            ReportRow,
            BaseReferences<_$KassaDatabase, $ReportRowsTable, ReportRow>,
          ),
          ReportRow,
          PrefetchHooks Function()
        > {
  $$ReportRowsTableTableManager(_$KassaDatabase db, $ReportRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReportRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReportRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReportRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<String> appVersion = const Value.absent(),
                Value<String?> androidVersion = const Value.absent(),
                Value<String?> deviceModel = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<String> signature = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReportRowsCompanion(
                id: id,
                kind: kind,
                at: at,
                appVersion: appVersion,
                androidVersion: androidVersion,
                deviceModel: deviceModel,
                count: count,
                signature: signature,
                content: content,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required DateTime at,
                required String appVersion,
                Value<String?> androidVersion = const Value.absent(),
                Value<String?> deviceModel = const Value.absent(),
                Value<int> count = const Value.absent(),
                required String signature,
                required String content,
                Value<int> rowid = const Value.absent(),
              }) => ReportRowsCompanion.insert(
                id: id,
                kind: kind,
                at: at,
                appVersion: appVersion,
                androidVersion: androidVersion,
                deviceModel: deviceModel,
                count: count,
                signature: signature,
                content: content,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReportRowsTable, ReportRow>(table),
                  BaseReferences<_$KassaDatabase, $ReportRowsTable, ReportRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReportRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KassaDatabase,
      $ReportRowsTable,
      ReportRow,
      $$ReportRowsTableFilterComposer,
      $$ReportRowsTableOrderingComposer,
      $$ReportRowsTableAnnotationComposer,
      $$ReportRowsTableCreateCompanionBuilder,
      $$ReportRowsTableUpdateCompanionBuilder,
      (ReportRow, BaseReferences<_$KassaDatabase, $ReportRowsTable, ReportRow>),
      ReportRow,
      PrefetchHooks Function()
    >;

class $KassaDatabaseManager {
  final _$KassaDatabase _db;
  $KassaDatabaseManager(this._db);
  $$BusinessRowsTableTableManager get businessRows =>
      $$BusinessRowsTableTableManager(_db, _db.businessRows);
  $$CategoryRowsTableTableManager get categoryRows =>
      $$CategoryRowsTableTableManager(_db, _db.categoryRows);
  $$ItemRowsTableTableManager get itemRows =>
      $$ItemRowsTableTableManager(_db, _db.itemRows);
  $$ModifierTemplateRowsTableTableManager get modifierTemplateRows =>
      $$ModifierTemplateRowsTableTableManager(_db, _db.modifierTemplateRows);
  $$ModifierGroupRowsTableTableManager get modifierGroupRows =>
      $$ModifierGroupRowsTableTableManager(_db, _db.modifierGroupRows);
  $$ModifierOptionRowsTableTableManager get modifierOptionRows =>
      $$ModifierOptionRowsTableTableManager(_db, _db.modifierOptionRows);
  $$StaffRowsTableTableManager get staffRows =>
      $$StaffRowsTableTableManager(_db, _db.staffRows);
  $$SettingsRowsTableTableManager get settingsRows =>
      $$SettingsRowsTableTableManager(_db, _db.settingsRows);
  $$TranslationRowsTableTableManager get translationRows =>
      $$TranslationRowsTableTableManager(_db, _db.translationRows);
  $$BusinessDayRowsTableTableManager get businessDayRows =>
      $$BusinessDayRowsTableTableManager(_db, _db.businessDayRows);
  $$CashMovementRowsTableTableManager get cashMovementRows =>
      $$CashMovementRowsTableTableManager(_db, _db.cashMovementRows);
  $$ReceiptRowsTableTableManager get receiptRows =>
      $$ReceiptRowsTableTableManager(_db, _db.receiptRows);
  $$ReceiptLineRowsTableTableManager get receiptLineRows =>
      $$ReceiptLineRowsTableTableManager(_db, _db.receiptLineRows);
  $$ReceiptLineOptionRowsTableTableManager get receiptLineOptionRows =>
      $$ReceiptLineOptionRowsTableTableManager(_db, _db.receiptLineOptionRows);
  $$PaymentRowsTableTableManager get paymentRows =>
      $$PaymentRowsTableTableManager(_db, _db.paymentRows);
  $$PendingCardPaymentRowsTableTableManager get pendingCardPaymentRows =>
      $$PendingCardPaymentRowsTableTableManager(
        _db,
        _db.pendingCardPaymentRows,
      );
  $$SyncStateRowsTableTableManager get syncStateRows =>
      $$SyncStateRowsTableTableManager(_db, _db.syncStateRows);
  $$RksvCertificateRowsTableTableManager get rksvCertificateRows =>
      $$RksvCertificateRowsTableTableManager(_db, _db.rksvCertificateRows);
  $$RksvChainRowsTableTableManager get rksvChainRows =>
      $$RksvChainRowsTableTableManager(_db, _db.rksvChainRows);
  $$RksvEntryRowsTableTableManager get rksvEntryRows =>
      $$RksvEntryRowsTableTableManager(_db, _db.rksvEntryRows);
  $$RksvStateRowsTableTableManager get rksvStateRows =>
      $$RksvStateRowsTableTableManager(_db, _db.rksvStateRows);
  $$OutboxRowsTableTableManager get outboxRows =>
      $$OutboxRowsTableTableManager(_db, _db.outboxRows);
  $$ReportRowsTableTableManager get reportRows =>
      $$ReportRowsTableTableManager(_db, _db.reportRows);
}
