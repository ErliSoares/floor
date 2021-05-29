import 'package:analyzer/dart/element/element.dart';
import 'package:floor_generator/misc/constants.dart';
import 'package:floor_generator/processor/entity_processor.dart';
import 'package:floor_generator/processor/error/foreign_key_relation_processor_error.dart';
import 'package:floor_generator/processor/processor.dart';
import 'package:floor_generator/value_object/foreign_key_relation.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations;
import 'package:floor_generator/misc/type_utils.dart';
import 'package:floor_generator/extension/field_element_extension.dart';

class ForeignKeyRelationProcessor extends Processor<ForeignKeyRelation?> {
  final ForeignKeyRelationProcessorError _processorError;
  final FieldElement _fieldElement;

  ForeignKeyRelationProcessor(
    final FieldElement fieldElement,
  )   : _fieldElement = fieldElement,
        _processorError = ForeignKeyRelationProcessorError(fieldElement);

  @override
  ForeignKeyRelation? process() {
    if (!_fieldElement.isForeignKeyRelation()) {
      return null;
    }

    if (_fieldElement.isEmbedded) {
      throw _processorError.embeddedAndForeignKeyRelationSameField;
    }

    final isIgnored = _fieldElement.hasAnnotation(annotations.Ignore);
    if (isIgnored) {
      throw _processorError.ignoreAndForeignKeyRelationSameField;
    }

    final fieldType = _fieldElement.type.isDartCoreList ? _fieldElement.type.flatten() : _fieldElement.type;

    final parentClassElement = fieldType.element;
    if (!(parentClassElement is ClassElement)) {
      throw _processorError.typeOfFieldIsNotClass;
    }

    final foreignKeyRelationAnnotation = _fieldElement.getAnnotation(annotations.ForeignKeyRelation)!;
    final save = foreignKeyRelationAnnotation.getField(ForeignKeyRelationField.save)!.toBoolValue()!;
    final namePropertyRelation = foreignKeyRelationAnnotation.getField(ForeignKeyRelationField.field)!.toStringValue()!;

    final childClassElement = _fieldElement.enclosingElement as ClassElement;

    final foreignKeys = EntityProcessor(childClassElement, {}).getForeignKeys(childClassElement);
    // TODO Pode ser colcoado para pegar somente onde as foreign key for do tipo da propriedade
    final foreignKeysRelation = foreignKeys.where((f) => f.childColumns.any((e) => e == namePropertyRelation));
    if (foreignKeysRelation.isEmpty) {
      throw _processorError.foreignKeyDoesNotReferenceEntity;
    }
    if (foreignKeysRelation.length > 1) {
      throw _processorError.twoForeignKeysForTheSameParentTable(namePropertyRelation);
    }

    return ForeignKeyRelation(
      nameProperty: _fieldElement.name,
      parentElement: parentClassElement,
      childElement: childClassElement,
      fieldElement: _fieldElement,
      foreignKey: foreignKeysRelation.first,
      namePropertyRelation: namePropertyRelation,
      save: save,
    );
  }
}
