import 'package:floor_annotation/floor_annotation.dart';

/// Representa uma definição da expansão de uma propriedade ou relação entre as entidades.
class ExpandInfo {
  ExpandInfo({
    required this.selector,
    this.expand,
    this.filter,
    this.select,
    this.sort,
    this.notSelect,
  });

  /// O campo de dados a ser usado para expandir, pode ser um [Column] ou o nome do campo.
  Object selector;

  /// Uma expressão de expansão para mais um nível levando em consideração os dados desse nível.
  List<ExpandInfo>? expand;

  /// Uma expressão de filtro que será aplicado sobre os registros a serem expandidos.
  List<Object>? filter;

  /// Colunas que vão ser retornadas, se não estiver preenchidas retornar todas,
  /// pode ser um [Column] ou o nome do campo.
  List<Object>? select;

  /// Uma expressão de classificação.
  List<SortingInfo>? sort;

  /// Propriedades que não devem ser retornadas, retornam todas menos as que forem definidas aqui,
  /// essa tem prioridade sobre o select, pode ser um [Column] ou o nome do campo.
  List<Object>? notSelect;
}
