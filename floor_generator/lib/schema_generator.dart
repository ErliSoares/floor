import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:collection/collection.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations;
import 'package:floor_generator/extension/class_extension.dart';
import 'package:floor_generator/extension/field_element_extension.dart';
import 'package:floor_generator/misc/constants.dart';
import 'package:floor_generator/misc/extension/dart_type_extension.dart';
import 'package:floor_generator/misc/extension/string_extension.dart';
import 'package:floor_generator/misc/extension/type_converter_element_extension.dart';
import 'package:floor_generator/misc/extension/type_converters_extension.dart';
import 'package:floor_generator/misc/type_utils.dart';
import 'package:floor_generator/processor/embedded_processor.dart';
import 'package:floor_generator/processor/junction_processor.dart';
import 'package:floor_generator/value_object/junction.dart';
import 'package:floor_generator/value_object/type_converter.dart';
import 'package:floor_generator/writer/enum_values_writer.dart';
import 'package:source_gen/source_gen.dart';

// ignore: implementation_imports
import 'package:source_gen/src/output_helpers.dart';

class SchemaGenerator extends Generator {
  TypeChecker get typeCheckerEntity => const TypeChecker.fromRuntime(annotations.Entity);

  TypeChecker get typeCheckerQueryView => TypeChecker.fromRuntime(annotations.queryView.runtimeType);

