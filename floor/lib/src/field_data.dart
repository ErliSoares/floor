class FieldData {
  final String name;
  final String nameColumn;
  final bool ignoreForQuery;
  final bool ignoreForInsert;
  final bool ignoreForUpdate;
  final bool ignoreForDelete;
  final Object? value;
  final Object? valueSave;

  final bool ignoredAll;

  FieldData(
    this.name,
    this.value,
    this.valueSave,
    this.nameColumn, {
    this.ignoreForQuery = false,
    this.ignoreForInsert = false,
    this.ignoreForUpdate = false,
    this.ignoreForDelete = false,
  }) : ignoredAll = ignoreForQuery && ignoreForInsert && ignoreForUpdate && ignoreForDelete;

  FieldData.ignoreAll(
    this.name,
    this.value,
    this.valueSave,
    this.nameColumn, {
    this.ignoreForQuery = true,
    this.ignoreForInsert = true,
    this.ignoreForUpdate = true,
    this.ignoreForDelete = true,
  }) : ignoredAll = ignoreForQuery && ignoreForInsert && ignoreForUpdate && ignoreForDelete;
}
