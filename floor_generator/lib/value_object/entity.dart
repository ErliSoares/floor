import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:floor_generator/value_object/embedded.dart';
import 'package:floor_generator/value_object/field.dart';
import 'package:floor_generator/value_object/foreign_key.dart';
import 'package:floor_generator/value_object/index.dart';
import 'package:floor_generator/value_object/primary_key.dart';
import 'package:floor_generator/value_object/queryable.dart';

import 'fts.dart';

class Entity extends Queryable {
  final PrimaryKey primaryKey;
  final List<ForeignKey> foreignKeys;
  final List<Index> indices;
  final bool withoutRowid;
  final String valueMappingForInsert;
  final String valueMappingForUpdate;
  final String valueMappingForDelete;
  final Fts? fts;
  final String actionsSave;

  Entity(
      ClassElement classElement,
      String name,
      List<Embedded> embeddeds,
      List<Field> fieldsAll,
      List<Field> fieldsDataBaseSchema,
      List<Field> fieldsQuery,
      this.primaryKey,
      this.foreignKeys,
      this.indices,
      this.withoutRowid,
      String constructor,
      this.valueMappingForInsert,
      this.valueMappingForUpdate,
      this.valueMappingForDelete,
      this.fts,
      [this.actionsSave = ''])
      : super(
            name: name,
            classElement: classElement,
            constructor: constructor,
            fieldsAll: fieldsAll,
            fieldsDataBaseSchema: fieldsDataBaseSchema,
            fieldsQuery: fieldsQuery,
            embeddeds: embeddeds);

  String getCreateTableStatement() {
    final clone = [...fieldsDataBaseSchema];
    fieldsDataBaseSchema.sort((a, b) {
      final int aIndex = clone.indexOf(a);
      final int bIndex = clone.indexOf(b);

      final aIsPrimaryKey = primaryKey.fields.contains(a);
      final bIsPrimaryKey = primaryKey.fields.contains(b);

      if (aIsPrimaryKey && !bIsPrimaryKey) {
        return -1;
      }
      if (!aIsPrimaryKey && bIsPrimaryKey) {
        return 1;
      }
      if (aIsPrimaryKey && bIsPrimaryKey) {
        return aIndex.compareTo(bIndex);
      }

      final aIsForeignKey = foreignKeys.any((e) => e.childColumns.contains(a.columnName));
      final bIsForeignKey = foreignKeys.any((e) => e.childColumns.contains(b.columnName));

      if (aIsForeignKey && !bIsForeignKey) {
        return -1;
      }
      if (!aIsForeignKey && bIsForeignKey) {
        return 1;
      }
      return 0;
    });
    final databaseDefinition = fieldsDataBaseSchema.map((field) {
      final autoIncrement = primaryKey.fields.contains(field) && primaryKey.autoGenerateId;
      return field.getDatabaseDefinition(autoIncrement);
    }).toList();

    final embeddedDefinitions = embeddeds
        .where((e) => !e.saveToSeparateEntity && (!e.ignoreForDelete || !e.ignoreForInsert || !e.ignoreForUpdate))
        // dig into children to expand fields
        .expand((embedded) {
          final fields = <Field>[];

          void dig(final Embedded child) {
            fields.addAll(child.fields);
            child.children.forEach(dig);
          }

          dig(embedded);

          return fields;
        })
        .map((field) => field.getDatabaseDefinition(false))
        .toList();
    databaseDefinition.addAll(embeddedDefinitions);

    final foreignKeyDefinitions = foreignKeys.map((foreignKey) => foreignKey.getDefinition()).toList();
    databaseDefinition.addAll(foreignKeyDefinitions);

    final primaryKeyDefinition = _createPrimaryKeyDefinition();
    if (primaryKeyDefinition != null) {
      databaseDefinition.add(primaryKeyDefinition);
    }

    final withoutRowidClause = withoutRowid ? ' WITHOUT ROWID' : '';

    if (fts == null) {
      return 'CREATE TABLE IF NOT EXISTS `$name` (${databaseDefinition.join(', ')})$withoutRowidClause';
    } else {
      if (fts!.tableCreateOption().isNotEmpty) {
        databaseDefinition.add('${fts!.tableCreateOption()}');
      }
      return 'CREATE VIRTUAL TABLE IF NOT EXISTS `$name` ${fts!.usingOption}(${databaseDefinition.join(', ')})';
    }
  }

