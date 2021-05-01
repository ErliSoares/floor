import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

class AfterMethodProcessorError {
  final MethodElement _methodElement;

  AfterMethodProcessorError(this._methodElement);

  InvalidGenerationSourceError get doesNotReturnFuture =>
      InvalidGenerationSourceError(
        'Methods after callback have to return a Future.',
        element: _methodElement,
      );

  InvalidGenerationSourceError get shouldNotReturnList =>
      InvalidGenerationSourceError(
        'Methods after callback have to return a Future of either void but not a list.',
        element: _methodElement,
      );
  InvalidGenerationSourceError get doesNotReturnVoid =>
      InvalidGenerationSourceError(
        'Methods after callback have to return a Future of either void.',
        element: _methodElement,
      );
}
