
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
import 'package:floor_generator/value_object/type_converter.dart';
import 'package:floor_generator/misc/extension/type_converters_extension.dart';

class EmbeddedProcessor extends Processor<Embedded> {
  final ClassElement _classElement;
  final FieldElement _fieldElement;
  final String _prefix;
  final List<FieldElement> _fields;
  final Set<TypeConverter> converters;

  EmbeddedProcessor(final FieldElement fieldElement, this.converters, [final String prefix = ''])
      : _fieldElement = fieldElement,
        _classElement = fieldElement.type.element as ClassElement,
        _prefix = prefix,
        _fields = [
          ...(fieldElement.type.element as ClassElement).fields,
          ...(fieldElement.type.element as ClassElement).allSupertypes.expand((type) => type.element.fields),
        ];

  @override
  Embedded process() {
    return Embedded(
      _fieldElement,
      _getFields(),
      _getChildren(),
      _getPrefix(),
    );
  }

  String _getPrefix() {
    return _prefix +
        ((_fieldElement
            .getAnnotation(annotations.Embedded)
            ?.getField(AnnotationField.embeddedPrefix))?.toStringValue() ?? '');
  }

  List<Field> _getFields() {
    return _fields.where((fieldElement) => fieldElement.shouldBeIncludedAnyOperation())
        .map((field) {
          return FieldProcessor(field, converters.getClosestOrNull(field.type), _getPrefix()).process();
    })
        .toList();
  }

  List<Embedded> _getChildren() {
    return _fields
        .where((fieldElement) => fieldElement.isEmbedded)
        // pass the previous prefix so we can prepend it with the old ones
        .map((embedded) => EmbeddedProcessor(embedded, converters, _getPrefix()).process())
        .toList();
  }
}
