import 'package:collection/collection.dart';

import '../../../floor.dart';

abstract class ExpressionCompiler {
  ExpressionCompiler({
    required this.sql,
    required this.loadOptions,
    required this.queryInfo,
    required this.arguments,
  });

  final String sql;
  final LoadOptions loadOptions;
  final QueryInfo queryInfo;
  final List<Object?> arguments;

  String addParameterAndGetKey(Object? value) {
    if (value is bool) {
      arguments.add(value ? 1 : 0);
    } else {
      arguments.add(value);
    }
    return '?${arguments.length}';
  }

  ColumnSql getSqlColumn(Object column) {
    ColumnSql? columnSql;
    if (column is Column) {
      final columnName = column.name;
      columnSql = queryInfo.columns.firstWhereOrNull((e) => e.name == columnName);
    } else {
      columnSql = queryInfo.columns.firstWhereOrNull((e) => e.name == column.toString());
    }
    if (columnSql == null) {
      throw Exception('Name of column `$column` is not valid column result in query `$sql`');
    }
    return columnSql;
  }

  String nameOfColumn(Object column) {
    if (column is Column) {
      return column.name;
    } else {
      return column.toString();
    }
  }
}
