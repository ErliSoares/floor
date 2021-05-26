import 'package:analyzer/dart/element/element.dart';
import 'package:floor_generator/misc/constants.dart';
import 'package:floor_generator/processor/entity_processor.dart';
import 'package:floor_generator/processor/error/junction_processor_error.dart';
import 'package:floor_generator/processor/processor.dart';
import 'package:floor_generator/value_object/foreign_key.dart';
import 'package:floor_generator/value_object/junction.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations;
import 'package:floor_generator/misc/type_utils.dart';
import 'package:floor_generator/extension/field_element_extension.dart';

class JunctionProcessor extends Processor<Junction?> {
  final JunctionProcessorError _processorError;
  final FieldElement _fieldElement;

  JunctionProcessor(
    final FieldElement fieldElement,
  )   : _fieldElement = fieldElement,
        _processorError = JunctionProcessorError(fieldElement);

  @override
  Junction? process() {
    if (!_fieldElement.isJunction()) {
      return null;
    }

    if (_fieldElement.isEmbedded) {
      throw _processorError.embeddedAndJunctionSameField;
    }

    final isIgnored = _fieldElement.hasAnnotation(annotations.Ignore);
    if (isIgnored) {
      throw _processorError.ignoreAndJunctionSameField;
    }

    final junctionAnnotation = _fieldElement.getAnnotation(annotations.Junction)!;
    final entityJunctionAnnotation = junctionAnnotation.getField(JunctionField.entityJunction)!.toTypeValue()!;

    final ignoreSaveChild = junctionAnnotation.getField(JunctionField.ignoreSaveChild)!.toBoolValue()!;

    final parentElement = _fieldElement.enclosingElement as ClassElement;
    final tableNameParent = parentElement.tableName();

    final entityJunction = EntityProcessor(entityJunctionAnnotation.element as ClassElement, {}).process();
    if (entityJunction.foreignKeys.length != 2) {
      throw _processorError.invalidNumbersOfForeignKeysError;
    }
    final ForeignKey foreignKeyParent;
    final ForeignKey foreignKeyChild;

    if (entityJunction.foreignKeys[0].parentName == tableNameParent) {
      foreignKeyParent = entityJunction.foreignKeys[0];
      foreignKeyChild = entityJunction.foreignKeys[1];
    } else if (entityJunction.foreignKeys[1].parentName == tableNameParent) {
      foreignKeyChild = entityJunction.foreignKeys[0];
      foreignKeyParent = entityJunction.foreignKeys[1];
    } else {
      throw _processorError.foreignKeysOfJunctionWithNotRelationWithParent;
    }
    if (foreignKeyChild.parentColumns.length != 1) {
      throw _processorError.moreThanOneColumnInTheKeyConnection;
    }
    if (foreignKeyParent.parentColumns.length != 1) {
      throw _processorError.moreThanOneColumnInTheKeyConnection;
    }

    final childElement = (_fieldElement.type.isDartCoreList ? _fieldElement.type.flatten() : _fieldElement.type).element;

    if (! (childElement  is ClassElement)) {
      throw _processorError.typeOfFieldIsNotClass;
    }

    return Junction(
      nameProperty: _fieldElement.name,
      parentElement: parentElement,
      childElement: childElement,
      entityJunction: entityJunction,
      fieldElement: _fieldElement,
      foreignKeyJunctionChild: foreignKeyChild,
      foreignKeyJunctionParent: foreignKeyParent,
      ignoreSaveChild: ignoreSaveChild,
    );
  }
}
