import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

class AfterQueryMethodProcessorError {
  final MethodElement _methodElement;

  AfterQueryMethodProcessorError(this._methodElement);

  InvalidGenerationSourceError get doesNotReturnFuture =>
      InvalidGenerationSourceError(
        'Methods before callback have to return a Future.',
        element: _methodElement,
      );

  InvalidGenerationSourceError get shouldReturnList =>
      InvalidGenerationSourceError(
        'Methods before callback have to return a Future of either list.',
        element: _methodElement,
      );

  InvalidGenerationSourceError get isAbstractMethod =>
      InvalidGenerationSourceError(
        'The after query method has to be abstract.',
        element: _methodElement,
      );

}
