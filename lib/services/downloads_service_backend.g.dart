// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: deprecated_member_use_from_same_package, strict_raw_type

// dart format off

part of 'downloads_service_backend.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetIsarTaskDataCollection on Isar {
  IsarCollection<IsarTaskData> get isarTaskDatas => this.collection();
}

const IsarTaskDataSchema = CollectionSchema(
  name: r'IsarTaskData',
  id: 5660606271041189933,
  properties: {
    r'age': PropertySchema(id: 0, name: r'age', type: IsarType.long),
    r'jsonData': PropertySchema(
      id: 1,
      name: r'jsonData',
      type: IsarType.string,
    ),
    r'type': PropertySchema(
      id: 2,
      name: r'type',
      type: IsarType.byte,
      enumMap: _IsarTaskDatatypeEnumValueMap,
    ),
  },

  estimateSize: _isarTaskDataEstimateSize,
  serialize: _isarTaskDataSerialize,
  deserialize: _isarTaskDataDeserialize,
  deserializeProp: _isarTaskDataDeserializeProp,
  idName: r'id',
  indexes: {
    r'type': IndexSchema(
      id: 5117122708147080838,
      name: r'type',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'type',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _isarTaskDataGetId,
  getLinks: _isarTaskDataGetLinks,
  attach: _isarTaskDataAttach,
  version: '3.3.2',
);

int _isarTaskDataEstimateSize(
  IsarTaskData object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.jsonData.length * 3;
  return bytesCount;
}

void _isarTaskDataSerialize(
  IsarTaskData object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.age);
  writer.writeString(offsets[1], object.jsonData);
  writer.writeByte(offsets[2], object.type.index);
}

IsarTaskData _isarTaskDataDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = IsarTaskData(
    id,
    _IsarTaskDatatypeValueEnumMap[reader.readByteOrNull(offsets[2])] ??
        IsarTaskDataType.pausedTask,
    reader.readString(offsets[1]),
    reader.readLong(offsets[0]),
  );
  return object;
}

P _isarTaskDataDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (_IsarTaskDatatypeValueEnumMap[reader.readByteOrNull(offset)] ??
              IsarTaskDataType.pausedTask)
          as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _IsarTaskDatatypeEnumValueMap = {
  'pausedTask': 0,
  'taskRecord': 1,
  'resumeData': 2,
  'deleteNode': 3,
  'syncNode': 4,
};
const _IsarTaskDatatypeValueEnumMap = {
  0: IsarTaskDataType.pausedTask,
  1: IsarTaskDataType.taskRecord,
  2: IsarTaskDataType.resumeData,
  3: IsarTaskDataType.deleteNode,
  4: IsarTaskDataType.syncNode,
};

Id _isarTaskDataGetId(IsarTaskData object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _isarTaskDataGetLinks(IsarTaskData object) {
  return [];
}

void _isarTaskDataAttach(
  IsarCollection<dynamic> col,
  Id id,
  IsarTaskData object,
) {}

extension IsarTaskDataQueryWhereSort
    on QueryBuilder<IsarTaskData, IsarTaskData, QWhere> {
  QueryBuilder<IsarTaskData, IsarTaskData, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterWhere> anyType() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'type'),
      );
    });
  }
}

