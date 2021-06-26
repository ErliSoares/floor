import 'package:analyzer/dart/element/element.dart';
import 'package:floor_generator/processor/processor.dart';
import 'package:floor_generator/value_object/entity.dart';
import 'package:floor_generator/value_object/routine_entry_trigger.dart';
import 'package:collection/collection.dart';
import 'package:source_gen/source_gen.dart';


class RoutineEntryTriggerMethodProcessor implements Processor<RoutineEntryTrigger> {
  final ClassElement _classElement;
  final List<Entity> _entities;

  RoutineEntryTriggerMethodProcessor(
      final ClassElement classElement,
      final List<Entity> entities,
      )   : _classElement = classElement,
  _entities = entities;

  @override
  RoutineEntryTrigger process() {
    final superType = _classElement.supertype;
    if (superType == null || superType.typeArguments.length != 1) {
      throw InvalidGenerationSourceError(
          'Routine class should extends from RoutineEntryTriggerBase',
          todo:
          'Please extends from RoutineEntryTriggerBase.',
          element: _classElement);
    }
    final entityRoutine = superType.typeArguments.first.element;
    final entity = _entities.firstWhereOrNull((e) => e.classElement == entityRoutine);

    if (entity == null) {
      throw InvalidGenerationSourceError(
          'Entity is not declared in database entities.',
          todo:
          'Declare entity `${entityRoutine!.name}` in database.',
          element: _classElement);
    }

    return RoutineEntryTrigger(
      classElement: _classElement,
      name: _classElement.name,
      entity: entity,
    );
  }
}
