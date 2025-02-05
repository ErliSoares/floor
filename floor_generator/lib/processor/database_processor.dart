import 'package:analyzer/dart/element/element.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations;
import 'package:floor_generator/misc/constants.dart';
import 'package:floor_generator/misc/extension/iterable_extension.dart';
import 'package:floor_generator/misc/extension/set_extension.dart';
import 'package:floor_generator/misc/extension/type_converter_element_extension.dart';
import 'package:floor_generator/misc/type_utils.dart';
import 'package:floor_generator/processor/dao_processor.dart';
import 'package:floor_generator/processor/entity_processor.dart';
import 'package:floor_generator/processor/error/database_processor_error.dart';
import 'package:floor_generator/processor/processor.dart';
import 'package:floor_generator/processor/routine_entry_trigger_processor.dart';
import 'package:floor_generator/processor/sql_column_processor.dart';
import 'package:floor_generator/processor/view_processor.dart';
import 'package:floor_generator/value_object/dao_getter.dart';
import 'package:floor_generator/value_object/database.dart';
import 'package:floor_generator/value_object/entity.dart';
import 'package:floor_generator/value_object/queryable.dart';
import 'package:floor_generator/value_object/routine_entry_trigger.dart';
import 'package:floor_generator/value_object/type_converter.dart';
import 'package:floor_generator/value_object/view.dart';
import 'package:floor_generator/extension/class_extension.dart';

class DatabaseProcessor extends Processor<Database> {
  final DatabaseProcessorError _processorError;

  final SqlColumnProcessor? sqlColumnProcessor;

  final ClassElement _classElement;

  DatabaseProcessor(final ClassElement classElement, {this.sqlColumnProcessor})
      : _classElement = classElement,
        _processorError = DatabaseProcessorError(classElement);

  @override
  Database process() {
    final databaseName = _classElement.displayName;
    final databaseTypeConverters = _classElement.getTypeConverters(TypeConverterScope.database);

    final fieldsDataBaseDao = _classElement.fields.where(_isDao).toList();

    final allFieldOfDaoWithAllMethods = fieldsDataBaseDao.expand((e) {
      final classElement = e.type.element;
      if (classElement is ClassElement) {
        return classElement.getAllMethods().map((method) => FieldOfDaoWithAllMethods(e, method));
      }
      return <FieldOfDaoWithAllMethods>[];
    });

    final entities = _getEntities(_classElement, databaseTypeConverters, allFieldOfDaoWithAllMethods.toList());
    if (sqlColumnProcessor != null) {
      for (var item in entities) {
        final sqlCreate = item.getCreateTableStatement();
        sqlColumnProcessor!.registerSqlCreateTable(sqlCreate);
      }
    }

    final views = _getViews(_classElement, databaseTypeConverters);
    final daoGetters = _getDaoGetters(
      databaseName,
      entities,
      views,
      databaseTypeConverters,
      fieldsDataBaseDao,
    );
    final version = _getDatabaseVersion();
    final allTypeConverters = _getAllTypeConverters(
      daoGetters,
      [...entities, ...views],
    );

    final routines = _getRoutinesEntryTrigger(_classElement, entities);
    return Database(
      _classElement,
      databaseName,
      entities,
      views,
      daoGetters,
      version,
      databaseTypeConverters,
      allTypeConverters,
      allFieldOfDaoWithAllMethods.toList(),
      routines,
    );
  }

  int _getDatabaseVersion() {
    final version =
        _classElement.getAnnotation(annotations.Database)?.getField(AnnotationField.databaseVersion)?.toIntValue();

    if (version == null) throw _processorError.versionIsMissing;
    if (version < 1) throw _processorError.versionIsBelowOne;

    return version;
  }

  List<DaoGetter> _getDaoGetters(
    final String databaseName,
    final List<Entity> entities,
    final List<View> views,
    final Set<TypeConverter> typeConverters,
    final List<FieldElement> fieldsDataBaseDao,
  ) {
    return fieldsDataBaseDao.map((field) {
      final classElement = field.type.element as ClassElement;
      final name = field.displayName;

      final dao = DaoProcessor(
        classElement,
        name,
        databaseName,
        entities,
        views,
        typeConverters,
      ).process();

      return DaoGetter(field, name, dao);
    }).toList();
  }

  bool _isDao(final FieldElement fieldElement) {
    final element = fieldElement.type.element;
    return element is ClassElement ? _isDaoClass(element) : false;
  }

  bool _isDaoClass(final ClassElement classElement) {
    return classElement.hasAnnotation(annotations.dao.runtimeType) && classElement.isAbstract;
  }

  List<Entity> _getEntities(
    final ClassElement databaseClassElement,
    final Set<TypeConverter> typeConverters,
    List<FieldOfDaoWithAllMethods> allFieldOfDaoWithAllMethods,
  ) {
    final entities = _classElement
        .getAnnotation(annotations.Database)
        ?.getField(AnnotationField.databaseEntities)
        ?.toListValue()
        ?.mapNotNull((object) => object.toTypeValue()?.element)
        .whereType<ClassElement>()
        .where((element) => element.isEntity)
        .map((classElement) => EntityProcessor(
              classElement,
              typeConverters,
              allFieldOfDaoWithAllMethods,
            ).process())
        .toList();

    if (entities == null || entities.isEmpty) {
      throw _processorError.noEntitiesDefined;
    }

    return entities;
  }

  List<RoutineEntryTrigger> _getRoutinesEntryTrigger(
    final ClassElement databaseClassElement,
    List<Entity> entities,
  ) {
    return _classElement
            .getAnnotation(annotations.Database)
            ?.getField(AnnotationField.databaseRoutines)
            ?.toListValue()
            ?.mapNotNull((object) => object.toTypeValue()?.element)
            .whereType<ClassElement>()
            .map((classElement) => RoutineEntryTriggerMethodProcessor(classElement, entities).process())
            .toList() ??
        [];
  }

  List<View> _getViews(
    final ClassElement databaseClassElement,
    final Set<TypeConverter> typeConverters,
  ) {
    return _classElement
            .getAnnotation(annotations.Database)
            ?.getField(AnnotationField.databaseViews)
            ?.toListValue()
            ?.mapNotNull((object) => object.toTypeValue()?.element)
            .whereType<ClassElement>()
            .where((element) => element.isQueryView)
            .map((classElement) => ViewProcessor(
                  classElement,
                  typeConverters,
                ).process())
            .toList() ??
        [];
  }

  Set<TypeConverter> _getAllTypeConverters(
    final List<DaoGetter> daoGetters,
    final List<Queryable> queryables,
  ) {
    // DAO query methods have access to all type converters
    final daoQueryMethodTypeConverters = daoGetters
        .expand((daoGetter) => daoGetter.dao.queryMethods)
        .expand((queryMethod) => queryMethod.typeConverters)
        .toSet();

    // but when no query methods are defined, we need to collect them differently
    final daoTypeConverters = daoGetters.expand((daoGetter) => daoGetter.dao.typeConverters).toSet();

    final fieldTypeConverters =
        queryables.expand((queryable) => queryable.fieldsAll).mapNotNull((field) => field.typeConverter).toSet();

    return daoQueryMethodTypeConverters + daoTypeConverters + fieldTypeConverters;
  }
}

class FieldOfDaoWithAllMethods {
  final FieldElement field;
  final MethodElement method;

  FieldOfDaoWithAllMethods(this.field, this.method);
}
