import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations;
import 'package:floor_generator/misc/constants.dart';
import 'package:floor_generator/misc/extension/dart_object_extension.dart';
import 'package:floor_generator/misc/extension/dart_type_extension.dart';
import 'package:floor_generator/misc/extension/iterable_extension.dart';
import 'package:floor_generator/misc/extension/string_extension.dart';
import 'package:floor_generator/misc/extension/type_converters_extension.dart';
import 'package:floor_generator/misc/type_utils.dart';
import 'package:floor_generator/processor/database_processor.dart';
import 'package:floor_generator/processor/error/entity_processor_error.dart';
import 'package:floor_generator/processor/queryable_processor.dart';
import 'package:floor_generator/value_object/embedded.dart';
import 'package:floor_generator/value_object/entity.dart';
import 'package:floor_generator/value_object/field.dart';
import 'package:floor_generator/value_object/fieldable.dart';
import 'package:floor_generator/value_object/foreign_key.dart';
import 'package:floor_generator/value_object/foreign_key_relation.dart';
import 'package:floor_generator/value_object/fts.dart';
import 'package:floor_generator/value_object/index.dart';
import 'package:floor_generator/value_object/junction.dart';
import 'package:floor_generator/value_object/primary_key.dart';
import 'package:floor_generator/value_object/relation.dart';
import 'package:floor_generator/value_object/type_converter.dart';

class EntityProcessor extends QueryableProcessor<Entity> {
  final EntityProcessorError _processorError;
  final List<FieldOfDaoWithAllMethods> _allFieldOfDaoWithAllMethods;

  EntityProcessor(final ClassElement classElement, final Set<TypeConverter> typeConverters,
      [final List<FieldOfDaoWithAllMethods> allFieldOfDaoWithAllMethods = const []])
      : _processorError = EntityProcessorError(classElement),
        _allFieldOfDaoWithAllMethods = allFieldOfDaoWithAllMethods,
        super(classElement, typeConverters);

  @override
  Entity process() {
    final name = classElement.tableName();
    final embeddeds = getEmbeddeds();
    final fieldsAll = getFieldsWithOutCheckIgnore();
    final fieldsDataBaseSchema = fieldsAll.where((e) => shouldBeIncludedForDataBaseSchema(e.fieldElement)).toList();
    final fieldsQuery = fieldsAll.where((e) => shouldBeIncludedForQuery(e.fieldElement)).toList();

    final fieldsInsert = fieldsAll.where((e) => shouldBeIncludedForInsert(e.fieldElement)).toList();
    final fieldsUpdate = fieldsAll.where((e) => shouldBeIncludedForUpdate(e.fieldElement)).toList();
    final fieldsDelete = fieldsAll.where((e) => shouldBeIncludedForDelete(e.fieldElement)).toList();

    final primaryKey = _getPrimaryKey(fieldsDataBaseSchema);
    final withoutRowid = _getWithoutRowid();

    if (primaryKey.autoGenerateId && withoutRowid) {
      throw _processorError.autoIncrementInWithoutRowid;
    }

    var actionsSave =
        fieldsAll.where((e) => e.relation != null).map((e) => _getSaveRelation(e.relation!, name)).join('\n');

    actionsSave = actionsSave +
        fieldsAll.where((e) => e.junction != null).map((e) => _getSaveJunction(e.junction!, name)).join('\n');

    actionsSave = actionsSave +
        embeddeds
            .where((e) => e.saveToSeparateEntity)
            .map((e) => _getSaveEmbeddedEntity(e.fieldElement, name))
            .join('\n');

    final beforeSave = fieldsAll
        .where((e) => e.foreignKeyRelation != null && e.foreignKeyRelation!.save)
        .map((e) => _getSaveForeignKeyRelation(e.foreignKeyRelation!, name))
        .join('\n');
    if (beforeSave.isNotEmpty) {
      // O geração do código pelo _getSaveForeignKeyRelation está correta, porem ela precisa ser salva antes da outra entidade
      throw UnimplementedError('Não foi implementado para salvar com o recurso foreignKeyRelation.');
    }

    return Entity(
      classElement,
      name,
      embeddeds,
      fieldsAll,
      fieldsDataBaseSchema,
      fieldsQuery,
      _getPrimaryKey(fieldsDataBaseSchema),
      getForeignKeys(classElement),
      _getIndices(fieldsDataBaseSchema, name),
      _getWithoutRowid(),
      getConstructor([...fieldsQuery, ...embeddeds.whereNot((e) => e.ignoreForQuery)]),
      _getValueMapping(fieldsInsert, embeddeds.whereNot((e) => e.ignoreForInsert || e.saveToSeparateEntity).toList()),
      _getValueMapping(fieldsUpdate, embeddeds.whereNot((e) => e.ignoreForUpdate || e.saveToSeparateEntity).toList()),
      _getValueMapping(fieldsDelete, embeddeds.whereNot((e) => e.ignoreForDelete || e.saveToSeparateEntity).toList()),
      _getFts(),
      actionsSave,
    );
  }

