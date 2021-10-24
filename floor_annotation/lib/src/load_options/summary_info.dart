import 'package:floor_annotation/floor_annotation.dart';

/// Representa uma definição de resumo do grupo ou total.
class SummaryInfo {
  SummaryInfo({required this.selector, required this.summaryType});

  /// O campo de dados a ser usado para calcular o resumo, pode ser um [Column] ou o nome do campo.
  Object selector;

  /// Uma função agregada.
  SummaryType summaryType;
}

enum SummaryType {
  @EnumValue('sum')
  sum,
  @EnumValue('min')
  min,
  @EnumValue('max')
  max,
  @EnumValue('avg')
  avg,
  @EnumValue('count')
  count
}
