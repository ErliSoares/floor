import 'package:floor/floor.dart';
import 'package:collection/collection.dart';
import 'package:floor/src/adapter/load_options_compiler/expression_compiler.dart';

class ColumnCompiler extends ExpressionCompiler {
  ColumnCompiler({
    required String sql,
    required LoadOptions loadOptions,
    required QueryInfo queryInfo,
    required List<Object?> arguments,
  }) : super(sql: sql, loadOptions: loadOptions, queryInfo: queryInfo, arguments: arguments);

  String? compile(List<Object>? columns, List<Object>? columnsExclude) {
    final fields = <String>[];
    final fieldsNames = <String>[];
    if (columns != null && columns.isNotEmpty) {
      for (var column in columns) {
        final nameColumn = nameOfColumn(column);
        if (columnsExclude == null || !columnsExclude.any((c) => nameOfColumn(c) == nameColumn)) {
          fields.add(getSqlColumn(column).sqlField + ' ' + nameColumn);
          fieldsNames.add(nameColumn);
        }
      }
    } else if (columnsExclude != null && columnsExclude.isNotEmpty) {
      for (var column in queryInfo.columns) {
        final nameColumn = column.name;
        if (!columnsExclude.any((c) => nameOfColumn(c) == nameColumn)) {
          fields.add(getSqlColumn(nameColumn).sqlField + ' ' + nameColumn);
          fieldsNames.add(nameColumn);
        }
      }
    }
    if (fields.isEmpty) {
      if (loadOptions.aggregators == null || loadOptions.aggregators!.isEmpty) {
        return null;
      }
      return queryInfo.columns.where((c) => c.sqlField.isNotEmpty).map((e) => _compileColumnAggregator(e)).join(',');
    }
    if (loadOptions.aggregators == null || loadOptions.aggregators!.isEmpty) {
      return fields.join(',');
    }
    return queryInfo.columns
        .where((c) => fieldsNames.any((f) => f == c.name))
        .map((e) => _compileColumnAggregator(e))
        .join(',');
  }

  String _compileColumnAggregator(ColumnSql columnSql) {
    final nameColumn = columnSql.name;
    final aggregator = loadOptions.aggregators!.firstWhereOrNull((e) => getSqlColumn(e.selector).name == nameColumn);
    if (aggregator == null) {
      return '${columnSql.sqlField} AS $nameColumn';
    }
    String aggregateFunctionSqlite;
    String parameters = columnSql.sqlField;
    switch (aggregator.type) {
      case AggregatorType.sum:
        aggregateFunctionSqlite = 'total';
        break;
      case AggregatorType.min:
        aggregateFunctionSqlite = 'min';
        break;
      case AggregatorType.max:
        aggregateFunctionSqlite = 'max';
        break;
      case AggregatorType.avg:
        aggregateFunctionSqlite = 'avg';
        break;
      case AggregatorType.count:
        aggregateFunctionSqlite = 'count';
        break;
      case AggregatorType.concat:
        aggregateFunctionSqlite = 'group_concat';
        parameters += ', \'${aggregator.groupSeparator}\'';
        break;
    }
    return '$aggregateFunctionSqlite($parameters) AS $nameColumn';
  }
}