  List<ForeignKey> getForeignKeys(ClassElement classElement) {
    return classElement
            .getAnnotation(annotations.Entity)
            ?.getField(AnnotationField.entityForeignKeys)
            ?.toListValue()
            ?.map((foreignKeyObject) {
          final parentType = foreignKeyObject.getField(ForeignKeyField.entity)?.toTypeValue() ??
              (throw _processorError.foreignKeyNoEntity);

          final parentElement = parentType.element;
          final parentName = parentElement is ClassElement
              ? parentElement.tableName()
              : throw _processorError.foreignKeyDoesNotReferenceEntity(classElement);

          final childColumns = _getColumns(foreignKeyObject, ForeignKeyField.childColumns);
          if (childColumns.isEmpty) {
            throw _processorError.missingChildColumns;
          }

          final parentColumns = _getColumns(foreignKeyObject, ForeignKeyField.parentColumns);
          if (parentColumns.isEmpty) {
            throw _processorError.missingParentColumns;
          }

          final onUpdate = _getForeignKeyAction(foreignKeyObject, ForeignKeyField.onUpdate);

          final onDelete = _getForeignKeyAction(foreignKeyObject, ForeignKeyField.onDelete);

          return ForeignKey(
            parentName,
            parentColumns,
            childColumns,
            onUpdate,
            onDelete,
          );
        }).toList() ??
        [];
  }

  Fts? _getFts() {
    if (classElement.hasAnnotation(annotations.Fts3)) {
      return _getFts3();
    } else if (classElement.hasAnnotation(annotations.Fts4)) {
      return _getFts4();
    } else {
      return null;
    }
  }

  Fts _getFts3() {
    final ftsObject = classElement.getAnnotation(annotations.Fts3);

    final tokenizer = ftsObject?.getField(Fts3Field.tokenizer)?.toStringValue() ?? annotations.FtsTokenizer.simple;

    final tokenizerArgs = ftsObject
            ?.getField(Fts3Field.tokenizerArgs)
            ?.toListValue()
            ?.mapNotNull((object) => object.toStringValue())
            .toList() ??
        [];

    return Fts3(tokenizer, tokenizerArgs);
  }

  Fts _getFts4() {
    final ftsObject = classElement.getAnnotation(annotations.Fts4);

    final tokenizer = ftsObject?.getField(Fts4Field.tokenizer)?.toStringValue() ?? annotations.FtsTokenizer.simple;

    final tokenizerArgs = ftsObject
            ?.getField(Fts4Field.tokenizerArgs)
            ?.toListValue()
            ?.mapNotNull((object) => object.toStringValue())
            .toList() ??
        [];

    return Fts4(tokenizer, tokenizerArgs);
  }

  List<Index> _getIndices(final List<Field> fields, final String tableName) {
    return classElement
            .getAnnotation(annotations.Entity)
            ?.getField(AnnotationField.entityIndices)
            ?.toListValue()
            ?.map((indexObject) {
          final unique = indexObject.getField(IndexField.unique)?.toBoolValue();
          // can't happen as Index.unique is non-nullable
          if (unique == null) throw ArgumentError.notNull();

          final indexColumnNames = indexObject
              .getField(IndexField.value)
              ?.toListValue()
              ?.mapNotNull((valueObject) => valueObject.toStringValue())
              .toList();

          if (indexColumnNames == null || indexColumnNames.isEmpty) {
            throw _processorError.missingIndexColumnName;
          }

          for (final indexColumnName in indexColumnNames) {
            if (!fields.any((field) => field.columnName == indexColumnName)) {
              throw _processorError.noMatchingColumn(indexColumnName);
            }
          }

          final name =
              indexObject.getField(IndexField.name)?.toStringValue() ?? _generateIndexName(tableName, indexColumnNames);

          return Index(name, tableName, unique, indexColumnNames);
        }).toList() ??
        [];
  }

