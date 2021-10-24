import 'package:analyzer/dart/element/element.dart';
import 'package:floor_generator/value_object/foreign_key.dart';

class ForeignKeyRelation {
  final FieldElement fieldElement;
  final ClassElement parentElement;
  final String nameProperty;
  final String namePropertyRelation;
  final ForeignKey foreignKey;
  final ClassElement childElement;
  final bool save;

  ForeignKeyRelation({
    required this.parentElement,
    required this.nameProperty,
    required this.fieldElement,
    required this.foreignKey,
    required this.childElement,
    required this.save,
    required this.namePropertyRelation,
  });
}
