import 'package:code_builder/code_builder.dart';
import 'package:floor_generator/writer/writer.dart';

class RoutineEntryTriggerFieldWriter extends Writer {
  final String _routineName;
  final String _routineFieldName;

  RoutineEntryTriggerFieldWriter(final String routineName, final String routineFieldName)
      : _routineName = routineName,
        _routineFieldName = routineFieldName;

  @override
  Spec write() {
    return Field((builder) => builder
      ..name = _routineFieldName
      ..modifier = FieldModifier.final$
      ..assignment = Code('$_routineName()'));
  }
}
