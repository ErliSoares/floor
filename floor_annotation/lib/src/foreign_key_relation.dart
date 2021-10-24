class ForeignKeyRelation {
  final String field;

  final bool save;

  const ForeignKeyRelation(
    this.field, {
    this.save = false,
  });
}
