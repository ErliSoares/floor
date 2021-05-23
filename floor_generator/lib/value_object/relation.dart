import 'package:analyzer/dart/element/element.dart';
import 'package:floor_generator/value_object/foreign_key.dart';

class Relation {
  final FieldElement fieldElement;
  final ClassElement parentElement;
  final String nameProperty;
  final ForeignKey foreignKey;
  final ClassElement childElement;

  Relation({
    required this.parentElement,
    required this.nameProperty,
    required this.fieldElement,
    required this.foreignKey,
    required this.childElement,
  });
}
