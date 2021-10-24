import 'package:floor_annotation/floor_annotation.dart';

/// Representa um nível de agrupamento a ser aplicado aos dados.
class GroupingInfo extends SortingInfo {
  GroupingInfo({
    required Object selector,
    this.groupInterval,
    this.numberInterval,
    this.isExpanded,
    bool desc = true,
  }) : super(selector: selector, desc: desc);

  /// Um valor que agrupa dados em intervalos de um determinado comprimento ou período de data/hora.
  GroupInterval? groupInterval;

  /// Define o número de intervalo que será agrupado, utilizado quando [groupInterval] for [GroupInterval.numberInterval
  num? numberInterval;

  /// Um sinalizador indicando se os objetos de dados do grupo devem ser retornados.
  bool? isExpanded;

  @override
  GroupingInfo copyWith({
    Object? selector,
    GroupInterval? groupInterval,
    num? numberInterval,
    bool? isExpanded,
    bool? desc,
  }) {
    return GroupingInfo(
      selector: selector ?? this.selector,
      groupInterval: groupInterval ?? this.groupInterval,
      numberInterval: numberInterval ?? this.numberInterval,
      isExpanded: isExpanded ?? this.isExpanded,
      desc: desc ?? this.desc,
    );
  }
}

enum GroupInterval {
  @EnumValue('numberInterval')
  numberInterval,
  @EnumValue('year')
  year,
  @EnumValue('quarter')
  quarter,
  @EnumValue('month')
  month,
  @EnumValue('day')
  day,
  @EnumValue('dayOfWeek')
  dayOfWeek,
  @EnumValue('weekOfYear')
  weekOfYear,
  @EnumValue('hour')
  hour,
  @EnumValue('minute')
  minute,
  @EnumValue('second')
  second,
}
