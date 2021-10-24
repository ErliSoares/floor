import 'package:floor_annotation/floor_annotation.dart';

class AggregatorField {
  final AggregatorType type;
  final Object selector;
  final String groupSeparator;

  AggregatorField({
    required this.type,
    required this.selector,
    this.groupSeparator = ', ',
  });
}

enum AggregatorType {
  @EnumValue('sum')
  sum,
  @EnumValue('min')
  min,
  @EnumValue('max')
  max,
  @EnumValue('avg')
  avg,
  @EnumValue('count')
  count,
  @EnumValue('concat')
  concat,
}
