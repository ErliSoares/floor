import 'package:floor_annotation/floor_annotation.dart';
import 'package:floor_annotation/src/load_options/aggregator_field.dart';

class LoadOptionsEntry {
  LoadOptionsEntry({
    this.skip,
    this.take,
    this.sort,
    this.filter,
    this.expand,
    this.group,
    this.aggregators,
  });

  LoadOptionsEntry copyWith({
    int? skip,
    int? take,
    List<SortingInfo>? sort,
    List<Object?>? filter,
    List<ExpandInfo>? expand,
    List<GroupingInfo>? group,
    List<AggregatorField>? aggregators,
  }) {
    return LoadOptionsEntry(
      skip: skip ?? this.skip,
      take: take ?? this.take,
      sort: sort ?? this.sort,
      filter: filter ?? this.filter,
      expand: expand ?? this.expand,
      group: group ?? this.group,
      aggregators: aggregators ?? this.aggregators,
    );
  }

  /// O número de objetos de dados a serem ignorados desde o início do conjunto resultante.
  int? skip;

  /// O número de objetos de dados a serem carregados.
  int? take;

  /// Uma expressão de classificação.
  List<SortingInfo>? sort;

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
  List<Object?>? filter;

  /// Uma expressão de expansão.
  List<ExpandInfo>? expand;

  /// Uma expressão de grupo.
  List<GroupingInfo>? group;

  /// Agregadores para os campos da select
  List<AggregatorField>? aggregators;
}
