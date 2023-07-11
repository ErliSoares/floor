import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:floor_generator/misc/constants.dart';
import 'package:floor_generator/extension/field_element_extension.dart';
import 'package:floor_generator/misc/extension/dart_type_extension.dart';
import 'package:floor_generator/misc/extension/type_converter_element_extension.dart';
import 'package:floor_generator/misc/extension/type_converters_extension.dart';
import 'package:floor_generator/misc/type_utils.dart';
import 'package:floor_generator/processor/foreign_key_relation_processor.dart';
import 'package:floor_generator/processor/junction_processor.dart';
import 'package:floor_generator/processor/processor.dart';
import 'package:floor_generator/processor/relation_processor.dart';
import 'package:floor_generator/value_object/field.dart';
import 'package:floor_generator/misc/extension/string_extension.dart';
import 'package:floor_generator/value_object/type_converter.dart';
import 'package:source_gen/source_gen.dart';

class FieldProcessor extends Processor<Field> {
  final FieldElement _fieldElement;
  final String _prefix;
  final TypeConverter? _typeConverter;

  FieldProcessor(final FieldElement fieldElement, final TypeConverter? typeConverter, [final String prefix = ''])
      : _fieldElement = fieldElement,
        _typeConverter = typeConverter,
        _prefix = prefix;

  @override
  Field process() {
    final name = _fieldElement.name;
    final columnName =
        '$_prefix${_prefix == '' ? _fieldElement.nameColumnInSql() : _fieldElement.nameColumnInSql().firstCharToUpper()}';
    final isNullable = _fieldElement.type.isNullable;
    final typeConverter =
        {..._fieldElement.getTypeConverters(TypeConverterScope.field), _typeConverter}.whereNotNull().closestOrNull;

    final junction = JunctionProcessor(_fieldElement).process();
    final relation = RelationProcessor(_fieldElement).process();
    final foreignKeyRelation = ForeignKeyRelationProcessor(_fieldElement).process();

    return Field(
      _fieldElement,
      name,
      columnName,
      isNullable,
      junction != null || relation != null || foreignKeyRelation != null ? '' : _getSqlType(typeConverter),
      typeConverter,
      junction: junction,
      relation: relation,
      foreignKeyRelation: foreignKeyRelation,
      decimals: _fieldElement.columnDecimals(),
      length: _fieldElement.columnLength(),
    );
  }

  String _getSqlType(final TypeConverter? typeConverter) {
    final type = _fieldElement.type;
    if (type.isDefaultSqlType) {
      return type.asSqlType();
    } else if (typeConverter != null) {
      return typeConverter.databaseType.asSqlType();
    } else if (type.element is EnumElement) {
      final enumElement = type.element as EnumElement;
      final typeOfEnum = enumElement.typeOfEnum();
      if (typeOfEnum == null) {
        throw InvalidGenerationSourceError(
          'Enum type $type must be defined the values through the @EnumValue annotation, it cannot have different data types for the same enum.',
          todo: 'Put @EnumValue in all enums for type $type, all values must be of the same type.',
          element: _fieldElement,
        );
      }
      return typeOfEnum.asSqlType();
    } else {
      throw InvalidGenerationSourceError(
        '1 - Column type is not supported for $type.',
        todo: 'Either make to use a supported type or supply a type converter.',
        element: _fieldElement,
      );
    }
  }
}

extension on DartType {
  String asSqlType() {
    if (isDartCoreInt) {
      return SqlType.integer;
    } else if (isDartCoreString) {
      return SqlType.text;
    } else if (isDartCoreBool) {
      return SqlType.integer;
    } else if (isDartCoreDouble) {
      return SqlType.real;
    } else if (isUint8List) {
      return SqlType.blob;
    }
    throw StateError('This should really be unreachable');
  }
}
