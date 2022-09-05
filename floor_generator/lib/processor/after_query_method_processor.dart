import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:floor_generator/misc/change_method_processor_helper.dart';
import 'package:floor_generator/processor/error/after_query_method_processor_error.dart';
import 'package:floor_generator/processor/processor.dart';
import 'package:floor_generator/value_object/after_query_method.dart';
import 'package:floor_generator/value_object/entity.dart';
import 'package:source_gen/source_gen.dart';
import 'package:floor_generator/misc/type_utils.dart';

class AfterQueryMethodProcessor implements Processor<AfterQueryMethod> {
  final MethodElement _methodElement;
  final ChangeMethodProcessorHelper _helper;
  final AfterQueryMethodProcessorError _errors;

  AfterQueryMethodProcessor(
    final MethodElement methodElement,
    final List<Entity> entities, [
    final ChangeMethodProcessorHelper? changeMethodProcessorHelper,
  ])  : _methodElement = methodElement,
        _errors = AfterQueryMethodProcessorError(methodElement),
        _helper = changeMethodProcessorHelper ?? ChangeMethodProcessorHelper(methodElement, entities);

  @override
  AfterQueryMethod process() {
    final name = _methodElement.name;
    final returnType = _methodElement.returnType;

    _assertMethodReturnsFuture(returnType);

    final flattenedReturnType = _getFlattenedReturnType(returnType);
    _assertMethodReturnsList(flattenedReturnType);

    final parameters = _methodElement.parameters;
    if (parameters.length < 2) {
      throw InvalidGenerationSourceError(
        'There is no parameter supplied for this method. Please add two parameters.',
        element: _methodElement,
      );
    } else if (parameters.length > 2) {
      throw InvalidGenerationSourceError(
        'Only two parameter is allowed on this.',
        element: _methodElement,
      );
    }

    if (!parameters[1].type.isLoadOptionsEntry) {
      throw InvalidGenerationSourceError(
        'Segundo parâmetro tem de ser do tipo LoadOptionsEntry.',
        element: _methodElement,
      );
    }

    final parameterElement = parameters.first;
    final flattenedParameterType = _helper.getFlattenedParameterType(parameterElement);
    final entity = _helper.getEntity(flattenedParameterType);

    if (_methodElement.isAbstract) {
      throw _errors.isAbstractMethod;
    }

    return AfterQueryMethod(
      methodElement: _methodElement,
      name: name,
      entity: entity,
    );
  }

  DartType _getFlattenedReturnType(final DartType returnType) {
    return _methodElement.library.typeSystem.flatten(returnType);
  }

  void _assertMethodReturnsList(final DartType flattenedReturnType) {
    if (!flattenedReturnType.isDartCoreList) {
      throw _errors.shouldReturnList;
    }
  }

  void _assertMethodReturnsFuture(final DartType returnType) {
    if (!returnType.isDartAsyncFuture) {
      throw _errors.doesNotReturnFuture;
    }
  }
}
