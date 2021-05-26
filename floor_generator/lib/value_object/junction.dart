import 'package:analyzer/dart/element/element.dart';
import 'package:floor_generator/value_object/entity.dart';
import 'package:floor_generator/value_object/foreign_key.dart';

class Junction {
  final FieldElement fieldElement;
  final ClassElement parentElement;
  final String nameProperty;
  final ForeignKey foreignKeyJunctionChild;
  final ForeignKey foreignKeyJunctionParent;
  final Entity entityJunction;
  final ClassElement childElement;
  final bool ignoreSaveChild;

  Junction({
    required this.parentElement,
    required this.nameProperty,
    required this.fieldElement,
    required this.foreignKeyJunctionChild,
    required this.foreignKeyJunctionParent,
    required this.entityJunction,
    required this.childElement,
    required this.ignoreSaveChild,
  });
}