  String? _createPrimaryKeyDefinition() {
    if (primaryKey.autoGenerateId) {
      return null;
    } else {
      final columns = primaryKey.fields.map((field) => '`${field.columnName}`').join(', ');
      return 'PRIMARY KEY ($columns)';
    }
  }

  String getValueMapping() {
    final keyValueList = <String>[];
    final fieldKeyValue = fieldsAll.map((field) {
      final columnName = field.columnName;
      final attributeValue = _getAttributeValue(field);
      return "'$columnName': item.$attributeValue";
    }).toList();
    keyValueList.addAll(fieldKeyValue);

    final embeddedKeyValue = embeddeds.expand((embedded) {
      final keyValue = <String>[];
      final className = <String>[];

      void dig(final Embedded child) {
        className.add(child.fieldElement.displayName);
        for (final field in child.fields) {
          final columnName = field.columnName;
          final attributeValue = [...className, _getAttributeValue(field)].join('?.');
          keyValue.add("'$columnName': item.$attributeValue");
        }

        child.children.forEach(dig);
      }

      dig(embedded);

      return keyValue;
    }).toList();
    keyValueList.addAll(embeddedKeyValue);

    return '<String, dynamic>{${keyValueList.join(', ')}}';
  }

  String _getAttributeValue(final Field field) {
    final parameterName = field.fieldElement.displayName;
    if (field.fieldElement.type.isDartCoreBool) {
      return '$parameterName?.toInt()';
    } else {
      return '$parameterName';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entity &&
          runtimeType == other.runtimeType &&
          classElement == other.classElement &&
          name == other.name &&
          const ListEquality<Field>().equals(fieldsDataBaseSchema, other.fieldsDataBaseSchema) &&
          const ListEquality<Field>().equals(fieldsQuery, other.fieldsQuery) &&
          const ListEquality<Field>().equals(fieldsAll, other.fieldsAll) &&
          const ListEquality<Embedded>().equals(embeddeds, other.embeddeds) &&
          primaryKey == other.primaryKey &&
          foreignKeys.equals(other.foreignKeys) &&
          indices.equals(other.indices) &&
          withoutRowid == other.withoutRowid &&
          constructor == other.constructor &&
          valueMappingForDelete == other.valueMappingForDelete &&
          valueMappingForInsert == other.valueMappingForInsert &&
          valueMappingForUpdate == other.valueMappingForUpdate;

  @override
  int get hashCode =>
      classElement.hashCode ^
      name.hashCode ^
      embeddeds.hashCode ^
      fieldsDataBaseSchema.hashCode ^
      fieldsQuery.hashCode ^
      fieldsAll.hashCode ^
      primaryKey.hashCode ^
      foreignKeys.hashCode ^
      indices.hashCode ^
      constructor.hashCode ^
      withoutRowid.hashCode ^
      fts.hashCode ^
      valueMappingForDelete.hashCode ^
      valueMappingForInsert.hashCode ^
      valueMappingForUpdate.hashCode;

  @override
  String toString() {
    return 'Entity{classElement: $classElement, name: $name, embeddeds: $embeddeds, fieldsDataBaseSchema: $fieldsDataBaseSchema, fieldsQuery: $fieldsQuery, fieldsAll: $fieldsAll, primaryKey: $primaryKey, foreignKeys: $foreignKeys, indices: $indices, constructor: $constructor, withoutRowid: $withoutRowid, valueMappingForUpdate: $valueMappingForUpdate, valueMappingForInsert: $valueMappingForInsert, valueMappingForDelete: $valueMappingForDelete, fts: $fts}';
  }
}
