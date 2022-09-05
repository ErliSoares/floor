import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

class BeforeMethodProcessorError {
  final MethodElement _methodElement;

  BeforeMethodProcessorError(this._methodElement);

  InvalidGenerationSourceError get doesNotReturnFuture => InvalidGenerationSourceError(
        'Methods before callback have to return a Future.',
        element: _methodElement,
      );

  InvalidGenerationSourceError get shouldNotReturnList => InvalidGenerationSourceError(
        'Methods before callback have to return a Future of either void but not a list.',
        element: _methodElement,
      );
  InvalidGenerationSourceError get doesNotReturnVoid => InvalidGenerationSourceError(
        'Methods before callback have to return a Future of either void.',
        element: _methodElement,
      );
}
