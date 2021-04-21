import 'package:analyzer/dart/element/element.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations
    show Embedded;
import 'package:floor_generator/extension/field_element_extension.dart';
import 'package:floor_generator/misc/constants.dart';
import 'package:floor_generator/misc/type_utils.dart';
import 'package:floor_generator/processor/field_processor.dart';
import 'package:floor_generator/processor/processor.dart';
import 'package:floor_generator/value_object/embedded.dart';
import 'package:floor_generator/value_object/field.dart';

class EmbeddedProcessor extends Processor<Embedded> {
  final ClassElement _classElement;
  final FieldElement _fieldElement;
  final String _prefix;

  EmbeddedProcessor(final FieldElement fieldElement, [final String prefix = ''])
      : _fieldElement = fieldElement,
        _classElement = fieldElement.type.element as ClassElement,
        _prefix = prefix;

  @override
  Embedded process() {
    return Embedded(
      _fieldElement,
      _getFields(),
      _getChildren(),
    );
  }

  String _getPrefix() {
    return _prefix +
        ((_fieldElement
            .getAnnotation(annotations.Embedded)
            ?.getField(AnnotationField.embeddedPrefix))?.toStringValue() ?? '');
  }

  List<Field> _getFields() {
    final fields = _classElement.fields
        .where((fieldElement) => fieldElement.shouldBeIncluded())
        .map((field) => FieldProcessor(field, null, _getPrefix()).process())
        .toList();

    return fields;
  }

  List<Embedded> _getChildren() {
    return _classElement.fields
        .where((fieldElement) => fieldElement.isEmbedded)
        // pass the previous prefix so we can prepend it with the old ones
        .map((embedded) => EmbeddedProcessor(embedded, _getPrefix()).process())
        .toList();
  }
}