  String _generateIndexName(
    final String tableName,
    final List<String> columnNames,
  ) {
    return Index.defaultPrefix + tableName + '_' + columnNames.join('_');
  }

  List<String> _getColumns(
    final DartObject object,
    final String foreignKeyField,
  ) {
    return object.getField(foreignKeyField)?.toListValue()?.mapNotNull((object) => object.toStringValue()).toList() ??
        [];
  }

  PrimaryKey _getPrimaryKey(final List<Field> fields) {
    final compoundPrimaryKey = _getCompoundPrimaryKey(fields);

    if (compoundPrimaryKey != null) {
      return compoundPrimaryKey;
    } else {
      return _getPrimaryKeyFromAnnotation(fields);
    }
  }

  PrimaryKey? _getCompoundPrimaryKey(final List<Field> fields) {
    final compoundPrimaryKeyColumnNames = classElement
        .getAnnotation(annotations.Entity)
        ?.getField(AnnotationField.entityPrimaryKeys)
        ?.toListValue()
        ?.map((object) => object.toStringValue());

    if (compoundPrimaryKeyColumnNames == null || compoundPrimaryKeyColumnNames.isEmpty) {
      return null;
    }

    final compoundPrimaryKeyFields = fields.where((field) {
      return compoundPrimaryKeyColumnNames.any((primaryKeyColumnName) => field.columnName == primaryKeyColumnName);
    }).toList();

    if (compoundPrimaryKeyFields.isEmpty) {
      throw _processorError.missingPrimaryKey;
    }

    return PrimaryKey(compoundPrimaryKeyFields, false);
  }

  PrimaryKey _getPrimaryKeyFromAnnotation(final List<Field> fields) {
    final primaryKeyField = fields.firstWhere((field) => field.fieldElement.hasAnnotation(annotations.PrimaryKey),
        orElse: () => throw _processorError.missingPrimaryKey);

    final autoGenerate = primaryKeyField.fieldElement
            .getAnnotation(annotations.PrimaryKey)
            ?.getField(AnnotationField.primaryKeyAutoGenerate)
            ?.toBoolValue() ??
        false;

    return PrimaryKey([primaryKeyField], autoGenerate);
  }

  bool _getWithoutRowid() {
    return classElement
            .getAnnotation(annotations.Entity)
            ?.getField(AnnotationField.entityWithoutRowid)
            ?.toBoolValue() ??
        false;
  }

  void _processFields(final Map map, final List<Fieldable> fields, {String prefix = ''}) {
    for (final field in fields) {
      if (field is Field) {
        map[field.columnName] = _getAttributeValue(field, prefix: prefix);
      } else if (field is Embedded) {
        _processFields(map, [...field.fields, ...field.children], prefix: '$prefix${field.fieldElement.name}.');
      }
    }
  }

  String _getValueMapping(final List<Fieldable> fields, List<Embedded> embeddeds) {
    final Map<String, String> map = {};
    _processFields(map, fields);

    final keyValueList = map.entries.map((entry) => "'${entry.key}': ${entry.value}").toList();

    final embeddedKeyValue = embeddeds.expand((embedded) {
      final keyValue = <String>[];
      final className = <String>[];

      void dig(final Embedded child) {
        className.add(child.fieldElement.displayName);
        for (final field in child.fields) {
          final columnName = field.columnName;
          final attributeValue = [...className, _getAttributeValue(field, ignoreAddItem: true)].join('?.');
          keyValue.add("'$columnName': item.$attributeValue");
        }

        child.children.forEach(dig);
      }

      dig(embedded);

      return keyValue;
    }).toList();
    keyValueList.addAll(embeddedKeyValue);

    return '<String, Object?>{${keyValueList.join(', ')}}';
  }

  String _getAttributeValue(final Field field, {String prefix = '', bool ignoreAddItem = false}) {
    final fieldElement = field.fieldElement;
    final parameterName = fieldElement.displayName;
    final fieldType = fieldElement.type;

    String attributeValue;

    if (fieldType.isDefaultSqlType) {
      attributeValue = '${ignoreAddItem ? '' : 'item.'}$prefix$parameterName';
    } else if (fieldType.element is EnumElement) {
      return '${ignoreAddItem ? '' : 'item.'}$prefix$parameterName.value';
    } else {
      final typeConverter = [
        ...queryableTypeConverters,
        field.typeConverter,
      ].whereNotNull().getClosest(fieldType);
      attributeValue =
          '${typeConverter.name.decapitalize()}.encode(${ignoreAddItem ? '' : 'item.'}$prefix$parameterName)';
    }

    if (fieldType.isDartCoreBool) {
      if (field.isNullable) {
        // force! underlying non-nullable type as null check has been done
        return '$attributeValue == null ? null : ($attributeValue! ? 1 : 0)';
      } else {
        return '$attributeValue ? 1 : 0';
      }
    } else {
      return attributeValue;
    }
  }