  TypeChecker get typeCheckerDatabase => const TypeChecker.fromRuntime(annotations.Database);

  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) async {
    final values = <String>{};

    for (var annotatedElement in library.annotatedWith(typeCheckerEntity)) {
      var generatedValue = generateForAnnotatedElement(
        annotatedElement.element,
        annotatedElement.annotation,
        buildStep,
      );
      await for (var value in normalizeGeneratorOutput(generatedValue)) {
        assert(value.length == value.trim().length);
        values.add(value);
      }

      generatedValue = writeEnumMapValues(annotatedElement.element);
      await for (var value in normalizeGeneratorOutput(generatedValue)) {
        assert(value.length == value.trim().length);
        values.add(value);
      }
    }

    for (var annotatedElement in library.annotatedWith(typeCheckerQueryView)) {
      final generatedValue = generateForAnnotatedElement(
        annotatedElement.element,
        annotatedElement.annotation,
        buildStep,
      );
      await for (var value in normalizeGeneratorOutput(generatedValue)) {
        assert(value.length == value.trim().length);
        values.add(value);
      }
    }

    return values.join('\n\n');
  }

  FutureOr<String> generateForAnnotatedElement(
    final Element element,
    final ConstantReader annotation,
    final BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError('The element is not a class.', element: element);
    }

    final code = codeForEntity(element);
    if (code.isEmpty) {
      return '';
    }

    final library = Library((builder) {
      builder.body.add(Code(code));
    });

    return library.accept(DartEmitter()).toString();
  }

  String writeEnumMapValues(Element element) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError('The element is not a class.', element: element);
    }
    return EnumValuesWriter(element).write();
  }

  String codeForEntity(ClassElement element) {
    if (element.isAbstract) {
      throw InvalidGenerationSourceError('The entity class has to be abstract.', element: element);
    }

    final tableName = element.tableName();
    final className = element.name;

    final fields = element
        .getAllFields()
        .expand((e) => e.isEmbedded ? e.toColumnDataEmbedded() : [e.toColumnData()])
        .whereNotNull();

    final cloneCode = _generateClone(element);

    final entryNotChangedOverrideCode = _generateEntryNotChangedOverride(element);

    final fieldsCode = _generateFields(element);

    final str = StringBuffer();

    final code = """mixin ${className}Mixin {
    
  $entryNotChangedOverrideCode
    
  @ignore
  ${className}Schema get schema => ${className}Schema.instance;
  
  $cloneCode
  
  $fieldsCode
}

class ${className}Schema extends Table {
  ${className}Schema._()
      : super(
          name: '$tableName',
          columns: [
${fields.map((e) => '            col${e.name.firstCharToUpper()}').join(',\n')}
          ],
        );

${fields.map((e) => e.writeCol()).join('\n')}

  static final ${className}Schema instance = ${className}Schema._();
}""";

    str.write(code);

    return str.toString();
  }

  String _generateFields(ClassElement classElement) {
    final fields = classElement.getAllFields();

    final fieldsCode = fields.map((e) {
      final isIgnored = e.hasAnnotation(annotations.Ignore);
      var ignoreForQuery = false;
      var ignoreForInsert = false;
      var ignoreForUpdate = false;
      var ignoreForDelete = false;

      if (isIgnored) {
        final ignoreAnnotation = e.getAnnotation(annotations.Ignore)!;
        ignoreForQuery = ignoreAnnotation.getField(IgnoreField.forQuery)!.toBoolValue()!;
        ignoreForInsert = ignoreAnnotation.getField(IgnoreField.forInsert)!.toBoolValue()!;
        ignoreForUpdate = ignoreAnnotation.getField(IgnoreField.forUpdate)!.toBoolValue()!;
        ignoreForDelete = ignoreAnnotation.getField(IgnoreField.forDelete)!.toBoolValue()!;
      }

      final String code;
      int totalIgnores = 0;
      if (ignoreForQuery) totalIgnores += 1;
      if (ignoreForInsert) totalIgnores += 1;
      if (ignoreForUpdate) totalIgnores += 1;
      if (ignoreForDelete) totalIgnores += 1;

      final valueDataBase = _getFieldValueDataBase(e);

      if (totalIgnores > 2) {
        var ignores = '';
        if (!ignoreForQuery) {
          ignores += ', ignoreForQuery: false';
        }
        if (!ignoreForInsert) {
          ignores += ', ignoreForInsert: false';
        }
        if (!ignoreForUpdate) {
          ignores += ', ignoreForUpdate: false';
        }
        if (!ignoreForDelete) {
          ignores += ', ignoreForDelete: false';
        }
        code =
            '''FieldData.ignoreAll('${e.name}', entry.${e.name}, $valueDataBase, '${e.nameColumnInSql()}'$ignores)''';
      } else {
        var ignores = '';
        if (ignoreForQuery) {
          ignores += ', ignoreForQuery: true';
        }
        if (ignoreForInsert) {
          ignores += ', ignoreForInsert: true';
        }
        if (ignoreForUpdate) {
          ignores += ', ignoreForUpdate: true';
        }
        if (ignoreForDelete) {
          ignores += ', ignoreForDelete: true';
        }
        code = '''FieldData('${e.name}', entry.${e.name}, $valueDataBase, '${e.nameColumnInSql()}'$ignores)''';
      }
      return code;
    }).join(',');
    return '''  @ignore
  List<FieldData> get fields {
    final entry = this as ${classElement.name};
    return [$fieldsCode];
  }''';
  }

  String _generateClone(ClassElement classElement) {
    final fields = classElement.getAllFields();

    final constructorParameters =
        classElement.constructors.first.parameters.where((e) => fields.any((f) => e.name == f.name));
    final fieldsOutsideConstructor = fields.where((f) => constructorParameters.every((e) => e.name != f.name)).toList();

    final parametersConstructor = constructorParameters
        .map((parameterElement) => _getParametersValuesConstructor(parameterElement, fields))
        .join(', ');

    final parametersOutsideConstructor = _getValueMappingOutsideConstructor(fields, fieldsOutsideConstructor);

    return '''  ${classElement.name} clone() {
    final entry = this as ${classElement.name};
    return ${classElement.name}(
      $parametersConstructor
    )$parametersOutsideConstructor;
  }''';
  }

  String _generateEntryNotChangedOverride(ClassElement classElement) {
    return '''  ${classElement.name}? _entryNotChanged;
  @Ignore()
  ${classElement.name}? get entryNotChanged => _entryNotChanged;
  @Ignore()
  set entryNotChanged(EntryBase? entryNotChanged) {
    if (entryNotChanged == null) {
      _entryNotChanged = null;
      return;
    }  
    if (entryNotChanged is! ${classElement.name}) {
      throw Exception('Objeto entryNotChanged para a entidade ${classElement.name} é inválida.');
    }
    _entryNotChanged = entryNotChanged;
  }''';
  }

  String _getValueMappingOutsideConstructor(
      final List<FieldElement> fields, final List<FieldElement> fieldsOutsideConstructor) {
    final keyValueList = fieldsOutsideConstructor
        .map((fieldElement) {
          final parameterName = fieldElement.name;
          final field = fields.firstWhereOrNull((field) => field.name == parameterName);
          if (field != null && field.setter != null) {
            String parameterValue;
            final typeParameter = fieldElement.type.element;
            if (typeParameter is ClassElement && typeParameter.isEntity) {
              final nullableText = field.type.isNullable ? '?' : '';
              parameterValue = 'entry.$parameterName$nullableText.clone()';
            } else if (fieldElement.type.isDartCoreList) {
              final typeCollection = fieldElement.type.flatten().element;
              final nullableText = field.type.isNullable ? '?' : '';
              if (typeCollection is ClassElement && typeCollection.isEntity) {
                parameterValue = 'entry.$parameterName$nullableText.map((e) => e.clone()).toList()';
              } else {
                parameterValue = '[...entry.$parameterName$nullableText]';
              }
            } else {
              parameterValue = 'entry.$parameterName';
            }

            return '..$parameterName = $parameterValue';
          }
          return null;
        })
        .whereNotNull()
        .toList();

    return keyValueList.join('\n');
  }

  String _getParametersValuesConstructor(
    final ParameterElement parameterElement,
    final List<FieldElement> fields,
  ) {
    final parameterName = parameterElement.name;

    final field = fields.firstWhere((e) => e.name == parameterName);

    String parameterValue;
    final typeParameter = parameterElement.type.element;
    if (typeParameter is ClassElement && typeParameter.isEntity) {
      final nullableText = field.type.isNullable ? '?' : '';
      parameterValue = 'entry.$parameterName$nullableText.clone()';
    } else if (parameterElement.type.isDartCoreList) {
      final typeCollection = parameterElement.type.flatten().element;
      final nullableText = field.type.isNullable ? '?' : '';
      if (typeCollection is ClassElement && typeCollection.isEntity) {
        parameterValue = 'entry.$parameterName$nullableText.map((e) => e.clone()).toList()';
      } else {
        parameterValue = '[...entry.$parameterName$nullableText]';
      }
    } else {
      parameterValue = 'entry.$parameterName';
    }

    if (parameterElement.isNamed) {
      return '$parameterName: $parameterValue';
    }
    return parameterValue;
  }

  String _getFieldValueDataBase(FieldElement parameter) {
    if (parameter.type.isDefaultSqlType) {
      if (parameter.type.isDartCoreBool) {
        return 'entry.${parameter.name} ? 1 : 0';
      } else {
        return 'entry.${parameter.name}';
      }
    } else if (parameter.type.element is ClassElement && (parameter.type.element as ClassElement).isEnum) {
      return 'entry.${parameter.name}.value';
    } else {
      final typeConverter = parameter.getAllTypeConverters().getClosestOrNull(parameter.type);
      if (typeConverter == null) {
        return 'null';
      }
      return '${typeConverter.name.decapitalize()}.encode(entry.${parameter.name})';
    }
  }
}

