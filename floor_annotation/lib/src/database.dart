/// Marks a class as a FloorDatabase.
class Database {
  /// The database version.
  final int version;

  /// The entities the database manages.
  final List<Type> entities;

  /// The views the database manages.
  final List<Type> views;

  /// The routines the database process.
  final List<Type> routines;

  /// Marks a class as a FloorDatabase.
  const Database({
    required this.version,
    required this.entities,
    this.views = const [],
    this.routines = const [],
  });
}
