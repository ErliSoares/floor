import 'package:analyzer/dart/element/element.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations;
import 'package:floor_generator/misc/constants.dart';
import 'package:floor_generator/misc/type_utils.dart';

extension FieldElementExtension on FieldElement {
  bool get isEmbedded {
    return hasAnnotation(annotations.Embedded) && type.element is ClassElement;
  }

  bool shouldBeIncludedAnyOperation() {
    if (isStatic || isSynthetic || isEmbedded) {
      return false;
    }

    final isIgnored = hasAnnotation(annotations.Ignore);
    if (!isIgnored) {
      return true;
    }
    final ignoreAnnotation = getAnnotation(annotations.Ignore)!;
    return !ignoreAnnotation.getField(IgnoreField.forQuery)!.toBoolValue()! ||
        !ignoreAnnotation.getField(IgnoreField.forInsert)!.toBoolValue()! ||
        !ignoreAnnotation.getField(IgnoreField.forUpdate)!.toBoolValue()! ||
        !ignoreAnnotation.getField(IgnoreField.forDelete)!.toBoolValue()!;
  }

  bool shouldBeIncludedForQuery() {
    if (isStatic || isSynthetic || isEmbedded) {
      return false;
    }
    if (isRelation() || isJunction()) {
      return false;
    }

    final isIgnored = hasAnnotation(annotations.Ignore);
    if (!isIgnored) {
      return true;
    }
    final ignoreAnnotation = getAnnotation(annotations.Ignore)!;
    return !ignoreAnnotation.getField(IgnoreField.forQuery)!.toBoolValue()!;
  }

  bool shouldBeIncludedForInsert() {
    if (isStatic || isSynthetic || isEmbedded) {
      return false;
    }
    if (isRelation() || isJunction()) {
      return false;
    }

    final isIgnored = hasAnnotation(annotations.Ignore);
    if (!isIgnored) {
      return true;
    }
    final ignoreAnnotation = getAnnotation(annotations.Ignore)!;
    return !ignoreAnnotation.getField(IgnoreField.forInsert)!.toBoolValue()!;
  }

  bool shouldBeIncludedForUpdate() {
    if (isStatic || isSynthetic || isEmbedded) {
      return false;
    }
    if (isRelation() || isJunction()) {
      return false;
    }

    final isIgnored = hasAnnotation(annotations.Ignore);
    if (!isIgnored) {
      return true;
    }
    final ignoreAnnotation = getAnnotation(annotations.Ignore)!;
    return !ignoreAnnotation.getField(IgnoreField.forUpdate)!.toBoolValue()!;
  }

  bool shouldBeIncludedForDelete() {
    if (isStatic || isSynthetic || isEmbedded) {
      return false;
    }
    if (isRelation() || isJunction()) {
      return false;
    }

    final isIgnored = hasAnnotation(annotations.Ignore);
    if (!isIgnored) {
      return true;
    }
    final ignoreAnnotation = getAnnotation(annotations.Ignore)!;
    return !ignoreAnnotation.getField(IgnoreField.forDelete)!.toBoolValue()!;
  }

  bool shouldBeIncludedForDataBaseSchema() {
    if (isStatic || isSynthetic || isEmbedded) {
      return false;
    }
    if (isRelation() || isJunction()) {
      return false;
    }

    final isIgnored = hasAnnotation(annotations.Ignore);
    if (!isIgnored) {
      return true;
    }
    final ignoreAnnotation = getAnnotation(annotations.Ignore)!;
    return !ignoreAnnotation.getField(IgnoreField.forInsert)!.toBoolValue()! ||
        !ignoreAnnotation.getField(IgnoreField.forUpdate)!.toBoolValue()! ||
        !ignoreAnnotation.getField(IgnoreField.forDelete)!.toBoolValue()!
    ;
  }

  bool isRelation(){
    return hasAnnotation(annotations.relation.runtimeType);
  }

  bool isJunction(){
    return hasAnnotation(annotations.Junction);
  }

}
