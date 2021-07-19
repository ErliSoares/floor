/// Allows customization of the column associated with this field.
class ColumnInfo {
  /// The custom name of the column.
  final String? name;

  final int? length;

  final int? decimals;

  const ColumnInfo({this.name,this.length,this.decimals});
}
