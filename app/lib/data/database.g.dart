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
  @override
  List<GeneratedColumn> get $columns => [id, name];
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
  const BusinessRow({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  BusinessRowsCompanion toCompanion(bool nullToAbsent) {
    return BusinessRowsCompanion(id: Value(id), name: Value(name));
  }

  factory BusinessRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BusinessRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  BusinessRow copyWith({int? id, String? name}) =>
      BusinessRow(id: id ?? this.id, name: name ?? this.name);
  BusinessRow copyWithCompanion(BusinessRowsCompanion data) {
    return BusinessRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BusinessRow(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BusinessRow && other.id == this.id && other.name == this.name);
}

class BusinessRowsCompanion extends UpdateCompanion<BusinessRow> {
  final Value<int> id;
  final Value<String> name;
  const BusinessRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  BusinessRowsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<BusinessRow> custom({
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  BusinessRowsCompanion copyWith({Value<int>? id, Value<String>? name}) {
    return BusinessRowsCompanion(id: id ?? this.id, name: name ?? this.name);
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BusinessRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name')
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cashDrawerEnabled,
    showImages,
    themeMode,
    voidRequiresChef,
    receiptDraft,
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
  const SettingsRow({
    required this.id,
    required this.cashDrawerEnabled,
    required this.showImages,
    required this.themeMode,
    required this.voidRequiresChef,
    this.receiptDraft,
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
    };
  }

  SettingsRow copyWith({
    int? id,
    bool? cashDrawerEnabled,
    bool? showImages,
    String? themeMode,
    bool? voidRequiresChef,
    Value<String?> receiptDraft = const Value.absent(),
  }) => SettingsRow(
    id: id ?? this.id,
    cashDrawerEnabled: cashDrawerEnabled ?? this.cashDrawerEnabled,
    showImages: showImages ?? this.showImages,
    themeMode: themeMode ?? this.themeMode,
    voidRequiresChef: voidRequiresChef ?? this.voidRequiresChef,
    receiptDraft: receiptDraft.present ? receiptDraft.value : this.receiptDraft,
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
          ..write('receiptDraft: $receiptDraft')
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
          other.receiptDraft == this.receiptDraft);
}

class SettingsRowsCompanion extends UpdateCompanion<SettingsRow> {
  final Value<int> id;
  final Value<bool> cashDrawerEnabled;
  final Value<bool> showImages;
  final Value<String> themeMode;
  final Value<bool> voidRequiresChef;
  final Value<String?> receiptDraft;
  const SettingsRowsCompanion({
    this.id = const Value.absent(),
    this.cashDrawerEnabled = const Value.absent(),
    this.showImages = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.voidRequiresChef = const Value.absent(),
    this.receiptDraft = const Value.absent(),
  });
  SettingsRowsCompanion.insert({
    this.id = const Value.absent(),
    this.cashDrawerEnabled = const Value.absent(),
    this.showImages = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.voidRequiresChef = const Value.absent(),
    this.receiptDraft = const Value.absent(),
  });
  static Insertable<SettingsRow> custom({
    Expression<int>? id,
    Expression<bool>? cashDrawerEnabled,
    Expression<bool>? showImages,
    Expression<String>? themeMode,
    Expression<bool>? voidRequiresChef,
    Expression<String>? receiptDraft,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cashDrawerEnabled != null) 'cash_drawer_enabled': cashDrawerEnabled,
      if (showImages != null) 'show_images': showImages,
      if (themeMode != null) 'theme_mode': themeMode,
      if (voidRequiresChef != null) 'void_requires_chef': voidRequiresChef,
      if (receiptDraft != null) 'receipt_draft': receiptDraft,
    });
  }

  SettingsRowsCompanion copyWith({
    Value<int>? id,
    Value<bool>? cashDrawerEnabled,
    Value<bool>? showImages,
    Value<String>? themeMode,
    Value<bool>? voidRequiresChef,
    Value<String?>? receiptDraft,
  }) {
    return SettingsRowsCompanion(
      id: id ?? this.id,
      cashDrawerEnabled: cashDrawerEnabled ?? this.cashDrawerEnabled,
      showImages: showImages ?? this.showImages,
      themeMode: themeMode ?? this.themeMode,
      voidRequiresChef: voidRequiresChef ?? this.voidRequiresChef,
      receiptDraft: receiptDraft ?? this.receiptDraft,
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
          ..write('receiptDraft: $receiptDraft')
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
  ];
}

typedef $$BusinessRowsTableCreateCompanionBuilder =
    BusinessRowsCompanion Function({Value<int> id, required String name});
typedef $$BusinessRowsTableUpdateCompanionBuilder =
    BusinessRowsCompanion Function({Value<int> id, Value<String> name});

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
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
          }) => BusinessRowsCompanion(id: id, name: name),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
          }) => BusinessRowsCompanion.insert(id: id, name: name),
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
    });
typedef $$SettingsRowsTableUpdateCompanionBuilder =
    SettingsRowsCompanion Function({
      Value<int> id,
      Value<bool> cashDrawerEnabled,
      Value<bool> showImages,
      Value<String> themeMode,
      Value<bool> voidRequiresChef,
      Value<String?> receiptDraft,
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
              }) => SettingsRowsCompanion(
                id: id,
                cashDrawerEnabled: cashDrawerEnabled,
                showImages: showImages,
                themeMode: themeMode,
                voidRequiresChef: voidRequiresChef,
                receiptDraft: receiptDraft,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> cashDrawerEnabled = const Value.absent(),
                Value<bool> showImages = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<bool> voidRequiresChef = const Value.absent(),
                Value<String?> receiptDraft = const Value.absent(),
              }) => SettingsRowsCompanion.insert(
                id: id,
                cashDrawerEnabled: cashDrawerEnabled,
                showImages: showImages,
                themeMode: themeMode,
                voidRequiresChef: voidRequiresChef,
                receiptDraft: receiptDraft,
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
}
