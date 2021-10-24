import 'package:floor_annotation/floor_annotation.dart';
import 'package:floor_annotation/src/load_options/aggregator_field.dart';

class LoadOptions extends LoadOptionsEntry {
  LoadOptions({
    int? skip,
    int? take,
    List<SortingInfo>? sort,
    List<Object?>? filter,
    List<ExpandInfo>? expand,
    List<GroupingInfo>? group,
    List<AggregatorField>? aggregators,
    this.requireTotalCount,
    this.requireGroupCount,
    this.isCountQuery,
    this.totalSummary,
    this.groupSummary,
    this.select,
    this.notSelect,
  }) : super(
          expand: expand,
          filter: filter,
          skip: skip,
          sort: sort,
          take: take,
          group: group,
          aggregators: aggregators,
        );

  @override
  LoadOptions copyWith({
    bool? requireTotalCount,
    bool? requireGroupCount,
    bool? isCountQuery,
    int? skip,
    int? take,
    List<SortingInfo>? sort,
    List<GroupingInfo>? group,
    List<Object?>? filter,
    List<SummaryInfo>? totalSummary,
    List<SummaryInfo>? groupSummary,
    List<Object>? select,
    List<Object>? notSelect,
    List<ExpandInfo>? expand,
    List<AggregatorField>? aggregators,
  }) {
    return LoadOptions(
      requireTotalCount: requireTotalCount ?? this.requireTotalCount,
      requireGroupCount: requireGroupCount ?? this.requireGroupCount,
      isCountQuery: isCountQuery ?? this.isCountQuery,
      skip: skip ?? this.skip,
      take: take ?? this.take,
      sort: sort ?? this.sort,
      group: group ?? this.group,
      filter: filter ?? this.filter,
      totalSummary: totalSummary ?? this.totalSummary,
      groupSummary: groupSummary ?? this.groupSummary,
      select: select ?? this.select,
      notSelect: notSelect ?? this.notSelect,
      expand: expand ?? this.expand,
      aggregators: aggregators ?? this.aggregators,
    );
  }

  /// Um sinalizador que indica se o número total de objetos de dados é obrigatório.
  bool? requireTotalCount;

  /// Um sinalizador que indica se o número de grupos de nível superior é obrigatório.
  bool? requireGroupCount;

  /// Um sinalizador indicando se a consulta atual é feita para obter o número total de objetos de dados.
  bool? isCountQuery;

  /// Uma expressão sumária total.
  List<SummaryInfo>? totalSummary;

  /// Uma expressão de resumo de grupo.
  List<SummaryInfo>? groupSummary;

  /// Colunas que vão ser retornadas, se não estiver preenchidas retornar todas, pode ser um [Column] ou o nome do campo.
  List<Object>? select;

  /// Propriedades que não devem ser retornadas, retornam todas menos as que forem definidas aqui,
  /// essa tem prioridade sobre o select, pode ser um [Column] ou o nome do campo.
  List<Object>? notSelect;
}
