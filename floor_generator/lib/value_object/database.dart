import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:floor_generator/misc/extension/set_equality_extension.dart';
import 'package:floor_generator/processor/database_processor.dart';
import 'package:floor_generator/value_object/dao_getter.dart';
import 'package:floor_generator/value_object/entity.dart';
import 'package:floor_generator/value_object/routine_entry_trigger.dart';
import 'package:floor_generator/value_object/type_converter.dart';
import 'package:floor_generator/value_object/view.dart';

/// Representation of the database component.
class Database {
  final ClassElement classElement;
  final String name;
  final List<Entity> entities;
  final List<View> views;
  final List<DaoGetter> daoGetters;
  final int version;
  final Set<TypeConverter> databaseTypeConverters;
  final Set<TypeConverter> allTypeConverters;
  final bool hasViewStreams;
  final Set<Entity> streamEntities;
  final List<FieldOfDaoWithAllMethods> allFieldOfDaoWithAllMethods;
  final List<RoutineEntryTrigger> routines;

  Database(
    this.classElement,
    this.name,
    this.entities,
    this.views,
    this.daoGetters,
    this.version,
    this.databaseTypeConverters,
    this.allTypeConverters,
    this.allFieldOfDaoWithAllMethods,
    this.routines,
  )   : streamEntities =
            daoGetters.expand((dg) => dg.dao.streamEntities).toSet(),
        hasViewStreams = daoGetters.any((dg) => dg.dao.streamViews.isNotEmpty);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Database &&
          runtimeType == other.runtimeType &&
          classElement == other.classElement &&
          name == other.name &&
          entities.equals(other.entities) &&
          views.equals(other.views) &&
          daoGetters.equals(other.daoGetters) &&
          version == other.version &&
          databaseTypeConverters.equals(other.databaseTypeConverters) &&
          allTypeConverters.equals(other.allTypeConverters) &&
          streamEntities.equals(other.streamEntities) &&
          hasViewStreams == hasViewStreams &&
          routines == routines;

  @override
  int get hashCode =>
      classElement.hashCode ^
      name.hashCode ^
      entities.hashCode ^
      views.hashCode ^
      daoGetters.hashCode ^
      version.hashCode ^
      databaseTypeConverters.hashCode ^
      allTypeConverters.hashCode ^
      streamEntities.hashCode ^
      hasViewStreams.hashCode ^
      routines.hashCode;

  @override
  String toString() {
    return 'Database{classElement: $classElement, name: $name, entities: $entities, views: $views, daoGetters: $daoGetters, version: $version, databaseTypeConverters: $databaseTypeConverters, allTypeConverters: $allTypeConverters, streamEntities: $streamEntities, hasViewStreams: $hasViewStreams, routines: $routines}';
  }
}