extension on FieldElement {
  List<ColumnData> toColumnDataEmbedded() {
    final converters = getAllTypeConverters();
    final fieldProcessed = EmbeddedProcessor(this, converters).process();
    final fields = [...fieldProcessed.children, ...fieldProcessed.fields];
    return fields.map((e) => e.fieldElement.toColumnData(fieldProcessed.prefix)).whereNotNull().toList();
  }

  Set<TypeConverter> getAllTypeConverters() {
    Set<TypeConverter> converters = {...getTypeConverters(TypeConverterScope.field)};
    final enclosingElement = this.enclosingElement;
    if (enclosingElement is ClassElement) {
      converters = {...converters, ...enclosingElement.getTypeConverters(TypeConverterScope.queryable)};
    }
    return converters;
  }

  ColumnData? toColumnData([String? prefix]) {
    if (isStatic || isSynthetic || isEmbedded) {
      return null;
    }
    final isIgnored = hasAnnotation(annotations.Ignore);
    var ignoreForQuery = false;
    var ignoreForInsert = false;
    var ignoreForUpdate = false;
    var ignoreForDelete = false;

    if (isIgnored) {
      final ignoreAnnotation = getAnnotation(annotations.Ignore)!;
      ignoreForQuery = ignoreAnnotation.getField(IgnoreField.forQuery)!.toBoolValue()!;
      ignoreForInsert = ignoreAnnotation.getField(IgnoreField.forInsert)!.toBoolValue()!;
      ignoreForUpdate = ignoreAnnotation.getField(IgnoreField.forUpdate)!.toBoolValue()!;
      ignoreForDelete = ignoreAnnotation.getField(IgnoreField.forDelete)!.toBoolValue()!;
      if (ignoreForQuery && ignoreForInsert && ignoreForUpdate && ignoreForDelete) {
        return null;
      }
    }
    var allTypeConverters = {...getTypeConverters(TypeConverterScope.field)};
    final enclosingElement = this.enclosingElement;
    if (enclosingElement is ClassElement) {
      allTypeConverters = {...allTypeConverters, ...enclosingElement.getTypeConverters(TypeConverterScope.queryable)};
    }
    final typeConverter = allTypeConverters.getClosestOrNull(type);

    Junction? junction;
    DartType? databaseType;
    String typeStr;
    if (isRelation() || isJunction() || isForeignKeyRelation()) {
      databaseType = type;
      typeStr = 'expand';
      junction = JunctionProcessor(this).process();
    } else {
      if (type.isDefaultSqlType) {
        databaseType = type;
      } else if (typeConverter != null) {
        databaseType = typeConverter.databaseType;
      } else if (type.element is ClassElement && (type.element as ClassElement).isEnum) {
        final classElement = type.element as ClassElement;
        databaseType = classElement.typeOfEnum();
        if (databaseType == null) {
          throw InvalidGenerationSourceError(
            'Enum type $type must be defined the values through the @EnumValue annotation, it cannot have different data types for the same enum.',
            todo: 'Put @EnumValue in all enums for type $type, all values must be of the same type.',
            element: this,
          );
        }
      } else {
        throw InvalidGenerationSourceError(
          '3 - Column type is not supported for $type. ${allTypeConverters.length}',
          todo: 'Either make to use a supported type or supply a type converter.',
          element: this,
        );
      }

      if (databaseType.isDartCoreInt) {
        typeStr = 'int';
      } else if (databaseType.isDartCoreString) {
        typeStr = 'text';
      } else if (databaseType.isDartCoreBool) {
        typeStr = 'int';
      } else if (databaseType.isDartCoreDouble) {
        typeStr = 'real';
      } else if (databaseType.isUint8List) {
        typeStr = 'blob';
      } else {
        throw StateError('Type ${databaseType.getDisplayString(withNullability: false)} of property is not valid.');
      }
    }

    String name = this.name;
    if (prefix != null) {
      name = '$prefix${name.firstCharToUpper()}';
    }

    return ColumnData(
      name,
      typeStr,
      nullable: databaseType.isNullable,
      useInIDelete: !ignoreForDelete,
      useInInsert: !ignoreForInsert,
      useInIUpdate: !ignoreForUpdate,
      useInQuery: !ignoreForQuery,
      junction: junction,
      converter: typeConverter,
      element: type.element,
    );
  }
}

