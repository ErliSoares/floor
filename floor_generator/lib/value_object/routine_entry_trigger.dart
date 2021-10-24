import 'package:analyzer/dart/element/element.dart';
import 'package:floor_generator/value_object/entity.dart';
import 'package:floor_generator/misc/extension/string_extension.dart';

class RoutineEntryTrigger {
  final Entity entity;
  final ClassElement classElement;
  final String nameFieldInDataBase;
  final String name;

  RoutineEntryTrigger({required this.entity, required this.classElement, required this.name})
      : nameFieldInDataBase = '_' + name.decapitalize();
}
