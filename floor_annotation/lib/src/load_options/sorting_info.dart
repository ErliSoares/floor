import 'package:floor_annotation/floor_annotation.dart';

/// Representa um parâmetro de classificação.
class SortingInfo {
  SortingInfo({required this.selector, this.desc = true});

  /// O campo de dados a ser usado para classificação, pode ser um [Column] ou o nome do campo.
  Object selector;

  /// Um sinalizador que indica se os dados devem ser classificados em ordem decrescente.
  bool desc;

  SortingInfo copyWith({
    Object? selector,
    bool? desc,
  }) {
    return SortingInfo(
      selector: selector ?? this.selector,
      desc: desc ?? this.desc,
    );
  }
}