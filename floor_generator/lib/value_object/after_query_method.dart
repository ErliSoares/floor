import 'package:analyzer/dart/element/element.dart';
import 'package:floor_generator/value_object/entity.dart';

class AfterQueryMethod {
  final MethodElement methodElement;
  final String name;
  final Entity entity;

  AfterQueryMethod({
    required this.methodElement,
    required this.name,
    required this.entity,
  });
}
