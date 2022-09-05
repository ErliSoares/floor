import 'package:analyzer/dart/element/element.dart';
import 'package:floor_generator/processor/entity_processor.dart';
import 'package:floor_generator/processor/error/relation_processor_error.dart';
import 'package:floor_generator/processor/processor.dart';
import 'package:floor_generator/value_object/relation.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations;
import 'package:floor_generator/misc/type_utils.dart';
import 'package:floor_generator/extension/field_element_extension.dart';

class RelationProcessor extends Processor<Relation?> {
  final RelationProcessorError _processorError;
  final FieldElement _fieldElement;

  RelationProcessor(
    final FieldElement fieldElement,
  )   : _fieldElement = fieldElement,
        _processorError = RelationProcessorError(fieldElement);

  @override
  Relation? process() {
    if (!_fieldElement.isRelation()) {
      return null;
    }

    if (_fieldElement.isEmbedded) {
      throw _processorError.embeddedAndRelationSameField;
    }

    final isIgnored = _fieldElement.hasAnnotation(annotations.Ignore);
    if (isIgnored) {
      throw _processorError.ignoreAndRelationSameField;
    }

    final fieldType = _fieldElement.type.isDartCoreList ? _fieldElement.type.flatten() : _fieldElement.type;

    final fieldTypeElement = fieldType.element;
    if (!(fieldTypeElement is ClassElement)) {
      throw _processorError.typeOfFieldIsNotClass;
    }

    final parentElement = _fieldElement.enclosingElement as ClassElement;
    final tableNameParent = parentElement.tableName();

    final foreignKeys = EntityProcessor(fieldTypeElement, {}).getForeignKeys(fieldTypeElement);
    final foreignKeysRelation = foreignKeys.where((e) => e.parentName == tableNameParent);
    if (foreignKeysRelation.isEmpty) {
      throw _processorError.foreignKeyDoesNotReferenceEntity;
    }
    if (foreignKeysRelation.length > 1) {
      throw _processorError.twoForeignKeysForTheSameParentTable(fieldTypeElement);
    }

    final childElement =
        (_fieldElement.type.isDartCoreList ? _fieldElement.type.flatten() : _fieldElement.type).element;

    if (!(childElement is ClassElement)) {
      throw _processorError.typeOfFieldIsNotClass;
    }

    return Relation(
      nameProperty: _fieldElement.name,
      parentElement: parentElement,
      childElement: childElement,
      fieldElement: _fieldElement,
      foreignKey: foreignKeysRelation.first,
    );
  }
}
