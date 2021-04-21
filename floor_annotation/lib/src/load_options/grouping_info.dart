import 'package:floor_annotation/floor_annotation.dart';

/// Representa um nível de agrupamento a ser aplicado aos dados.
class GroupingInfo extends SortingInfo {
  GroupingInfo({
    required String selector,
    this.groupInterval,
    this.isExpanded,
    bool desc = true,
  }) : super(selector: selector, desc: desc);

  /// Um valor que agrupa dados em intervalos de um determinado comprimento ou período de data/hora.
  GroupInterval? groupInterval;

  /// Um sinalizador indicando se os objetos de dados do grupo devem ser retornados.
  bool? isExpanded;

  @override
  GroupingInfo copyWith({
    String? selector,
    GroupInterval? groupInterval,
    bool? isExpanded,
    bool? desc,
  }) {
    return GroupingInfo(
      selector: selector ?? this.selector,
      groupInterval: groupInterval ?? this.groupInterval,
      isExpanded: isExpanded ?? this.isExpanded,
      desc: desc ?? this.desc,
    );
  }


}

enum GroupInterval {
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
  @EnumValue('hour')
  hour,
  @EnumValue('minute')
  minute,
  @EnumValue('second')
  second,
}
