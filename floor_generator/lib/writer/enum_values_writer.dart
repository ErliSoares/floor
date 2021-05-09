import 'package:analyzer/dart/element/element.dart';
import 'package:code_builder/code_builder.dart';
import 'package:floor_generator/misc/constants.dart';
import 'package:floor_generator/value_object/entity.dart';
import 'package:floor_generator/writer/writer.dart';
import 'package:source_gen/source_gen.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations;

class EnumValuesWriter extends Writer {
  final TypeChecker hasEnumValueAnnotation = const TypeChecker.fromRuntime(annotations.EnumValue);
  final TypeChecker hasDescriptionAnnotation = const TypeChecker.fromRuntime(annotations.Description);

  final List<Entity> _entities;

  EnumValuesWriter(final List<Entity> entities) : _entities = entities;

  @override
  Field write() {
    final enums = _removeDuplicate(_entities
        .expand((e) => e.fieldsAll.map((f) => f.fieldElement.type.element).whereType<ClassElement>())
        .toList());

    final code = enums.expand((e) {
      final enumValueAnnotations = e.annotatedWith(hasEnumValueAnnotation);
      if (enumValueAnnotations.isEmpty) {
        return <String>[];
      }

      final typeReturnIsString = !enumValueAnnotations.every((e) => !e.annotation.read(EnumValueField.value).isString);

      return enumValueAnnotations.map((item) {
        final enumValue = item.annotation.read('value').literalValue;
        return '${e.name}.${item.element.name}: ${typeReturnIsString ? '\'$enumValue\'' : enumValue},\n';
      });
    }).join();

    return Field((builder) => builder
      ..name = 'enumValues'
      ..modifier = FieldModifier.final$
      ..type = const Reference('Map<Object, Object>')
      ..assignment = Code('{$code}'));
  }

  List<ClassElement> _removeDuplicate(List<ClassElement> list) {
    for (int i = 0; i < list.length; i++) {
      final classElement = list[i];
      int index = i + 2;
      do {
        index = list.indexWhere((sub) => sub.name == classElement.name, index - 1);
        if (index != -1) {
          list.removeAt(index);
        }
      } while (index != -1 && index < list.length);
    }
    return list;
  }
}

extension _EnumElementExtension on ClassElement {
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
