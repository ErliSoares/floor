import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';
import 'package:floor_generator/misc/type_utils.dart';

class JunctionProcessorError {
  final FieldElement _fieldElement;

  JunctionProcessorError(final FieldElement fieldElement) : _fieldElement = fieldElement;

  InvalidGenerationSourceError get invalidNumbersOfForeignKeysError {
    return InvalidGenerationSourceError(
      'Class must have two foreign keys.',
      todo: 'Define two fields with foreign keys to make the connection.',
      element: _fieldElement,
    );
  }

  InvalidGenerationSourceError get foreignKeysOfJunctionWithNotRelationWithParent {
    return InvalidGenerationSourceError(
      'Foreign keys of junction with not relation with parent.',
      todo: 'Define in junction class relation with parent class.',
      element: _fieldElement,
    );
  }

  InvalidGenerationSourceError get moreThanOneColumnInTheKeyConnection {
    return InvalidGenerationSourceError(
      'Junction does not support foreign keys with more than one column for connection.',
      todo: 'In the foreign key of the junction, define only one field for connection in the list.',
      element: _fieldElement,
    );
  }

  InvalidGenerationSourceError get embeddedAndJunctionSameField {
    return InvalidGenerationSourceError(
      'Embedded and junction feature cannot be used in the same field.',
      todo: 'Consider remove @embedded.',
      element: _fieldElement,
    );
  }

  InvalidGenerationSourceError get ignoreAndJunctionSameField {
    return InvalidGenerationSourceError(
      'Skip element and junction feature cannot be used in the same field.',
      todo: 'Consider remove @ignore.',
      element: _fieldElement,
    );
  }

  InvalidGenerationSourceError get typeOfFieldIsNotClass {
    final type = _fieldElement.type.isDartCoreList ? _fieldElement.type.flatten() : _fieldElement.type;
    return InvalidGenerationSourceError(
      'The type ${type.getDisplayString(withNullability: false)} of fields with the @Junction annotation must be an entity.',
      todo: 'Remove the @Junction annotation or change the property type to an entity.',
      element: _fieldElement,
    );
  }
}