extension IsarTaskDataQueryWhere
    on QueryBuilder<IsarTaskData, IsarTaskData, QWhereClause> {
  QueryBuilder<IsarTaskData, IsarTaskData, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterWhereClause> typeEqualTo(
    IsarTaskDataType type,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'type', value: [type]),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterWhereClause> typeNotEqualTo(
    IsarTaskDataType type,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'type',
                lower: [],
                upper: [type],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'type',
                lower: [type],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'type',
                lower: [type],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'type',
                lower: [],
                upper: [type],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterWhereClause> typeGreaterThan(
    IsarTaskDataType type, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'type',
          lower: [type],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterWhereClause> typeLessThan(
    IsarTaskDataType type, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'type',
          lower: [],
          upper: [type],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterWhereClause> typeBetween(
    IsarTaskDataType lowerType,
    IsarTaskDataType upperType, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'type',
          lower: [lowerType],
          includeLower: includeLower,
          upper: [upperType],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension IsarTaskDataQueryFilter
    on QueryBuilder<IsarTaskData, IsarTaskData, QFilterCondition> {
  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition> ageEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'age', value: value),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition>
  ageGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'age',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition> ageLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'age',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition> ageBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'age',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition>
  jsonDataEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'jsonData',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition>
  jsonDataGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'jsonData',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition>
  jsonDataLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'jsonData',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition>
  jsonDataBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'jsonData',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition>
  jsonDataStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'jsonData',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition>
  jsonDataEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'jsonData',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition>
  jsonDataContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'jsonData',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition>
  jsonDataMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'jsonData',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition>
  jsonDataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'jsonData', value: ''),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition>
  jsonDataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'jsonData', value: ''),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition> typeEqualTo(
    IsarTaskDataType value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'type', value: value),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition>
  typeGreaterThan(IsarTaskDataType value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'type',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition> typeLessThan(
    IsarTaskDataType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'type',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterFilterCondition> typeBetween(
    IsarTaskDataType lower,
    IsarTaskDataType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'type',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension IsarTaskDataQueryObject
    on QueryBuilder<IsarTaskData, IsarTaskData, QFilterCondition> {}

extension IsarTaskDataQueryLinks
    on QueryBuilder<IsarTaskData, IsarTaskData, QFilterCondition> {}

extension IsarTaskDataQuerySortBy
    on QueryBuilder<IsarTaskData, IsarTaskData, QSortBy> {
  QueryBuilder<IsarTaskData, IsarTaskData, QAfterSortBy> sortByAge() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'age', Sort.asc);
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterSortBy> sortByAgeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'age', Sort.desc);
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterSortBy> sortByJsonData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jsonData', Sort.asc);
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterSortBy> sortByJsonDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jsonData', Sort.desc);
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterSortBy> sortByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterSortBy> sortByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }
}

extension IsarTaskDataQuerySortThenBy
    on QueryBuilder<IsarTaskData, IsarTaskData, QSortThenBy> {
  QueryBuilder<IsarTaskData, IsarTaskData, QAfterSortBy> thenByAge() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'age', Sort.asc);
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterSortBy> thenByAgeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'age', Sort.desc);
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterSortBy> thenByJsonData() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jsonData', Sort.asc);
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterSortBy> thenByJsonDataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'jsonData', Sort.desc);
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterSortBy> thenByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.asc);
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QAfterSortBy> thenByTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'type', Sort.desc);
    });
  }
}

extension IsarTaskDataQueryWhereDistinct
    on QueryBuilder<IsarTaskData, IsarTaskData, QDistinct> {
  QueryBuilder<IsarTaskData, IsarTaskData, QDistinct> distinctByAge() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'age');
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QDistinct> distinctByJsonData({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'jsonData', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskData, QDistinct> distinctByType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'type');
    });
  }
}

extension IsarTaskDataQueryProperty
    on QueryBuilder<IsarTaskData, IsarTaskData, QQueryProperty> {
  QueryBuilder<IsarTaskData, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<IsarTaskData, int, QQueryOperations> ageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'age');
    });
  }

  QueryBuilder<IsarTaskData, String, QQueryOperations> jsonDataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'jsonData');
    });
  }

  QueryBuilder<IsarTaskData, IsarTaskDataType, QQueryOperations>
  typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'type');
    });
  }
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyncNode _$SyncNodeFromJson(Map json) => SyncNode(
  stubIsarId: (json['stubIsarId'] as num).toInt(),
  required: json['required'] as bool,
  viewId: _$JsonConverterFromJson<String, BaseItemId>(
    json['viewId'],
    const BaseItemIdConverter().fromJson,
  ),
);

Map<String, dynamic> _$SyncNodeToJson(SyncNode instance) => <String, dynamic>{
  'stubIsarId': instance.stubIsarId,
  'required': instance.required,
  'viewId': _$JsonConverterToJson<String, BaseItemId>(
    instance.viewId,
    const BaseItemIdConverter().toJson,
  ),
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
