import 'package:floor/floor.dart';
import 'package:floor/src/adapter/load_options_compiler/expression_compiler.dart';

class ColumnCompiler extends ExpressionCompiler {
  ColumnCompiler({
    required String sql,
    required LoadOptions loadOptions,
    required QueryInfo queryInfo,
    required List<Object?> arguments,
  }) : super(sql: sql, loadOptions: loadOptions, queryInfo: queryInfo, arguments: arguments);

  String compile(List<String>? columns, List<String>? columnsExclude) {
    final fields = <String>[];
    if (columns != null && columns.isNotEmpty) {
      for (var nameColumn in columns) {
        if (columnsExclude == null || !columnsExclude.any((c) => c == nameColumn)) {
          fields.add(compileAccessorExpression(nameColumn) + ' ' + nameColumn);
        }
      }
    } else if (columnsExclude != null && columnsExclude.isNotEmpty) {
      for (var nameColumn in queryInfo.sqlColumns.keys) {
        if (!columnsExclude.any((c) => c == nameColumn)) {
          fields.add(compileAccessorExpression(nameColumn) + ' ' + nameColumn);
        }
      }
    }
    return fields.join(',');
  }
}
