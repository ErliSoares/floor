import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:floor_generator/value_object/embedded.dart';
import 'package:floor_generator/value_object/field.dart';
import 'package:floor_generator/value_object/queryable.dart';

class View extends Queryable {
  final String query;
  final bool isQueryView;

  View(
    ClassElement classElement,
    String name,
    List<Embedded> embeddeds,
    List<Field> fieldsQuery,
    List<Field> fieldsDataBaseSchema,
    List<Field> fieldsAll,
    this.query,
    String constructor,
    this.isQueryView,
  ) : super(
            classElement: classElement,
            name: name,
            fieldsQuery: fieldsQuery,
            fieldsDataBaseSchema: fieldsDataBaseSchema,
            fieldsAll: fieldsAll,
            constructor: constructor,
            embeddeds: embeddeds);

  String getCreateViewStatement() {
    return 'CREATE VIEW IF NOT EXISTS `$name` AS $query';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is View &&
          runtimeType == other.runtimeType &&
          classElement == other.classElement &&
          name == other.name &&
          const ListEquality<Field>().equals(fieldsAll, other.fieldsAll) &&
          const ListEquality<Field>().equals(fieldsQuery, other.fieldsQuery) &&
          const ListEquality<Field>().equals(fieldsDataBaseSchema, other.fieldsDataBaseSchema) &&
          query == other.query &&
          constructor == other.constructor &&
          isQueryView == isQueryView;

  @override
  int get hashCode =>
      classElement.hashCode ^
      name.hashCode ^
      fieldsAll.hashCode ^
      fieldsQuery.hashCode ^
      fieldsDataBaseSchema.hashCode ^
      query.hashCode ^
      constructor.hashCode ^
      isQueryView.hashCode;

  @override
  String toString() {
    return 'View{classElement: $classElement, name: $name, fieldsAll: $fieldsAll, fieldsQuery: $fieldsQuery, fieldsDataBaseSchema: $fieldsDataBaseSchema, query: $query, constructor: $constructor, isQueryView: $isQueryView}';
  }
}