  annotations.ForeignKeyAction _getForeignKeyAction(
    DartObject foreignKeyObject,
    String triggerName,
  ) {
    final field = foreignKeyObject.getField(triggerName);
    if (field == null) {
      // field was not defined, return default value
      return annotations.ForeignKeyAction.noAction;
    }

    final foreignKeyAction = field.toForeignKeyAction();
    if (foreignKeyAction == null) {
      throw _processorError.wrongForeignKeyAction(field, triggerName);
    } else {
      return foreignKeyAction;
    }
  }

  String _getSaveRelation(final Relation relation, String tableName) {
    final String code;

    final field = relation.fieldElement;
    final fieldType = field.type.isDartCoreList ? field.type.flatten() : field.type;

    final fieldOfDaoWithAllMethods = _findMethodsDaoSaveToEntity(fieldType.element!);

    if (fieldOfDaoWithAllMethods == null) {
      throw _processorError.noMethodWithSaveAnnotation(field);
    }

    final setFields = StringBuffer();
    final foreignKey = relation.foreignKey;

    if (field.type.isDartCoreList) {
      for (var i = 0; i < foreignKey.parentColumns.length; i++) {
        setFields.writeln('sub.${foreignKey.childColumns[i]} = entity.${foreignKey.parentColumns[i]};');
      }
    } else {
      for (var i = 0; i < foreignKey.parentColumns.length; i++) {
        setFields
            .writeln('entity.${field.name}.${foreignKey.childColumns[i]} = entity.${foreignKey.parentColumns[i]};');
      }
    }
    if (field.type.isNullable && field.type.isDartCoreList) {
      code = '''          if (entity.${field.name} != null) {
            for(final sub in entity.${field.name}!) {
              ${setFields}await floorDatabase.${fieldOfDaoWithAllMethods.field.name}.${fieldOfDaoWithAllMethods.method.name}(sub);
            }
          }''';
    } else if (field.type.isDartCoreList) {
      code = '''          for(final sub in entity.${field.name}) {
            ${setFields}await floorDatabase.${fieldOfDaoWithAllMethods.field.name}.${fieldOfDaoWithAllMethods.method.name}(sub);
          }''';
    } else if (field.type.isNullable) {
      code = '''          if (entity.${field.name} != null) {
            ${setFields}await floorDatabase.${fieldOfDaoWithAllMethods.field.name}.${fieldOfDaoWithAllMethods.method.name}(entity.${field.name}!);
          }''';
    } else {
      code =
          '''                ${setFields}await floorDatabase.${fieldOfDaoWithAllMethods.field.name}.${fieldOfDaoWithAllMethods.method.name}(entity.${field.name});''';
    }

    return code;
  }

  String _getSaveForeignKeyRelation(final ForeignKeyRelation relation, String tableName) {
    final String code;

    final field = relation.fieldElement;
    final fieldType = field.type.isDartCoreList ? field.type.flatten() : field.type;

    final fieldOfDaoWithAllMethods = _findMethodsDaoSaveToEntity(fieldType.element!);

    if (fieldOfDaoWithAllMethods == null) {
      throw _processorError.noMethodWithSaveAnnotation(field);
    }

    final setFields = StringBuffer();
    final foreignKey = relation.foreignKey;

    for (var i = 0; i < foreignKey.parentColumns.length; i++) {
      setFields.writeln('entity.${foreignKey.childColumns[i]} = entity.${field.name}.${foreignKey.parentColumns[i]};');
    }

    if (field.type.isNullable) {
      code = '''          if (entity.${field.name} != null) {
            ${setFields}await floorDatabase.${fieldOfDaoWithAllMethods.field.name}.${fieldOfDaoWithAllMethods.method.name}(entity.${field.name}!);
          }''';
    } else {
      code =
          '''                ${setFields}await floorDatabase.${fieldOfDaoWithAllMethods.field.name}.${fieldOfDaoWithAllMethods.method.name}(entity.${field.name});''';
    }

    return code;
  }

