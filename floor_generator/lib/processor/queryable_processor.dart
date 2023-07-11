import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:floor_generator/misc/extension/dart_type_extension.dart';
import 'package:floor_generator/extension/field_element_extension.dart';
import 'package:floor_generator/misc/extension/set_extension.dart';
import 'package:floor_generator/misc/extension/string_extension.dart';
import 'package:floor_generator/misc/extension/type_converter_element_extension.dart';
import 'package:floor_generator/misc/extension/type_converters_extension.dart';
import 'package:floor_generator/misc/type_utils.dart';
import 'package:floor_generator/processor/embedded_processor.dart';
import 'package:floor_generator/processor/error/queryable_processor_error.dart';
import 'package:floor_generator/processor/field_processor.dart';
import 'package:floor_generator/processor/processor.dart';
import 'package:floor_generator/value_object/embedded.dart';
import 'package:floor_generator/value_object/field.dart';
import 'package:floor_generator/value_object/fieldable.dart';
import 'package:floor_generator/value_object/queryable.dart';
import 'package:floor_generator/value_object/type_converter.dart';
import 'package:meta/meta.dart';
import 'package:source_gen/source_gen.dart';

abstract class QueryableProcessor<T extends Queryable> extends Processor<T> {
  final QueryableProcessorError _queryableProcessorError;

  @protected
  final ClassElement classElement;
  @protected
  final List<FieldElement> _fields;

  final Set<TypeConverter> queryableTypeConverters;

  @protected
  QueryableProcessor(
    this.classElement,
    final Set<TypeConverter> typeConverters,
  )   : _queryableProcessorError = QueryableProcessorError(classElement),
        queryableTypeConverters = typeConverters + classElement.getTypeConverters(TypeConverterScope.queryable),
        _fields = classElement.getAllFields();

  @protected
  List<Field> getFieldsWithOutCheckIgnore() {
    if (classElement.mixins.isNotEmpty) {
      throw _queryableProcessorError.prohibitedMixinUsage;
    }

    return _fields.where((fieldElement) => fieldElement.shouldBeIncludedAnyOperation()).map((field) {
      final typeConverter = queryableTypeConverters.getClosestOrNull(field.type);
      return FieldProcessor(field, typeConverter).process();
    }).toList();
  }

  @protected
  List<FieldElement> getFieldsOutsideConstructor() {
    if (classElement.mixins.isNotEmpty) {
      throw _queryableProcessorError.prohibitedMixinUsage;
    }
    final constructorParameters =
        classElement.constructors.first.parameters.where((e) => _fields.any((f) => e.displayName == f.displayName));

    return _fields
        .where((fieldElement) =>
            fieldElement.shouldBeIncludedForQuery() && constructorParameters.every((e) => e.name != fieldElement.name))
        .toList();
  }

  String _getValueMappingOutsideConstructor(final List<Fieldable> fields, List<FieldElement> fieldsOutsideConstructor) {
    final keyValueList = fieldsOutsideConstructor
        .map((fieldElement) {
          final parameterName = fieldElement.displayName;
          final field = fields.firstWhereOrNull((field) => field.fieldElement.name == parameterName);
          if (field is Field) {
            final columnName = field.columnName;
            final attributeValue = _getAttributeValue(fieldElement, field);
            return '..$columnName = $attributeValue';
          }
          return null;
        })
        .whereNotNull()
        .toList();

    return keyValueList.join('\n');
  }

  String _getAttributeValue(FieldElement parameterElement, Field field) {
    final databaseValue = "row['${field.columnName}']";

    String parameterValue;

    if (parameterElement.type.isDefaultSqlType) {
      parameterValue = databaseValue.cast(
        parameterElement.type,
        parameterElement,
      );
    } else if (parameterElement.type.element is EnumElement) {
      if (field.isNullable) {
        parameterValue =
            '$databaseValue == null ? null : ${parameterElement.type.element?.displayName}.values.firstWhere((e) => e.value == $databaseValue)';
      } else {
        parameterValue =
            '${parameterElement.type.element?.displayName}.values.firstWhere((e) => e.value == $databaseValue)';
      }
    } else {
      final typeConverter =
          [...queryableTypeConverters, field.typeConverter].whereNotNull().getClosest(parameterElement.type);
      final castedDatabaseValue = databaseValue.cast(
        typeConverter.databaseType,
        parameterElement,
      );

      parameterValue = '${typeConverter.name.decapitalize()}.decode($castedDatabaseValue)';
    }
    return parameterValue; // also covers positional parameter
  }

