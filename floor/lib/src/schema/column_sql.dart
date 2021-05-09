import 'package:floor/src/schema/column.dart';

/// A column that is part of a table.
class ColumnSql extends Column {
  ColumnSql(Column column, {required this.sqlField})
      : super(
          column.name,
          column.type,
          nullable: column.nullable,
          useInIDelete: column.useInIDelete,
          useInInsert: column.useInInsert,
          useInIUpdate: column.useInIUpdate,
          useInQuery: column.useInQuery,
          relationship: column.relationship,
          converter: column.converter,
        );

  final String sqlField;
}
