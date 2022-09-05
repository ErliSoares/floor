import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations;
import 'package:floor_generator/misc/extension/iterable_extension.dart';
import 'package:floor_generator/processor/database_processor.dart';
import 'package:floor_generator/processor/sql_column_processor.dart';
import 'package:floor_generator/value_object/database.dart';
import 'package:floor_generator/writer/dao_writer.dart';
import 'package:floor_generator/writer/database_builder_writer.dart';
import 'package:floor_generator/writer/database_writer.dart';
import 'package:floor_generator/writer/floor_writer.dart';
import 'package:floor_generator/writer/routine_entry_trigger_field_writer.dart';
import 'package:floor_generator/writer/type_converter_field_writer.dart';
import 'package:source_gen/source_gen.dart';

/// Floor generator that produces the implementation of the persistence code.
class FloorGenerator extends GeneratorForAnnotation<annotations.Database> {
  @override
  FutureOr<String> generateForAnnotatedElement(
    final Element element,
    final ConstantReader annotation,
    final BuildStep buildStep,
  ) {
    final _sqlColumnProcessor = SqlColumnProcessor();

    final database = _getDatabase(element, _sqlColumnProcessor);

    final databaseClass = DatabaseWriter(database).write();
    final daoClasses = database.daoGetters.map((daoGetter) => daoGetter.dao).map((dao) => DaoWriter(
          dao,
          database.streamEntities,
          database.hasViewStreams,
          database.name,
          sqlColumnProcessor: _sqlColumnProcessor,
          allFieldOfDaoWithAllMethods: database.allFieldOfDaoWithAllMethods,
          routines: database.routines,
        ).write());
    final distinctTypeConverterFields = database.allTypeConverters
        .distinctBy((element) => element.name)
        .map((typeConverter) => TypeConverterFieldWriter(typeConverter.name).write());

    final routineFields = database.routines.distinctBy((element) => element.name).map((typeConverter) =>
        RoutineEntryTriggerFieldWriter(typeConverter.name, typeConverter.nameFieldInDataBase).write());

    const ignore = '// ignore_for_file: cast_nullable_to_non_nullable\n'
        '// ignore_for_file: avoid_types_on_closure_parameters\n'
        '// ignore_for_file: invalid_null_aware_operator\n'
        '// ignore_for_file: prefer_interpolation_to_compose_strings\n\n';

    final library = Library((builder) {
      builder
        ..body.add(const Code(ignore))
        ..body.add(FloorWriter(database.name).write())
        ..body.add(DatabaseBuilderWriter(database.name).write())
        ..body.add(databaseClass)
        ..body.addAll(daoClasses);

      if (distinctTypeConverterFields.isNotEmpty) {
        builder.body
          ..addAll(distinctTypeConverterFields)
          ..addAll(routineFields);
      }
    });

    return library.accept(DartEmitter()).toString();
  }

  Database _getDatabase(final Element element, SqlColumnProcessor sqlColumnProcessor) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError('The element annotated with @Database is not a class.', element: element);
    }

    if (!element.isAbstract) {
      throw InvalidGenerationSourceError('The database class has to be abstract.', element: element);
    }

    return DatabaseProcessor(element, sqlColumnProcessor: sqlColumnProcessor).process();
  }
}
