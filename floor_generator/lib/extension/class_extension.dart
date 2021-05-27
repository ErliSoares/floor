import 'package:analyzer/dart/element/element.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations;
import 'package:floor_generator/misc/type_utils.dart';

extension ClassExtension on ClassElement {
  bool get isEntity {
    return hasAnnotation(annotations.Entity) &&
    !isAbstract;
  }
}
