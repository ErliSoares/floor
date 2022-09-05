import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';
import 'package:floor_generator/misc/type_utils.dart';

class RelationProcessorError {
  final FieldElement _fieldElement;

  RelationProcessorError(final FieldElement fieldElement) : _fieldElement = fieldElement;

  InvalidGenerationSourceError get invalidNumbersOfForeignKeysError {
    return InvalidGenerationSourceError(
      'Class must have two foreign keys.',
      todo: 'Define two fields with foreign keys to make the connection.',
      element: _fieldElement,
    );
  }

  InvalidGenerationSourceError get foreignKeysOfRelationWithNotRelationWithParent {
    return InvalidGenerationSourceError(
      'Foreign keys of relation with not relation with parent.',
      todo: 'Define in relation class relation with parent class.',
      element: _fieldElement,
    );
  }

  InvalidGenerationSourceError get moreThanOneColumnInTheKeyConnection {
    return InvalidGenerationSourceError(
      'Relation does not support foreign keys with more than one column for connection.',
      todo: 'In the foreign key of the relation, define only one field for connection in the list.',
      element: _fieldElement,
    );
  }

  InvalidGenerationSourceError get embeddedAndRelationSameField {
    return InvalidGenerationSourceError(
      'Embedded and relation feature cannot be used in the same field.',
      todo: 'Consider remove @embedded.',
      element: _fieldElement,
    );
  }

  InvalidGenerationSourceError get ignoreAndRelationSameField {
    return InvalidGenerationSourceError(
      'Skip element and relation feature cannot be used in the same field.',
      todo: 'Consider remove @ignore.',
      element: _fieldElement,
    );
  }

  InvalidGenerationSourceError get typeOfFieldIsNotClass {
    final type = _fieldElement.type.isDartCoreList ? _fieldElement.type.flatten() : _fieldElement.type;
    return InvalidGenerationSourceError(
      'The type ${type.getDisplayString(withNullability: false)} of fields with the @Relation annotation must be an entity.',
      todo: 'Remove the @Relation annotation or change the property type to an entity.',
      element: _fieldElement,
    );
  }

  InvalidGenerationSourceError twoForeignKeysForTheSameParentTable(ClassElement _classElement) {
    return InvalidGenerationSourceError(
      'More than one link from the child table to the same parent table, it was not implemented for two or more fields to link to the child table.',
      todo: 'Open a issue to implement the feature.',
      element: _classElement,
    );
  }

  InvalidGenerationSourceError foreignKeyDoesNotReferenceEntity(ClassElement _classElement) {
    return InvalidGenerationSourceError(
      "The class ${_classElement.name} doesn't reference a entity class parent ${_fieldElement.enclosingElement.name}.",
      element: _fieldElement,
    );
  }
}
