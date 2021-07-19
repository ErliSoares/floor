import 'package:analyzer/dart/element/element.dart';
import 'package:floor_generator/value_object/fieldable.dart';
import 'package:floor_generator/value_object/foreign_key_relation.dart';
import 'package:floor_generator/value_object/junction.dart';
import 'package:floor_generator/value_object/relation.dart';
import 'package:floor_generator/value_object/type_converter.dart';

/// Represents an Entity field and thus a table column.
class Field extends Fieldable {
  final String name;
  final String columnName;
  final bool isNullable;
  final String sqlType;
  final TypeConverter? typeConverter;
  final Junction? junction;
  final Relation? relation;
  final ForeignKeyRelation? foreignKeyRelation;
  final int? length;
  final int? decimals;

  Field(
    FieldElement fieldElement,
    this.name,
    this.columnName,
    this.isNullable,
    this.sqlType,
    this.typeConverter, {
    this.junction,
    this.relation,
    this.foreignKeyRelation,
    this.length,
    this.decimals,
  }) : super(fieldElement);

  /// The database column definition.
  String getDatabaseDefinition(final bool autoGenerate) {
    final columnSpecification = StringBuffer();

    if (autoGenerate) {
      columnSpecification.write(' PRIMARY KEY AUTOINCREMENT');
    }
    if (!isNullable) {
      columnSpecification.write(' NOT NULL');
    }

    var constrainsLength = '';
    if (length != null) {
      constrainsLength = '($length${decimals == null ? '' : ',$decimals'})';
    }

    return '`$columnName` $sqlType$constrainsLength$columnSpecification';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Field &&
          runtimeType == other.runtimeType &&
          fieldElement == other.fieldElement &&
          name == other.name &&
          columnName == other.columnName &&
          isNullable == other.isNullable &&
          sqlType == other.sqlType &&
          length == other.length &&
          decimals == other.decimals &&
          typeConverter == other.typeConverter;

  @override
  int get hashCode =>
      fieldElement.hashCode ^
      name.hashCode ^
      columnName.hashCode ^
      isNullable.hashCode ^
      sqlType.hashCode ^
      length.hashCode ^
      decimals.hashCode ^
      typeConverter.hashCode;

  @override
  String toString() {
    return 'Field{fieldElement: $fieldElement, name: $name, columnName: $columnName, isNullable: $isNullable, sqlType: $sqlType, typeConverter: $typeConverter}, length: $length}, decimals: $decimals}';
  }
}