class ColumnData {
  ColumnData(
    this.name,
    this.type, {
    required this.nullable,
    required this.useInQuery,
    required this.useInInsert,
    required this.useInIUpdate,
    required this.useInIDelete,
    required this.junction,
    required this.converter,
    required this.element,
  });

  final bool useInQuery;
  final bool useInInsert;
  final bool useInIUpdate;
  final bool useInIDelete;
  final Junction? junction;
  final TypeConverter? converter;
  final Element? element;

  final String type;

  final bool nullable;

  final String name;

  String writeCol() {
    final str = StringBuffer();

    var setAllUse = false;
    str.write('  static final col${name.firstCharToUpper()} = Column');

    if (junction != null) {
      str.write('.junction');
    } else if (useInQuery && useInInsert && useInIUpdate && useInIDelete) {
      str.write('.useAll');
    } else if (useInQuery && !useInInsert && !useInIUpdate && !useInIDelete) {
      str.write('.onlyQuery');
    } else if (!useInQuery && useInInsert && !useInIUpdate && !useInIDelete) {
      str.write('.onlyInsert');
    } else if (!useInQuery && !useInInsert && useInIUpdate && !useInIDelete) {
      str.write('.onlyUpdate');
    } else if (!useInQuery && !useInInsert && !useInIUpdate && useInIDelete) {
      str.write('.onlyDelete');
    } else {
      setAllUse = true;
    }

    String secondParameter;
    if (junction != null) {
      secondParameter = '''JunctionData(
        table: '${junction!.entityJunction.name}',
        tableChildField: '${junction!.foreignKeyJunctionChild.childColumns[0]}',
        tableParentField: '${junction!.foreignKeyJunctionParent.childColumns[0]}',
        parentTableField: '${junction!.foreignKeyJunctionChild.parentColumns[0]}',
        parentTable: '${junction!.parentElement.tableName()}',
      )''';
    } else {
      secondParameter = 'DbType.$type';
    }

    str.write('(\'$name\', $secondParameter, nullable: $nullable');

    if (setAllUse) {
      str.write(
          ', useInQuery: $useInQuery, useInInsert: $useInInsert, useInIUpdate: $useInIUpdate, useInIDelete: $useInIDelete');
    }

    final element = this.element;
    if (converter != null) {
      str.write(', converter: ');
      str.write(converter!.name.decapitalize());
    } else if (element is ClassElement && element.isEnum) {
      str.write(', converter: const EnumConverter(_');
      str.write(element.name.decapitalize());
      str.write(')');
    }
    str.write(');');

    return str.toString();
  }
}
