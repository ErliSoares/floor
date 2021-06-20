import 'dart:typed_data';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations;
import 'package:floor_generator/misc/constants.dart';
import 'package:source_gen/source_gen.dart';

extension SupportedTypeChecker on DartType {
  /// Whether this [DartType] is either
  /// - String
  /// - bool
  /// - int
  /// - double
  /// - Uint8List
  bool get isDefaultSqlType {
    return TypeChecker.any([
      _stringTypeChecker,
      _boolTypeChecker,
      _intTypeChecker,
      _doubleTypeChecker,
      _uint8ListTypeChecker,
    ]).isExactlyType(this);
  }
}

extension Uint8ListTypeChecker on DartType {
  bool get isUint8List => getDisplayString(withNullability: false) == 'Uint8List';
}

extension StreamTypeChecker on DartType {
  bool get isStream => _streamTypeChecker.isExactlyType(this);
}

extension FlattenUtil on DartType {
  DartType flatten() {
    return (this as ParameterizedType).typeArguments.first;
  }
}

extension LoadOptionsChecker on DartType {
  bool get isLoadOptions => _loadOptionsTypeChecker.isExactlyType(this);

  bool get isLoadOptionsEntry => _loadOptionsEntryTypeChecker.isExactlyType(this);
}

extension AnnotationChecker on Element {
  bool hasAnnotation(final Type type) {
    return _typeChecker(type).hasAnnotationOfExact(this);
  }

  /// Returns the first annotation object found of [type]
  /// or `null` if annotation of [type] not found
  DartObject? getAnnotation(final Type type) {
    return _typeChecker(type).firstAnnotationOfExact(this);
  }
}

extension ClassElementExtension on ClassElement {
  List<MethodElement> getAllMethods() {
    final methods = [...this.methods];
    for (var superType in allSupertypes) {
      if (superType.element.isSynthetic) {
        continue;
      }  
      for (var methodSuper in superType.methods) {
        if (methodSuper.isSynthetic || methodSuper.isStatic || methodSuper.isPrivate) {
          continue;
        }
        if (methods.any((e) => e.name == methodSuper.name)) {
          continue;
        }
        methods.add(methodSuper);
      }
    }
    return methods;
  }

  List<FieldElement> getAllFields() {
    final allFields = [...fields];
    for (var superType in allSupertypes) {
      if (superType.element.isSynthetic) {
        continue;
      }
      for (var fieldSuper in superType.element.fields) {
        if (fieldSuper.isSynthetic || fieldSuper.isStatic || fieldSuper.isPrivate) {
          continue;
        }
        if (allFields.any((e) => e.name == fieldSuper.name)) {
          continue;
        }
        allFields.add(fieldSuper);
      }
    }
    return allFields;
  }

  String tableName() {
    final DartObject? annotation = getAnnotation(annotations.Entity);
    if (annotation == null) {
      return '';
    }
    return annotation.getField(AnnotationField.entityTableName)?.toStringValue() ?? displayName;
  }

  DartType? typeOfEnum() {
    final types = fields.where((e) => e.isEnumConstant).map((e) {
      if (!e.hasAnnotation(annotations.EnumValue)) {
        return null;
      }
      final annotation = e.getAnnotation(annotations.EnumValue);
      return annotation?.getField(EnumValueField.value)?.type;
    }).where((e) => e != null);
    if (types.isEmpty) {
      return null;
    }
    final first = types.first;
    if (types.every((e) => e == first)) {
      return first;
    }
    return null;
  }
}

TypeChecker _typeChecker(final Type type) => TypeChecker.fromRuntime(type);

final _loadOptionsTypeChecker = _typeChecker(annotations.LoadOptions);

final _loadOptionsEntryTypeChecker = _typeChecker(annotations.LoadOptionsEntry);

final _stringTypeChecker = _typeChecker(String);

final _boolTypeChecker = _typeChecker(bool);

final _intTypeChecker = _typeChecker(int);

final _doubleTypeChecker = _typeChecker(double);

final _uint8ListTypeChecker = _typeChecker(Uint8List);

final _streamTypeChecker = _typeChecker(Stream);
