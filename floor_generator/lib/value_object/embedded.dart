import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:floor_generator/value_object/field.dart';
import 'package:floor_generator/value_object/fieldable.dart';

class Embedded extends Fieldable {
  final ClassElement classElement;
  final List<Field> fields;
  final List<Embedded> children;
  final String? prefix;
  final bool ignoreForQuery;
  final bool ignoreForInsert;
  final bool ignoreForUpdate;
  final bool ignoreForDelete;
  final bool saveToSeparateEntity;

  Embedded(FieldElement fieldElement, this.fields, this.children,
      {this.ignoreForQuery = false,
      this.ignoreForInsert = false,
      this.ignoreForUpdate = false,
      this.ignoreForDelete = false,
      this.saveToSeparateEntity = false,
      this.prefix})
      : classElement = fieldElement.type.element as ClassElement,
        super(fieldElement);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Embedded &&
          runtimeType == other.runtimeType &&
          fieldElement == other.fieldElement &&
          prefix == other.prefix &&
          ignoreForQuery == other.ignoreForQuery &&
          ignoreForInsert == other.ignoreForInsert &&
          ignoreForUpdate == other.ignoreForUpdate &&
          ignoreForDelete == other.ignoreForDelete &&
          const ListEquality<Field>().equals(fields, other.fields) &&
          const ListEquality<Embedded>().equals(children, other.children);

  @override
  int get hashCode => fieldElement.hashCode ^ fields.hashCode;

  @override
  String toString() {
    return 'Embedded{classElement: $classElement, fieldElement: $fieldElement, fields: $fields, children: $children, prefix: $prefix, ignoreForQuery: $ignoreForQuery, ignoreForInsert: $ignoreForInsert, ignoreForUpdate: $ignoreForUpdate, ignoreForDelete: $ignoreForDelete';
  }
}
