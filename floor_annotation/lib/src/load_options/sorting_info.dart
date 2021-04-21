/// Representa um parâmetro de classificação.
class SortingInfo {
  SortingInfo({required this.selector, this.desc = true});

  /// O campo de dados a ser usado para classificação.
  String selector;

  /// Um sinalizador que indica se os dados devem ser classificados em ordem decrescente.
  bool desc;

  SortingInfo copyWith({
    String? selector,
    bool? desc,
  }) {
    return SortingInfo(
      selector: selector ?? this.selector,
      desc: desc ?? this.desc,
    );
  }
}