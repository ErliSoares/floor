import 'package:floor_annotation/floor_annotation.dart';

class LoadOptions {
  LoadOptions({
    this.requireTotalCount,
    this.requireGroupCount,
    this.isCountQuery,
    this.skip,
    this.take,
    this.sort,
    this.group,
    this.filter,
    this.totalSummary,
    this.groupSummary,
    this.select,
    this.notSelect,
    this.expand,
  });

  LoadOptions copyWith({
    bool? requireTotalCount,
    bool? requireGroupCount,
    bool? isCountQuery,
    int? skip,
    int? take,
    List<SortingInfo>? sort,
    List<GroupingInfo>? group,
    List<Object>? filter,
    List<SummaryInfo>? totalSummary,
    List<SummaryInfo>? groupSummary,
    List<String>? select,
    List<String>? notSelect,
    List<ExpandInfo>? expand,
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
    );
  }

  /// Um sinalizador que indica se o número total de objetos de dados é obrigatório.
  bool? requireTotalCount;

  /// Um sinalizador que indica se o número de grupos de nível superior é obrigatório.
  bool? requireGroupCount;

  /// Um sinalizador indicando se a consulta atual é feita para obter o número total de objetos de dados.
  bool? isCountQuery;

  /// O número de objetos de dados a serem ignorados desde o início do conjunto resultante.
  int? skip;

  /// O número de objetos de dados a serem carregados.
  int? take;

  /// Uma expressão de classificação.
  List<SortingInfo>? sort;

  /// Uma expressão de grupo.
  List<GroupingInfo>? group;

  /// Uma expressão de filtro.
  ///
  /// Os operadores disponíveis são: '=', '<>', '>', '>=', '<', '<=', 'startswith', 'endswith', 'contains', 'notcontains', 'substring' e 'in'.
  ///
  /// ## Exemplos
  ///
  /// ### Filtro binário
  /// ```DART
  /// final filter = ['fieldOne', '=', 1];
  /// ```
  ///
  /// ### Filtro unário
  /// ```DART
  /// final filter = ['!', ['fieldOne', '=', 1] ];
  /// ```
  ///
  /// ### Filtro complexo
  /// ```DART
  /// final filter = [
  ///   [ 'fieldOne', '=', 8 ],
  ///   'and',
  ///   [
  ///     [ 'fieldTwo', '<', 3 ],
  ///     'or',
  ///     [ 'fieldTwo', '>', 11 ]
  ///   ]
  /// ];
  /// ```
  ///
  /// ### Filtro com substring
  ///
  /// `[ fieldName, 'substring', position, length, valueCompare ]`
  ///
  /// ```DART
  /// final filter = [ 'fieldName', 'substring', 1, 1, 'T' ];
  /// ```
  ///
  /// ### Filtro com in
  ///
  /// ```DART
  /// final filter = [ 'fieldName', 'in', [1, 2, 3, 4] ];
  /// ```
  List<Object>? filter;

  /// Uma expressão sumária total.
  List<SummaryInfo>? totalSummary;

  /// Uma expressão de resumo de grupo.
  List<SummaryInfo>? groupSummary;

  /// Colunas que vão ser retornadas, se não estiver preenchidas retornar todas.
  List<String>? select;

  /// Propriedades que não devem ser retornadas, retornam todas menos as que forem definidas aqui,
  /// essa tem prioridade sobre o select.
  List<String>? notSelect;

  /// Uma expressão de expansão.
  List<ExpandInfo>? expand;
}