  @protected
  List<Embedded> getEmbeddeds() {
    return _fields
        .where((fieldElement) => fieldElement.isEmbedded)
        .map((embedded) => EmbeddedProcessor(embedded, queryableTypeConverters).process())
        .toList();
  }

  @protected
  String getConstructor(final List<Fieldable> fields) {
    final fieldsOutsideConstructor = getFieldsOutsideConstructor();
    final valueMappingOutsideConstructor = _getValueMappingOutsideConstructor(fields, fieldsOutsideConstructor);
    return _getConstructor(classElement, fields) + valueMappingOutsideConstructor;
  }

  String _getConstructor(ClassElement classElement, final List<Fieldable> fields) {
    final constructorParameters = classElement.constructors.first.parameters;
    final parameterValues = constructorParameters
        .map((parameterElement) => _getParameterValue(parameterElement, fields))
        .where((parameterValue) => parameterValue != null)
        .join(', ');

    return '${classElement.displayName}($parameterValues)';
  }

  /// Returns `null` whenever field is @ignored
  String? _getParameterValue(
    final ParameterElement parameterElement,
    final List<Fieldable> fields,
  ) {
    final parameterName = parameterElement.displayName;
    final field =
        // null whenever field is @ignored
        fields.firstWhereOrNull((field) => field.fieldElement.displayName == parameterName);
    if (field != null) {
      if (field is Field) {
        final databaseValue = "row['${field.columnName}']";

        String parameterValue;

        if (parameterElement.type.isDefaultSqlType) {
          parameterValue = databaseValue.cast(
            parameterElement.type,
            parameterElement,
          );
        } else if (parameterElement.type.element is EnumElement) {
          if (field.isNullable) {
            parameterValue =
                '$databaseValue == null ? null : ${parameterElement.type.element?.displayName}.values.firstWhere((e) => e.value == $databaseValue)';
          } else {
            parameterValue =
                '${parameterElement.type.element?.displayName}.values.firstWhere((e) => e.value == $databaseValue)';
          }
        } else {
          final typeConverter =
              [...queryableTypeConverters, field.typeConverter].whereNotNull().getClosest(parameterElement.type);
          final castedDatabaseValue = databaseValue.cast(
            typeConverter.databaseType,
            parameterElement,
          );

          parameterValue = '${typeConverter.name.decapitalize()}.decode($castedDatabaseValue)';
        }

        if (parameterElement.isNamed) {
          return '$parameterName: $parameterValue';
        }
        return parameterValue; // also covers positional parameter
      } else if (field is Embedded) {
        final parameterValue = _getConstructor(field.classElement, [...field.fields, ...field.children]);
        if (parameterElement.isNamed) {
          return '$parameterName: $parameterValue';
        }
        return parameterValue;
      }
    }
    return null;
  }

  @protected
  bool shouldBeIncludedAnyOperation(FieldElement fieldElement) {
    return fieldElement.shouldBeIncludedAnyOperation();
  }

  @protected
  bool shouldBeIncludedForDataBaseSchema(FieldElement fieldElement) {
    return fieldElement.shouldBeIncludedForDataBaseSchema();
  }

  @protected
  bool shouldBeIncludedForQuery(FieldElement fieldElement) {
    return fieldElement.shouldBeIncludedForQuery();
  }

  @protected
  bool shouldBeIncludedForInsert(FieldElement fieldElement) {
    return fieldElement.shouldBeIncludedForInsert();
  }

  @protected
  bool shouldBeIncludedForUpdate(FieldElement fieldElement) {
    return fieldElement.shouldBeIncludedForUpdate();
  }

  @protected
  bool shouldBeIncludedForDelete(FieldElement fieldElement) {
    return fieldElement.shouldBeIncludedForDelete();
  }
}

extension on String {
  String cast(DartType dartType, VariableElement parameterElement) {
    if (dartType.isDartCoreBool) {
      if (dartType.isNullable) {
        // if the value is null, return null
        // if the value is not null, interpret 1 as true and 0 as false
        return '$this == null ? null : ($this as int) != 0';
      } else {
        return '($this as int) != 0';
      }
    } else if (dartType.isDartCoreString ||
        dartType.isDartCoreInt ||
        dartType.isUint8List ||
        dartType.isDartCoreDouble) {
      final typeString = dartType.getDisplayString(withNullability: true);
      return '$this as $typeString';
    } else {
      throw InvalidGenerationSourceError(
        'Trying to convert unsupported type $dartType.',
        todo: 'Consider adding a type converter.',
        element: parameterElement,
      );
    }
  }
}
