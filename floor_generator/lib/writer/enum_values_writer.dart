import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations;
import 'package:floor_generator/misc/constants.dart';
import 'package:floor_generator/misc/extension/string_extension.dart';
import 'package:floor_generator/misc/type_utils.dart';
import 'package:source_gen/source_gen.dart';

class EnumValuesWriter {
  final TypeChecker hasEnumValueAnnotation = const TypeChecker.fromRuntime(annotations.EnumValue);
  final TypeChecker hasDescriptionAnnotation = const TypeChecker.fromRuntime(annotations.Description);

  final ClassElement _classElement;

  EnumValuesWriter(final ClassElement classElement) : _classElement = classElement;

  String write() {
    final fields = _classElement.getAllFields();

    final enums = _removeDuplicate(fields.map((f) => f.type.element).whereType<EnumElement>().toList());

    return enums
        .map((e) {
          final enumValueAnnotations = e.annotatedWith(hasEnumValueAnnotation);
          if (enumValueAnnotations.isEmpty) {
            return null;
          }

          final typeReturnIsString =
              !enumValueAnnotations.every((e) => !e.annotation.read(EnumValueField.value).isString);

          final valuesEnums = enumValueAnnotations.map((item) {
            final enumValue = item.annotation.read('value').literalValue;
            return '${e.name}.${item.element.name}: ${typeReturnIsString ? '\'$enumValue\'' : enumValue},\n';
          });
          if (valuesEnums.isEmpty) {
            return null;
          }

          return '''const Map<Object, int> _${e.name.decapitalize()} = {
  ${valuesEnums.join()}
};''';
        })
        .whereNotNull()
        .join('\n');
  }

  List<EnumElement> _removeDuplicate(List<EnumElement> list) {
    for (int i = 0; i < list.length; i++) {
      final enumElement = list[i];
      int index = i + 1;
      do {
        index = list.indexWhere((m) => m.name == enumElement.name, index);
        if (index != -1) {
          list.removeAt(index);
        }
      } while (index != -1 && index < list.length);
    }
    return list;
  }
}

extension _EnumElementExtension on EnumElement {
  Iterable<AnnotatedElement> annotatedWith(TypeChecker checker) {
    return fields
        .map((f) {
          final annotation = checker.firstAnnotationOf(f, throwOnUnresolved: true);
          return (annotation != null) ? AnnotatedElement(ConstantReader(annotation), f) : null;
        })
        .where((e) => e != null)
        .cast();
  }
}