  String _getSaveJunction(final Junction junction, String tableName) {
    final String code;

    final fieldOfDaoWithAllMethodsChild = _findMethodsDaoSaveToEntity(junction.childElement);
    if (fieldOfDaoWithAllMethodsChild == null) {
      throw _processorError.noMethodWithSaveAnnotation(junction.childElement);
    }
    final fieldOfDaoWithAllMethodsJunction = _findMethodsDaoSaveToEntity(junction.entityJunction.classElement);
    if (fieldOfDaoWithAllMethodsJunction == null) {
      throw _processorError.noMethodWithSaveAnnotation(junction.entityJunction.classElement);
    }

    final entityJunctionClass = junction.entityJunction.classElement;

    final field = junction.fieldElement;
    if (field.type.isNullable && field.type.isDartCoreList) {
      final String saveChildCode;
      if (junction.ignoreSaveChild) {
        saveChildCode = '';
      } else {
        saveChildCode =
            'await floorDatabase.${fieldOfDaoWithAllMethodsChild.field.name}.${fieldOfDaoWithAllMethodsChild.method.name}(sub);';
      }
      code = '''          if (entity.${field.name} != null) {
            for(final sub in entity.${field.name}!) {
              $saveChildCode
              await floorDatabase.${fieldOfDaoWithAllMethodsJunction.field.name}.${fieldOfDaoWithAllMethodsJunction.method.name}(${entityJunctionClass.name}(
                ${junction.foreignKeyJunctionChild.childColumns[0]}: sub.${junction.foreignKeyJunctionChild.parentColumns[0]},
                ${junction.foreignKeyJunctionParent.childColumns[0]}: entity.${junction.foreignKeyJunctionParent.parentColumns[0]},
                deleted: sub.deleted,
              ));
            }
          }''';
    } else if (field.type.isDartCoreList) {
      final String saveChildCode;
      if (junction.ignoreSaveChild) {
        saveChildCode = '';
      } else {
        saveChildCode =
            'await floorDatabase.${fieldOfDaoWithAllMethodsChild.field.name}.${fieldOfDaoWithAllMethodsChild.method.name}(sub);';
      }
      code = '''          for(final sub in entity.${field.name}) {
              $saveChildCode
              await floorDatabase.${fieldOfDaoWithAllMethodsJunction.field.name}.${fieldOfDaoWithAllMethodsJunction.method.name}(${entityJunctionClass.name}(
                ${junction.foreignKeyJunctionChild.childColumns[0]}: sub.${junction.foreignKeyJunctionChild.parentColumns[0]},
                ${junction.foreignKeyJunctionParent.childColumns[0]}: entity.${junction.foreignKeyJunctionParent.parentColumns[0]},
                deleted: sub.deleted,
              ));
            }''';
    } else if (field.type.isNullable) {
      final String saveChildCode;
      if (junction.ignoreSaveChild) {
        saveChildCode = '';
      } else {
        saveChildCode =
            'await floorDatabase.${fieldOfDaoWithAllMethodsChild.field.name}.${fieldOfDaoWithAllMethodsChild.method.name}(entity.${field.name}!);';
      }
      code = '''          if (entity.${field.name} != null) {
              $saveChildCode
              await floorDatabase.${fieldOfDaoWithAllMethodsJunction.field.name}.${fieldOfDaoWithAllMethodsJunction.method.name}(${entityJunctionClass.name}(
                ${junction.foreignKeyJunctionChild.childColumns[0]}: entity.${field.name}!.${junction.foreignKeyJunctionChild.parentColumns[0]},
                ${junction.foreignKeyJunctionParent.childColumns[0]}: entity.${junction.foreignKeyJunctionParent.parentColumns[0]},
                deleted: entity.${field.name}!.deleted,
              ));
            }''';
    } else {
      final String saveChildCode;
      if (junction.ignoreSaveChild) {
        saveChildCode = '';
      } else {
        saveChildCode =
            'await floorDatabase.${fieldOfDaoWithAllMethodsChild.field.name}.${fieldOfDaoWithAllMethodsChild.method.name}(entity.${field.name});';
      }
      code = '''
              $saveChildCode
              await floorDatabase.${fieldOfDaoWithAllMethodsJunction.field.name}.${fieldOfDaoWithAllMethodsJunction.method.name}(${entityJunctionClass.name}(
                ${junction.foreignKeyJunctionChild.childColumns[0]}: entity.${field.name}.${junction.foreignKeyJunctionChild.parentColumns[0]},
                ${junction.foreignKeyJunctionParent.childColumns[0]}: entity.${junction.foreignKeyJunctionParent.parentColumns[0]},
                deleted: entity.${field.name}!.deleted, // TODO todos esses lugares de deleted pegar os campos da pai e setar na filha
              ));''';
    }

    return code;
  }

