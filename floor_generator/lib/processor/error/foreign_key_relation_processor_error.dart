import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';
import 'package:floor_generator/misc/type_utils.dart';

class ForeignKeyRelationProcessorError {
  final FieldElement _fieldElement;

  ForeignKeyRelationProcessorError(final FieldElement fieldElement)
      : _fieldElement = fieldElement;

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

  InvalidGenerationSourceError get embeddedAndForeignKeyRelationSameField {
    return InvalidGenerationSourceError(
      'Embedded and foreign key relation feature cannot be used in the same field.',
      todo: 'Consider remove @embedded.',
      element: _fieldElement,
    );
  }

  InvalidGenerationSourceError get ignoreAndForeignKeyRelationSameField {
    return InvalidGenerationSourceError(
      'Skip element and foreign key relation feature cannot be used in the same field.',
      todo: 'Consider remove @ignore.',
      element: _fieldElement,
    );
  }

  InvalidGenerationSourceError get typeOfFieldIsNotClass {
    final type = _fieldElement.type.isDartCoreList ? _fieldElement.type.flatten() : _fieldElement.type;
    return InvalidGenerationSourceError(
       'The type ${type.getDisplayString(withNullability: false)} of fields with the @ForeignKeyRelation annotation must be an entity.',
      todo: 'Remove the @ForeignKeyRelation annotation or change the property type to an entity.',
      element: _fieldElement,
    );
  }

  InvalidGenerationSourceError foreignKeyDoesNotReferenceEntity(String nameField) {
    return InvalidGenerationSourceError(
      "The class ${_fieldElement.enclosingElement.name} doesn't have foreign key with child relation for field $nameField.",
      element: _fieldElement,
    );
  }

  InvalidGenerationSourceError twoForeignKeysForTheSameParentTable(String nameField){
    return InvalidGenerationSourceError(
      'The class ${_fieldElement.enclosingElement.name} have more one foreign key with child relation for field $nameField.',
      todo: 'Open a issue to implement the feature.',
      element: _fieldElement,
    );
  }
}
