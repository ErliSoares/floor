import 'dart:async';

import 'package:floor/floor.dart';

abstract class RoutineEntryTriggerBase<T> {
  FutureOr<void> run(List<T> entries, FloorDatabase persistence);
}
