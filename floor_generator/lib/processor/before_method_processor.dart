import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations;
import 'package:floor_generator/misc/change_method_processor_helper.dart';
import 'package:floor_generator/misc/type_utils.dart';
import 'package:floor_generator/processor/error/before_method_processor_error.dart';
import 'package:floor_generator/processor/processor.dart';
import 'package:floor_generator/value_object/before_operation_method.dart';
import 'package:floor_generator/value_object/entity.dart';

class BeforeMethodProcessor implements Processor<BeforeOperationMethod> {
  final MethodElement _methodElement;
  final ChangeMethodProcessorHelper _helper;
  final BeforeMethodProcessorError _errors;

  BeforeMethodProcessor(
    final MethodElement methodElement,
    final List<Entity> entities, [
    final ChangeMethodProcessorHelper? changeMethodProcessorHelper,
  ])  : _methodElement = methodElement,
        _errors = BeforeMethodProcessorError(methodElement),
        _helper = changeMethodProcessorHelper ?? ChangeMethodProcessorHelper(methodElement, entities);

  @override
  BeforeOperationMethod process() {
    final name = _methodElement.name;
    final returnType = _methodElement.returnType;

    _assertMethodReturnsFuture(returnType);

    final flattenedReturnType = _getFlattenedReturnType(returnType);
    _assertMethodReturnsNoList(flattenedReturnType);

    final parameterElement = _helper.getParameterElement();
    final flattenedParameterType = _helper.getFlattenedParameterType(parameterElement);
    final entity = _helper.getEntity(flattenedParameterType);

    final returnsVoid = flattenedReturnType.isVoid;
    if (!returnsVoid) {
      throw _errors.doesNotReturnVoid;
    }

    final forDelete = _methodElement.hasAnnotation(annotations.beforeDelete.runtimeType);
    final forInsert = _methodElement.hasAnnotation(annotations.beforeInsert.runtimeType);
    final forUpdate = _methodElement.hasAnnotation(annotations.beforeUpdate.runtimeType);

    return BeforeOperationMethod(
      methodElement: _methodElement,
      name: name,
      entity: entity,
      forDelete: forDelete,
      forInsert: forInsert,
      forUpdate: forUpdate,
    );
  }

  DartType _getFlattenedReturnType(final DartType returnType) {
    return _methodElement.library.typeSystem.flatten(returnType);
  }

  void _assertMethodReturnsNoList(final DartType flattenedReturnType) {
    if (flattenedReturnType.isDartCoreList) {
      throw _errors.shouldNotReturnList;
    }
  }

  void _assertMethodReturnsFuture(final DartType returnType) {
    if (!returnType.isDartAsyncFuture) {
      throw _errors.doesNotReturnFuture;
    }
  }
}