  FieldOfDaoWithAllMethods? _findMethodsDaoSaveToEntity(Element element) {
    return _allFieldOfDaoWithAllMethods.firstWhereOrNull((e) {
      if (!e.method.hasAnnotation(annotations.save.runtimeType)) {
        return false;
      }
      if (e.method.parameters.length != 1) {
        throw _processorError.saveMethodParameterHaveMoreOne(e.method);
      }
      final parameter = e.method.parameters[0];
      if (parameter.type.isNullable) {
        throw _processorError.saveMethodParameterIsNullable(parameter);
      }
      if (parameter.type.element != element) {
        return false;
      }
      return true;
    });
  }

  String _getSaveEmbeddedEntity(final FieldElement field, String tableName) {
    final String code;

    final fieldType = field.type.isDartCoreList ? field.type.flatten() : field.type;

    final fieldTypeElement = fieldType.element;
    if (!(fieldTypeElement is ClassElement)) {
      throw _processorError.noMethodWithSaveAnnotation(field);
    }

    final fieldOfDaoWithAllMethods = _allFieldOfDaoWithAllMethods.firstWhereOrNull((e) {
      if (!e.method.hasAnnotation(annotations.save.runtimeType)) {
        return false;
      }
      if (e.method.parameters.length != 1) {
        throw _processorError.saveMethodParameterHaveMoreOne(e.method);
      }
      final parameter = e.method.parameters[0];
      if (parameter.type.isNullable) {
        throw _processorError.saveMethodParameterIsNullable(parameter);
      }
      if (parameter.type != fieldType) {
        return false;
      }
      return true;
    });

    if (fieldOfDaoWithAllMethods == null) {
      throw _processorError.noMethodWithSaveAnnotation(field);
    }

    final foreignKeys = getForeignKeys(fieldTypeElement);
    final foreignKeysRelation = foreignKeys.where((e) => e.parentName == tableName);
    if (foreignKeysRelation.isEmpty) {
      throw _processorError.foreignKeyDoesNotReferenceEntity(fieldTypeElement);
    }
    if (foreignKeysRelation.length > 1) {
      throw _processorError.twoForeignKeysForTheSameParentTable(fieldTypeElement);
    }

    final setFields = StringBuffer();
    final foreignKey = foreignKeysRelation.first;

    if (field.type.isDartCoreList) {
      for (var i = 0; i < foreignKey.parentColumns.length; i++) {
        setFields.writeln('sub.${foreignKey.childColumns[i]} = entity.${foreignKey.parentColumns[i]};');
      }
    } else {
      for (var i = 0; i < foreignKey.parentColumns.length; i++) {
        setFields
            .writeln('entity.${field.name}.${foreignKey.childColumns[i]} = entity.${foreignKey.parentColumns[i]};');
      }
    }
    if (field.type.isNullable && field.type.isDartCoreList) {
      code = '''          if (entity.${field.name} != null) {
            for(final sub in entity.${field.name}!) {
              ${setFields}await floorDatabase.${fieldOfDaoWithAllMethods.field.name}.${fieldOfDaoWithAllMethods.method.name}(sub);
            }
          }''';
    } else if (field.type.isDartCoreList) {
      code = '''          for(final sub in entity.${field.name}) {
            ${setFields}await floorDatabase.${fieldOfDaoWithAllMethods.field.name}.${fieldOfDaoWithAllMethods.method.name}(sub);
          }''';
    } else if (field.type.isNullable) {
      code = '''          if (entity.${field.name} != null) {
            ${setFields}await floorDatabase.${fieldOfDaoWithAllMethods.field.name}.${fieldOfDaoWithAllMethods.method.name}(entity.${field.name}!);
          }''';
    } else {
      code =
          '''                ${setFields}await floorDatabase.${fieldOfDaoWithAllMethods.field.name}.${fieldOfDaoWithAllMethods.method.name}(entity.${field.name});''';
    }

    return code;
  }
}
