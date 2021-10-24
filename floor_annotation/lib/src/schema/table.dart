import 'package:floor_annotation/floor_annotation.dart';

/// A database table. The information stored here will be used to resolve mount operations on runtime
class Table {
  /// Constructs a table from the known [name] and [columns].
  Table({required this.name, required this.columns}) {
    for (final column in columns) {
      column.table = this;
    }
  }

  /// The raw name of this table
  final String name;

  /// Columns of this table
  final List<Column> columns;

  /// find column by name
  Column? findColumn(String name) {
    for(final item in columns){
      if (item.name == name) {
        return item;
      }
    }
    return null;
  }
}
