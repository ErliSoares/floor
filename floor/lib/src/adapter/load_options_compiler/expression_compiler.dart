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
      if (value) {
        arguments.add(1);
      } else {
        arguments.add(0);
      }
    } else {
      arguments.add(value);
    }
    return '?${arguments.length}';
  }

  ColumnSql getSqlColumn(String name) {
    final column = queryInfo.columns.firstWhereOrNull((e) => e.name == name);
    if (column == null) {
      throw Exception('Name of column `$name` is not valid column result in query `$sql`');
    }
    return column;
  }
}
