import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations;
import 'package:floor_generator/misc/constants.dart';
import 'package:floor_generator/misc/extension/dart_type_extension.dart';
import 'package:floor_generator/misc/extension/type_converter_element_extension.dart';
import 'package:floor_generator/misc/extension/type_converters_extension.dart';
import 'package:floor_generator/misc/type_utils.dart';
import 'package:floor_generator/processor/embedded_processor.dart';
import 'package:floor_generator/value_object/type_converter.dart';
import 'package:source_gen/source_gen.dart';
import 'package:collection/collection.dart';
import 'package:source_gen/src/output_helpers.dart';
import 'package:floor_generator/extension/field_element_extension.dart';

class SchemaGenerator extends Generator {
  TypeChecker get typeCheckerEntity => const TypeChecker.fromRuntime(annotations.Entity);

  TypeChecker get typeCheckerQueryView => TypeChecker.fromRuntime(annotations.queryView.runtimeType);

  TypeChecker get typeCheckerDatabase => const TypeChecker.fromRuntime(annotations.Database);

  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) async {
    final values = <String>{};

    for (var annotatedElement in library.annotatedWith(typeCheckerEntity)) {
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

  String codeForEntity(ClassElement element) {
    if (element.isAbstract) {
      throw InvalidGenerationSourceError('The entity class has to be abstract.', element: element);
    }

    final tableName = element.tableName();
    final className = element.displayName;

    final fields = [
      ...element.fields,
      ...element.allSupertypes.expand((type) => type.element.fields),
    ]
        .expand((e) => e.isEmbedded ? e.toColumnDataEmbedded() : [e.toColumnData()])
        .where((e) => e != null)
        .cast<ColumnData>();

    final str = StringBuffer();

    final code = """mixin ${className}Mixin {
  @ignore
  @JsonKey(ignore: true)
  ${className}Schema get schema => ${className}Schema.instance;
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
}

extension StringExtension on String {
  String firstCharToUpper() {
    if (isEmpty) {
      return this;
    }
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

extension on FieldElement {
  List<ColumnData> toColumnDataEmbedded() {
    Set<TypeConverter> converters = {...getTypeConverters(TypeConverterScope.field)};
    final enclosingElement = this.enclosingElement;
    if (enclosingElement is ClassElement) {
      converters = {...converters, ...enclosingElement.getTypeConverters(TypeConverterScope.queryable)};
    }
    final fieldProcessed = EmbeddedProcessor(this, converters).process();
    final fields = [...fieldProcessed.children, ...fieldProcessed.fields];
    return fields.map((e) => e.fieldElement.toColumnData(fieldProcessed.prefix)).whereNotNull().toList();
  }

  ColumnData? toColumnData([String? prefix]) {
    if (isStatic || isSynthetic || isEmbedded) {
      return null;
    }
    // TODO Tratar quando for sub
    final isSub = hasAnnotation(annotations.sub.runtimeType);
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

    DartType? databaseType;
    String typeStr;
    if (isSub) {
      databaseType = type;
      typeStr = 'expand';
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

    String name = displayName;
    if (prefix != null) {
      name = '$prefix${name.firstCharToUpper()}';
    }

    return ColumnData(
      name, typeStr, nullable: databaseType.isNullable,
      useInIDelete: !ignoreForDelete,
      useInInsert: !ignoreForInsert,
      useInIUpdate: !ignoreForUpdate,
      useInQuery: !ignoreForQuery,
      relationship: null,
      // TODO Set relationship
      converter: typeConverter,
      // TODO Set converter
    );
  }
}

class ColumnData {
  ColumnData(
    this.name,
    this.type, {
    this.relationship,
    required this.nullable,
    required this.useInQuery,
    required this.useInInsert,
    required this.useInIUpdate,
    required this.useInIDelete,
    required this.converter,
  });

  final bool useInQuery;
  final bool useInInsert;
  final bool useInIUpdate;
  final bool useInIDelete;

  TypeConverter? converter;

  annotations.ForeignKey? relationship;

  bool get isSub => relationship != null;

  final String type;

  final bool nullable;

  final String name;

  String writeCol() {
    final str = StringBuffer();

    var setAllUse = false;
    str.write('  static final col${name.firstCharToUpper()} = Column');

    if (useInQuery && useInInsert && useInIUpdate && useInIDelete) {
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

    str.write('(\'$name\', DbType.$type, nullable: $nullable');

    if (setAllUse) {
      str.write(
          ', useInQuery: $useInQuery, useInInsert: $useInInsert, useInIUpdate: $useInIUpdate, useInIDelete: $useInIDelete');
    }

    if (relationship != null) {
      throw Exception('NotImplemented');
      // TODO Implementar
    }

    if (converter != null) {
      //throw Exception('NotImplemented');
      // TODO Implementar
    }

    str.write(');');

    return str.toString();
  }
}
