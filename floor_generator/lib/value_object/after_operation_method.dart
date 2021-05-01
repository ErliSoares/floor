import 'package:analyzer/dart/element/element.dart';
import 'package:floor_generator/value_object/entity.dart';

class AfterOperationMethod {
  final MethodElement methodElement;
  final String name;
  final Entity entity;
  final bool forUpdate;
  final bool forInsert;
  final bool forDelete;

  AfterOperationMethod({
    required this.methodElement,
    required this.name,
    required this.entity,
    required this.forUpdate,
    required this.forInsert,
    required this.forDelete,
  });
}
